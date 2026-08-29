#!/usr/bin/env python3
"""Coloca el atajo de skwd-wall en la configuracion de Hyprland del usuario.

Decide solo el formato (Lua o hyprlang), si manda Caelestia, y limpia de paso
cualquier linea que se haya pegado a mano en el formato equivocado (el fallo
mas comun: sintaxis .conf dentro de un hyprland.lua, que rompe la config con
"syntax error near 'toggle'").

Uso:  bind.py <hypr_dir> <cae_dir> <tecla> <detect|apply>
"""
import os
import shutil
import sys
from datetime import datetime

MARCA = "skwd wall toggle"
COMENTARIO = "Selector de wallpapers skwd-wall"


def detectar(hypr_dir, cae_dir):
    """Devuelve (formato, usa_caelestia, archivo_destino)."""
    if os.path.isfile(os.path.join(hypr_dir, "hyprland.lua")):
        formato, entry = "lua", os.path.join(hypr_dir, "hyprland.lua")
    elif os.path.isfile(os.path.join(hypr_dir, "hyprland.conf")):
        formato, entry = "conf", os.path.join(hypr_dir, "hyprland.conf")
    else:
        return "desconocido", False, ""

    # Tener el comando 'caelestia' no basta: lo que manda es si la config que
    # Hyprland carga lo integra, porque es su stub el que hace source de
    # hypr-user.* y ese archivo es el que sobrevive a un update de los dots.
    try:
        with open(entry, errors="replace") as fh:
            caelestia = "caelestia" in fh.read().lower()
    except OSError:
        caelestia = False

    if caelestia:
        destino = os.path.join(cae_dir, "hypr-user." + formato)
    else:
        destino = os.path.join(hypr_dir, "hyprland." + formato)
    return formato, caelestia, destino


def sintaxis_de(linea):
    """'lua', 'conf' o None segun como este escrito el bind."""
    s = linea.strip()
    if s.startswith("hl.bind("):
        return "lua"
    if s.startswith("bind") and "=" in s:
        return "conf"
    return None


def bloque_para(formato, caelestia, tecla):
    if formato == "lua":
        return [
            "",
            "-- " + COMENTARIO + " (anadido por skwd-wall-setup)",
            'hl.bind("SUPER + SHIFT + %s", hl.dsp.exec_cmd("skwd wall toggle"))' % tecla,
        ]
    if caelestia:
        # Los binds de Caelestia viven en el submap 'global' y la sesion se
        # queda ahi: uno suelto caeria en el submap por defecto, inactivo.
        return [
            "",
            "# " + COMENTARIO + " (anadido por skwd-wall-setup)",
            "submap = global",
            "bind = Super+Shift, %s, exec, skwd wall toggle" % tecla,
            "submap = reset",
        ]
    return [
        "",
        "# " + COMENTARIO + " (anadido por skwd-wall-setup)",
        "bind = SUPER SHIFT, %s, exec, skwd wall toggle" % tecla,
    ]


_RESPALDADOS = {}


def respaldar(path):
    """Una sola copia por archivo y ejecucion: la segunda guardaria ya lo editado."""
    if path in _RESPALDADOS:
        return None
    copia = "%s.bak-%s" % (path, datetime.now().strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(path, copia)
    _RESPALDADOS[path] = copia
    return copia


def limpiar(path, formato_archivo, informe):
    """Quita lineas de skwd escritas en el formato que este archivo no entiende.

    Devuelve True si el archivo tenia un atajo BUENO (y por tanto no hay que
    volver a insertarlo).
    """
    try:
        with open(path, errors="replace") as fh:
            lineas = fh.read().splitlines()
    except OSError:
        return False

    if not any(MARCA in ln for ln in lineas):
        return False

    sobra = set()
    tiene_bueno = False

    for i, linea in enumerate(lineas):
        if MARCA not in linea:
            continue
        sintaxis = sintaxis_de(linea)
        if sintaxis == formato_archivo:
            tiene_bueno = True
            continue

        # Linea en el formato equivocado: fuera, con lo que vino pegado a ella.
        sobra.add(i)
        for j in (i - 1, i - 2):
            if j >= 0 and (COMENTARIO in lineas[j] or lineas[j].strip() == "submap = global"):
                sobra.add(j)
        if i + 1 < len(lineas) and lineas[i + 1].strip() == "submap = reset":
            sobra.add(i + 1)

    if not sobra:
        return tiene_bueno

    copia = respaldar(path)
    quedan = [ln for i, ln in enumerate(lineas) if i not in sobra]
    with open(path, "w") as fh:
        fh.write("\n".join(quedan).rstrip("\n") + "\n")

    informe.append("[!!] %s tenia el atajo en el formato equivocado." % path)
    informe.append("[!!] He quitado %d linea(s) que rompian la config." % len(sobra))
    if copia:
        informe.append("[ok] Copia previa: %s" % copia)
    return tiene_bueno


def insertar(path, bloque, formato):
    nuevo = not os.path.exists(path)
    if nuevo:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        lineas = []
    else:
        with open(path, errors="replace") as fh:
            lineas = fh.read().splitlines()

    # En Lua un 'return' final cierra el modulo: el bloque va antes.
    corte = len(lineas)
    if formato == "lua":
        for i in range(len(lineas) - 1, -1, -1):
            if not lineas[i].strip():
                continue
            if lineas[i].strip().startswith("return"):
                corte = i
            break

    con_bloque = lineas[:corte] + bloque + lineas[corte:]
    with open(path, "w") as fh:
        fh.write("\n".join(con_bloque).rstrip("\n") + "\n")
    return nuevo


def main():
    if len(sys.argv) != 5:
        print(__doc__.strip())
        return 2

    hypr_dir, cae_dir, tecla, accion = sys.argv[1:5]
    formato, caelestia, destino = detectar(hypr_dir, cae_dir)

    if accion == "detect":
        print(formato)
        print("si" if caelestia else "no")
        print(destino)
        print("\n".join(bloque_para(formato, caelestia, tecla)).strip())
        return 0

    if formato == "desconocido":
        print("[XX] No encuentro hyprland.lua ni hyprland.conf en %s" % hypr_dir)
        return 1

    informe = []
    ya_esta = False

    # El atajo pudo pegarse en cualquiera de los cuatro archivos posibles.
    candidatos = [
        (os.path.join(hypr_dir, "hyprland.lua"), "lua"),
        (os.path.join(hypr_dir, "hyprland.conf"), "conf"),
        (os.path.join(cae_dir, "hypr-user.lua"), "lua"),
        (os.path.join(cae_dir, "hypr-user.conf"), "conf"),
    ]
    for path, formato_archivo in candidatos:
        if os.path.isfile(path):
            if limpiar(path, formato_archivo, informe) and path == destino:
                ya_esta = True

    if ya_esta:
        informe.append("[ok] El atajo ya estaba bien puesto en %s" % destino)
    else:
        if os.path.isfile(destino):
            copia = respaldar(destino)
            if copia:
                informe.append("[ok] Copia previa: %s" % copia)
        nuevo = insertar(destino, bloque_para(formato, caelestia, tecla), formato)
        if nuevo:
            informe.append("[ok] He creado %s" % destino)
        informe.append("[ok] Atajo escrito en %s" % destino)

    print("\n".join(informe))
    return 0


if __name__ == "__main__":
    sys.exit(main())
