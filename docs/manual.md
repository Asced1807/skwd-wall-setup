# Detalles

Guía larga de `skwd-wall-setup`. Para instalar basta el [README](../README.md).

---

## Qué hace exactamente esta configuración

skwd trae muchísimas cosas (barra, launcher, menú de apagado, integración con
Steam, temas para media distro...). Aquí está **recortado a propósito**: quiero
un selector de wallpapers y nada más.

| Ajuste | Valor | Por qué |
|---|---|---|
| `pickOnlyMode` | `true` | Modo "solo elegir". Ni barra, ni launcher, ni menú de sesión. |
| `features.matugen` | `false` | El theming del sistema lo manda **wallust/Caelestia**. skwd no toca colores fuera de su propia UI. |
| `features.music` | `false` | El cliente de Spotify que trae skwd desde r90 deja un proceso zombi y un MPRIS fantasma. Ver *Problemas conocidos*. |
| `features.wallhaven` | `true` | Buscar y descargar wallpapers desde dentro del panel. |
| `features.steam` / `ollama` | `false` | No los uso; encienden servicios y peticiones de red para nada. |
| `colorSource` | `magick` | Extrae la paleta con ImageMagick, sin depender de matugen. |
| `postProcessing` | `caelestia wallpaper -n -f "%path%"` | skwd **elige** el fondo y Caelestia lo **aplica** y regenera su tema. |
| `wallpaperMute` | `true` | Los fondos de vídeo entran silenciados. |
| `integrations` | solo `colors.json` | Colorea la UI de skwd y nada más del sistema. |

En resumen: **skwd es el selector, Caelestia sigue mandando en el theming.**

---

## Poner el atajo a mano

La sintaxis depende del formato, no de la versión de Hyprland:

```bash
ls ~/.config/hypr/hyprland.lua 2>/dev/null && echo "-> usa Lua" || echo "-> usa .conf"
```

**Lua:**

```lua
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("skwd wall toggle"))
```

**`.conf`:**

```conf
bind = SUPER SHIFT, T, exec, skwd wall toggle
```

> Meter la sintaxis `.conf` en un archivo `.lua` **rompe la configuración**:
> Hyprland falla con `syntax error near 'toggle'`. Si te pasó, no lo arregles a
> mano — vuelve a ejecutar `./install.sh` y él quita las líneas malas (guardando
> copia) y pone las buenas.

## Si usas Caelestia

Caelestia manda en la configuración de Hyprland, así que el atajo va en **su**
archivo de usuario, no en el de Hyprland: `hypr-user.lua` o `hypr-user.conf`
según tu formato. Los dots de Caelestia se sobrescriben al actualizar; esos dos
archivos existen justo para lo que añades tú, y se cargan al final.

Y con **Caelestia en `.conf`** hay una trampa: sus binds viven dentro de
`submap = global` y la sesión se queda permanentemente en ese submap, así que
un `bind` suelto se registra en el submap por defecto —inactivo— y **no dispara
nunca**. Hay que envolverlo:

```conf
submap = global
bind = Super+Shift, T, exec, skwd wall toggle
submap = reset
```

Con **Caelestia en Lua** no hace falta: ahí los binds ya no usan submap y
`hl.bind(...)` vale tal cual.



## Instalación manual (sin el script)

Ejecuta esto desde la raíz del repositorio (no desde `docs/`):

```bash
# 1. Paquetes
sudo pacman -S --needed quickshell imagemagick
yay -S --needed skwd-daemon-bin

# 2. Carpeta de wallpapers
mkdir -p "$(xdg-user-dir PICTURES)/wallpapers"

# 3. Primer arranque: skwd crea ~/.config/skwd-wall con sus plantillas
systemctl --user enable --now skwd-daemon.service

# 4. Copiar mi config
cp ~/.config/skwd-wall/config.json ~/.config/skwd-wall/config.json.bak
sed "s|__WALLPAPER_DIR__|$(xdg-user-dir PICTURES)/wallpapers|" \
    config/config.json > ~/.config/skwd-wall/config.json

# 5. Colores de arranque de la UI (si no, la barra superior no se ve)
mkdir -p ~/.cache/skwd-wall
cp config/colors.json ~/.cache/skwd-wall/colors.json

# 6. Recargar
systemctl --user restart skwd-daemon.service
```

Y añade el keybind de `hypr/keybind.lua` o `hypr/keybind.conf`.

## Si no usas Caelestia

Con `postProcessing` vacío, skwd elige la imagen pero nadie la pinta. Tienes
dos salidas, editando `~/.config/skwd-wall/config.json`:

