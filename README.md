# skwd-wall setup — selector de wallpapers para Hyprland

Mi configuración del selector de fondos de pantalla **skwd-wall** en Hyprland:
un panel a pantalla completa que se abre con `Super + Shift + T`, muestra tus
wallpapers, deja buscar y descargar más desde Wallhaven, y aplica el fondo.

> **Importante:** el selector no es código mío. Es
> [`skwd-daemon`](https://github.com/liixini/skwd-daemon) de **liixini** (MIT).
> Este repositorio contiene **mi configuración y mi integración**: el perfil
> "solo selector", el atajo de teclado, el enganche con Caelestia y un
> instalador que lo deja todo listo de una pasada.

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

## Requisitos

- Arch Linux o derivada (CachyOS, EndeavourOS...) con `yay` o `paru`
- Hyprland
- `imagemagick` (lo instala el script si falta)
- *Opcional:* [Caelestia](https://github.com/caelestia-dots/shell) para el
  post-procesado. Sin él el selector funciona igual, pero hay que decirle
  a skwd cómo pintar el fondo (ver más abajo).

---

## Instalación

```bash
git clone https://github.com/Asced1807/skwd-wall-setup.git
cd skwd-wall-setup
./install.sh
```

El script:

1. Instala `skwd-daemon-bin` desde el AUR e `imagemagick` si faltan.
2. Crea la carpeta de wallpapers (`~/Imágenes/wallpapers` o su equivalente
   según tu idioma, detectado con `xdg-user-dir`).
3. Habilita y arranca `skwd-daemon.service` (servicio de usuario) para que
   genere sus plantillas.
4. Hace **copia de seguridad** de tu `config.json` anterior si existía y
   escribe el mío.
5. Si no encuentra Caelestia, vacía `postProcessing` para que no falle.
6. Te imprime la línea del atajo que tienes que pegar en Hyprland.

Para usar otra carpeta de wallpapers:

```bash
SKWD_WALLPAPER_DIR="$HOME/Fondos" ./install.sh
```

### El último paso es manual: el atajo

No toco tu configuración de Hyprland. Añade **una** de estas líneas:

**Hyprland en Lua** (0.57 en adelante — en un setup Caelestia va en
`~/.config/caelestia/hypr-user.lua`):

```lua
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("skwd wall toggle"))
```

**Hyprland clásico** (`.conf`):

```conf
bind = SUPER SHIFT, T, exec, skwd wall toggle
```

Recarga Hyprland y pulsa `Super + Shift + T`.

---

## Instalación manual (sin el script)

```bash
# 1. Paquetes
yay -S --needed skwd-daemon-bin
sudo pacman -S --needed imagemagick

# 2. Carpeta de wallpapers
mkdir -p "$(xdg-user-dir PICTURES)/wallpapers"

# 3. Primer arranque: skwd crea ~/.config/skwd-wall con sus plantillas
systemctl --user enable --now skwd-daemon.service

# 4. Copiar mi config (cambia la ruta por la tuya)
cp ~/.config/skwd-wall/config.json ~/.config/skwd-wall/config.json.bak
sed "s|__WALLPAPER_DIR__|$(xdg-user-dir PICTURES)/wallpapers|" \
    config/config.json > ~/.config/skwd-wall/config.json

# 5. Recargar
systemctl --user restart skwd-daemon.service
```

Y añade el keybind de `hypr/keybind.lua` o `hypr/keybind.conf`.

---

## Uso

| Acción | Comando |
|---|---|
| Abrir/cerrar el selector | `skwd wall toggle` (`Super + Shift + T`) |
| Solo abrir | `skwd wall show` |
| Solo cerrar | `skwd wall hide` |
| Ver todos los comandos | `skwd help` |

Dentro del panel: navegas por tu carpeta, y en la pestaña de **Wallhaven**
buscas y descargas fondos nuevos, que caen directamente en tu carpeta.

---

## Si no usas Caelestia

Con `postProcessing` vacío, skwd elige la imagen pero nadie la pinta. Tienes
dos salidas, editando `~/.config/skwd-wall/config.json`:

**a) Que la aplique skwd** con su propio motor (`awww`): quita `pickOnlyMode`.

```json
"pickOnlyMode": false
```

**b) Que la aplique tu herramienta de siempre** (swww, hyprpaper, wallust...):

```json
"postProcessing": [
  { "command": "swww img \"%path%\" --transition-type any", "type": "all" }
]
```

`%path%` se sustituye por la ruta del fondo elegido.

---

## Problemas conocidos

**`skwd --help` no existe y además rompe el daemon.**
La opción no está implementada, y al lanzarla el proceso **se queda con el
socket** del daemon. Usa siempre `skwd help`. Si te pasa:
`systemctl --user restart skwd-daemon.service`.

**El reproductor de música deja un zombi.**
Desde la r90 skwd trae un cliente de Spotify propio cuya interfaz no llega a
dibujarse: queda un proceso colgado y un reproductor MPRIS fantasma que
confunde a las barras (Waybar, Caelestia...). Por eso `features.music` va en
`false`. No lo enciendas salvo que upstream lo arregle.

**El panel no abre.**
Comprueba el daemon antes que nada:

```bash
systemctl --user status skwd-daemon.service
journalctl --user -u skwd-daemon.service -n 50
```

**La carpeta de wallpapers no aparece.**
`paths.wallpaper` tiene que ser una ruta real. En sistemas en español es
`~/Imágenes/wallpapers`, con acento — si copias la config de otro sitio a
ciegas, la ruta `~/Pictures/wallpapers` no existirá y verás el panel vacío.

---

## Desinstalar

```bash
systemctl --user disable --now skwd-daemon.service
yay -Rns skwd-daemon-bin
rm -rf ~/.config/skwd-wall
```

Y quita el keybind de tu configuración de Hyprland.

---

## Créditos

- [**skwd-daemon**](https://github.com/liixini/skwd-daemon) — liixini (MIT).
  Todo el mérito del selector es suyo.
- [**Caelestia**](https://github.com/caelestia-dots/shell) — la shell con la
  que se integra.

La configuración y los scripts de este repositorio están bajo licencia MIT.
