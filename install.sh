#!/usr/bin/env bash
# Instalador del selector de wallpapers skwd-wall (perfil "solo selector").
# Idempotente: se puede volver a ejecutar sin romper nada.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/skwd-wall"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall"
CONFIG_FILE="$CONFIG_DIR/config.json"

c_ok()   { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
c_err()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------- 1. Requisitos
if ! command -v pacman >/dev/null 2>&1; then
  c_err "Esto solo esta pensado para Arch Linux y derivadas (CachyOS, EndeavourOS...)."
  c_err "En otra distro tendras que compilar skwd-daemon a mano:"
  c_err "  https://github.com/liixini/skwd-daemon"
  exit 1
fi

if ! command -v hyprctl >/dev/null 2>&1; then
  c_warn "No detecto Hyprland. La config trae 'compositor: hyprland';"
  c_warn "si usas niri o KDE cambialo en $CONFIG_FILE al terminar."
fi

AUR_HELPER=""
for helper in yay paru; do
  if command -v "$helper" >/dev/null 2>&1; then AUR_HELPER="$helper"; break; fi
done

if [ -z "$AUR_HELPER" ]; then
  c_err "No encuentro yay ni paru. Instala uno de los dos y vuelve a ejecutar."
  exit 1
fi
c_ok "Helper AUR: $AUR_HELPER"

# ------------------------------------------------------------- 2. Dependencias
# quickshell NO figura en las dependencias de skwd-daemon-bin, pero el daemon
# dibuja el panel con el:  quickshell -p /usr/share/skwd/skwd-daemon/host/shell.qml
# Sin quickshell el daemon arranca pero el selector no aparece nunca.
if ! command -v quickshell >/dev/null 2>&1; then
  c_ok "Instalando quickshell (lo necesita el panel; no es dependencia declarada)..."
  sudo pacman -S --needed --noconfirm quickshell
else
  c_ok "quickshell presente: $(command -v quickshell)"
fi

if ! command -v skwd >/dev/null 2>&1; then
  c_ok "Instalando skwd-daemon-bin desde el AUR..."
  "$AUR_HELPER" -S --needed skwd-daemon-bin
else
  c_ok "skwd ya esta instalado: $(command -v skwd)"
fi

if ! command -v magick >/dev/null 2>&1; then
  c_ok "Instalando imagemagick (necesario para colorSource=magick)..."
  sudo pacman -S --needed --noconfirm imagemagick
else
  c_ok "imagemagick presente."
fi

# --------------------------------------------------- 3. Carpeta de wallpapers
if command -v xdg-user-dir >/dev/null 2>&1; then
  PICTURES="$(xdg-user-dir PICTURES)"
else
  PICTURES="$HOME/Pictures"
fi
WALLPAPER_DIR="${SKWD_WALLPAPER_DIR:-$PICTURES/wallpapers}"
mkdir -p "$WALLPAPER_DIR"
c_ok "Carpeta de wallpapers: $WALLPAPER_DIR"

if [ -z "$(find "$WALLPAPER_DIR" -maxdepth 1 -type f 2>/dev/null | head -1)" ]; then
  c_warn "La carpeta esta vacia. Mete imagenes ahi o descargalas desde"
  c_warn "la pestana Wallhaven del propio selector."
fi

# ------------------------------------ 4. Primer arranque (bootstrap de skwd)
c_ok "Habilitando skwd-daemon.service..."
systemctl --user enable skwd-daemon.service

if ! systemctl --user start skwd-daemon.service; then
  c_err "El servicio no arranco. Mira: journalctl --user -u skwd-daemon.service -n 50"
  exit 1
fi

# El servicio cuelga de graphical-session.target. Si tu sesion no lo levanta
# (Hyprland lanzado a pelo, sin uwsm), 'enable' no bastara en el proximo login.
if ! systemctl --user is-active --quiet graphical-session.target; then
  c_warn "graphical-session.target NO esta activo en tu sesion."
  c_warn "El daemon no arrancara solo al iniciar sesion. Anade a tu Hyprland:"
  c_warn "    exec-once = systemctl --user start skwd-daemon.service"
fi

# El daemon crea ~/.config/skwd-wall con sus plantillas la primera vez.
for _ in $(seq 1 20); do
  [ -d "$CONFIG_DIR" ] && break
  sleep 0.5
done

if [ ! -d "$CONFIG_DIR" ]; then
  c_err "skwd no creo $CONFIG_DIR. Revisa: systemctl --user status skwd-daemon.service"
  exit 1
fi

# -------------------------------------------------------- 5. Aplicar config
if [ -f "$CONFIG_FILE" ]; then
  BACKUP="$CONFIG_FILE.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP"
  c_ok "Backup de tu config anterior: $BACKUP"
fi

sed "s|__WALLPAPER_DIR__|$WALLPAPER_DIR|" "$REPO_DIR/config/config.json" > "$CONFIG_FILE"

# El post-procesado solo tiene sentido si usas Caelestia.
if ! command -v caelestia >/dev/null 2>&1; then
  c_warn "No detecto Caelestia: quito el post-procesado (postProcessing vacio)."
  c_warn "Sin el, skwd solo elige el fondo y no lo aplica nadie."
  c_warn "Lee la seccion 'Si no usas Caelestia' del README."
  python3 - "$CONFIG_FILE" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as fh:
    cfg = json.load(fh)
cfg["postProcessing"] = []
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
else
  c_ok "Caelestia detectado: el fondo se aplicara con 'caelestia wallpaper'."
fi

python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CONFIG_FILE"
c_ok "Config escrita en $CONFIG_FILE"

# ------------------------------------------- 6. Colores de arranque de la UI
# Con matugen desactivado skwd no genera ~/.cache/skwd-wall/colors.json, y sin
# ese archivo la barra superior del panel (filtros + engranaje) es INVISIBLE.
mkdir -p "$CACHE_DIR"
if [ ! -f "$CACHE_DIR/colors.json" ]; then
  cp "$REPO_DIR/config/colors.json" "$CACHE_DIR/colors.json"
  c_ok "Colores de arranque de la UI puestos (barra superior visible)."
else
  c_ok "Ya existe $CACHE_DIR/colors.json, lo respeto."
fi

# ------------------------------------------------------------ 7. Recargar
systemctl --user restart skwd-daemon.service
c_ok "Daemon reiniciado."

# ------------------------------------------------------------- 8. Keybind
# La sintaxis NO depende de la version de Hyprland, sino del formato de config
# que cargue: si existe hyprland.lua manda Lua, si no, hyprlang (.conf).
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
CAE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia"

if [ -f "$HYPR_DIR/hyprland.lua" ]; then
  FORMATO="lua"
elif [ -f "$HYPR_DIR/hyprland.conf" ]; then
  FORMATO="conf"
else
  FORMATO="desconocido"
fi

echo
echo "------------------------------------------------------------------"
echo "  ULTIMO PASO MANUAL: el atajo de teclado"
echo "------------------------------------------------------------------"

case "$FORMATO" in
  lua)
    if [ -f "$CAE_DIR/hypr-user.lua" ]; then
      DESTINO="$CAE_DIR/hypr-user.lua"
    else
      DESTINO="$HYPR_DIR/hyprland.lua"
    fi
    echo "  Tu Hyprland carga configuracion en Lua ($HYPR_DIR/hyprland.lua)."
    echo "  Pega esta linea en:  $DESTINO"
    echo
    echo '    hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("skwd wall toggle"))'
    ;;
  conf)
    if [ -f "$CAE_DIR/hypr-user.conf" ]; then
      DESTINO="$CAE_DIR/hypr-user.conf"
    else
      DESTINO="$HYPR_DIR/hyprland.conf"
    fi
    echo "  Tu Hyprland carga configuracion clasica (.conf, hyprlang)."
    echo "  Pega esta linea en:  $DESTINO"
    echo
    echo "    bind = SUPER SHIFT, T, exec, skwd wall toggle"
    echo
    echo "  OJO: la sintaxis 'hl.bind(...)' es de Lua y aqui NO hace nada."
    ;;
  *)
    echo "  No encuentro tu configuracion de Hyprland en $HYPR_DIR."
    echo "  Usa la linea que corresponda a tu formato:"
    echo
    echo "    .conf (hyprlang):  bind = SUPER SHIFT, T, exec, skwd wall toggle"
    echo '    .lua            :  hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("skwd wall toggle"))'
    ;;
esac

echo
echo "  Recarga con 'hyprctl reload' y pulsa Super + Shift + T."
echo "  Para probar el selector sin tocar nada:  skwd wall toggle"
echo "------------------------------------------------------------------"