**a) Que la aplique skwd** con su propio motor. Quita el modo "solo elegir":

```json
"pickOnlyMode": false
```

La config trae `"paper": {"engine": "awww"}`, que es un motor ligero (~30-60 MB)
y **se instala aparte**:

```bash
yay -S awww
```

La alternativa es `"engine": "skwd-paper"`, que ya viene con el paquete y
soporta vídeo y Wallpaper Engine, pero come bastante más RAM (~180 MB).

**b) Que la aplique tu herramienta de siempre** (swww, hyprpaper, wallust...):

```json
"postProcessing": [
  { "command": "swww img \"%path%\" --transition-type any", "type": "all" }
]
```

`%path%` se sustituye por la ruta del fondo elegido. El `"type"` tiene que ser
`"all"`: con `"image"` no se dispara nunca, porque skwd clasifica las imágenes
internamente como `static`.

## Problemas conocidos

**El panel no abre y el daemon parece vivo.**
Casi siempre falta **quickshell**, que no es dependencia declarada del paquete.
Compruébalo:

```bash
command -v quickshell || sudo pacman -S quickshell
pgrep -af 'quickshell -p /usr/share/skwd'
```

**Hyprland dice `syntax error near 'toggle'` y se queda sin configuración.**
Alguien pegó la línea `.conf` (`bind = ...`) dentro de un archivo `.lua`. Lua no
entiende esa sintaxis y toda la config revienta. Solución:

```bash
cd skwd-wall-setup && ./install.sh
```

El instalador detecta las líneas en el formato equivocado, las quita dejando una
copia `.bak-<fecha>` al lado, y escribe la versión correcta.

**Pulso Super+Shift+T y no pasa nada.**
Separa los dos problemas posibles. Primero, en una terminal:

```bash
skwd wall toggle
```

- **Si el panel se abre**, el selector está bien y el fallo es el atajo: casi
  siempre la línea está en el formato equivocado (Lua dentro de un `.conf`, o
  al revés). Vuelve a *Poner el atajo a mano*.
- **Si no se abre**, el problema es skwd: mira si falta `quickshell` y revisa
  el daemon (abajo).

**El daemon no arranca al iniciar sesión.**
`skwd-daemon.service` cuelga de `graphical-session.target`. Ese target no lo
levanta Hyprland por sí mismo, sino el gestor de sesión: con `uwsm` la cadena es
`wayland-wm@hyprland.desktop.service` → `wayland-session@hyprland.desktop.target`
→ `graphical-session.target`. Si lanzas Hyprland a pelo, el target nunca se
activa y `systemctl --user enable` no sirve de nada.

El unit del paquete está bien (`PartOf`, `After` y `WantedBy` correctos): no hay
que editarlo, y editarlo sería peor porque se pierde en cada actualización. El
instalador comprueba el target y, si no está activo, añade el arranque a tu
configuración de Hyprland:

```conf
exec-once = systemctl --user start skwd-daemon.service
```

En Lua, su equivalente:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start skwd-daemon.service")
end)
```

Comprueba en qué situación estás con:

```bash
systemctl --user is-active graphical-session.target
```

**La barra superior del panel (filtros + engranaje) no se ve.**
Le falta `~/.cache/skwd-wall/colors.json`. Con `features.matugen: false` skwd
no lo genera, por eso este repo trae uno de arranque. Cópialo:

```bash
cp config/colors.json ~/.cache/skwd-wall/colors.json
```

Dentro del panel también se puede alternar con `Shift + ↑`.

**`skwd --help` no existe y además rompe el daemon.**
La opción no está implementada, y al lanzarla el proceso **se queda con el
socket** del daemon. Usa siempre `skwd help`. Si te pasa:
`systemctl --user restart skwd-daemon.service`.

**El reproductor de música deja un zombi.**
Desde la r90 skwd trae un cliente de Spotify propio cuya interfaz no llega a
dibujarse: queda un proceso colgado y un reproductor MPRIS fantasma que
confunde a las barras (Waybar, Caelestia...). Por eso `features.music` va en
`false`. No lo enciendas salvo que upstream lo arregle.

**La carpeta de wallpapers sale vacía.**
`paths.wallpaper` tiene que ser una ruta real. En sistemas en español es
`~/Imágenes/wallpapers`, con acento — si copias una config a ciegas, la ruta
`~/Pictures/wallpapers` no existirá. Tras cambiarla hace falta
`systemctl --user restart skwd-daemon.service`: recargar la config **no**
reescanea la carpeta.

**Diagnóstico general:**

```bash
systemctl --user status skwd-daemon.service
journalctl --user -u skwd-daemon.service -n 50
```

