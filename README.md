# skwd-wall setup

Selector de fondos de pantalla para Hyprland. `Super + Shift + T` abre un panel
con tus wallpapers en forma de panal, y desde ahí también puedes buscar y
descargar más de Wallhaven.

> El selector no es código mío: es
> [skwd-daemon](https://github.com/liixini/skwd-daemon) de **liixini** (MIT).
> Esto es mi configuración, más un instalador que lo deja funcionando.

---

## Instalar

Necesitas **Arch** (o CachyOS, EndeavourOS...) con `yay` o `paru`, y **Hyprland**.

```bash
git clone https://github.com/Asced1807/skwd-wall-setup.git
cd skwd-wall-setup
./install.sh
```

Te pedirá la contraseña de `sudo` para los paquetes y una confirmación antes de
tocar tu configuración de Hyprland. El resto lo hace solo:

- Instala lo que falte: `quickshell`, `skwd-daemon-bin` (AUR) e `imagemagick`.
- Crea tu carpeta de wallpapers y aplica la configuración.
- **Pone el atajo él mismo** en el archivo correcto: detecta si tu Hyprland usa
  Lua o `.conf`, y si mandan los dots de Caelestia.
- Guarda copia (`.bak-<fecha>`) de todo lo que toca y comprueba al final que el
  atajo responde.

## Usar

| | |
|---|---|
| Abrir / cerrar | `Super + Shift + T` (o `skwd wall toggle`) |
| Todos los comandos | `skwd help` |

Los wallpapers van en `~/Imágenes/wallpapers` (o `Pictures`, según tu idioma).
Si está vacía, descarga desde la pestaña **Wallhaven** del panel.

## Opciones

| Quiero... | Comando |
|---|---|
| Otra carpeta | `SKWD_WALLPAPER_DIR=~/Fondos ./install.sh` |
| Otra tecla | `SKWD_BIND_KEY=W ./install.sh` |
| Que no toque mi config de Hyprland | `SKWD_NO_BIND=1 ./install.sh` |
| Que no pregunte nada | `SKWD_YES=1 ./install.sh` |

## Colores que siguen al fondo (opcional)

Caelestia ya recolorea su barra y las apps GTK con cada fondo nuevo, pero se
queda ahí. Con esto **Nemo y kitty también cambian de color** con el wallpaper:

```bash
./install-theming.sh
```

Instala un `postHook` que, cada vez que Caelestia recalcula su paleta, regenera
desde ella el CSS de Nemo y el tema de kitty. La cadena completa queda así:

```
Super+Shift+T → eliges fondo → caelestia wallpaper → paleta Material You
                                                   → barra y apps GTK (Caelestia)
                                                   → Nemo y kitty (este hook)
```

Necesita Caelestia y `python3`. Detalle y personalización en
[docs/manual.md](docs/manual.md#colores-que-siguen-al-fondo). El resto de mis
ajustes de Caelestia (barra, atajos, parches) está en
[caelestia-config](https://github.com/Asced1807/caelestia-config).

## Si algo falla

**El panel no abre.** Casi siempre falta `quickshell`, que no es dependencia
declarada del paquete: `sudo pacman -S quickshell`.

**Tras reiniciar, el daemon aparece muerto.** El servicio del paquete cuelga de
`graphical-session.target`, que levanta uwsm. Si lanzas Hyprland sin uwsm ese
target no se activa nunca: `./install.sh` lo detecta y añade el arranque a tu
configuración de Hyprland.

**Pulso el atajo y no pasa nada.** Prueba `skwd wall toggle` en una terminal. Si
el panel abre, el problema es el atajo: vuelve a ejecutar `./install.sh`.

**Hyprland dice `syntax error near 'toggle'`.** Pegaste la línea `.conf` dentro
de un archivo `.lua`. No lo arregles a mano: `./install.sh` quita lo malo
(dejando copia) y pone lo bueno.

**Cualquier otra cosa:**

```bash
systemctl --user status skwd-daemon.service
journalctl --user -u skwd-daemon.service -n 50
```

## Más

- [**docs/manual.md**](docs/manual.md) — qué hace cada ajuste, instalación paso
  a paso sin el script, uso sin Caelestia y la lista completa de problemas.
- Desinstalar:

  ```bash
  systemctl --user disable --now skwd-daemon.service
  yay -Rns skwd-daemon-bin
  rm -rf ~/.config/skwd-wall ~/.cache/skwd-wall
  ```

## Créditos

[skwd-daemon](https://github.com/liixini/skwd-daemon) de liixini (MIT) — todo el
mérito del selector es suyo. Se integra con
[Caelestia](https://github.com/caelestia-dots/shell).
Esta configuración y sus scripts, bajo licencia MIT.
