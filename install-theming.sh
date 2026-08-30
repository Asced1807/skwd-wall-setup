#!/usr/bin/env bash
# Extension opcional: que el cambio de fondo repinte tambien Nemo y kitty.
#
# Caelestia ya recolorea su barra y las apps GTK al aplicar un wallpaper, pero
# se queda ahi. Este script instala un postHook que, cada vez que Caelestia
# recalcula la paleta, regenera desde ella el CSS de Nemo y el tema de kitty.
#
# Idempotente: se puede volver a ejecutar sin romper nada.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CAE_DIR="$CONFIG_HOME/caelestia"
CLI_JSON="$CAE_DIR/cli.json"
BIN_DIR="$HOME/.local/bin"
HOOK="$BIN_DIR/caelestia-to-nemo"
KITTY_CONF="$CONFIG_HOME/kitty/kitty.conf"
KITTY_INCLUDE="kitty-themes/01-Wallust.conf"
SCHEME="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json"
# Sobrescribibles: para instalaciones de Caelestia fuera de lo normal (y para
# poder probar este script sin tenerla instalada).
CAELESTIA_BIN="${CAELESTIA_BIN:-caelestia}"
CAELESTIA_QML="${CAELESTIA_QML:-/etc/xdg/quickshell/caelestia}"
STAMP="$(date +%Y%m%d-%H%M%S)"

c_ok()   { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
c_err()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; }

# copia_con_backup ORIGEN DESTINO
copia_con_backup() {
  local src="$1" dst="$2"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "$dst.bak-$STAMP"
    c_ok "Backup: $dst.bak-$STAMP"
  fi
  install -Dm644 "$src" "$dst"
}

# ------------------------------------------------------------ 0. Utilidades
# AUTO_YES=1 (o -y) instala todo sin preguntar. Sin terminal interactiva se
# asume que no: nadie puede contestar, y no se instala nada a escondidas.
AUTO_YES="${AUTO_YES:-}"
case "${1:-}" in -y|--yes) AUTO_YES=1 ;; esac

confirmar() {
  [ -n "$AUTO_YES" ] && return 0
  [ -t 0 ] || return 1
  printf '    %s [S/n] ' "$1"
  local resp
  read -r resp || resp=""
  case "$resp" in [nN]*) return 1 ;; *) return 0 ;; esac
}

# Devuelve por stdout el helper AUR, instalando yay si hace falta y se acepta.
helper_aur() {
  local h
  for h in yay paru; do
    if command -v "$h" >/dev/null 2>&1; then echo "$h"; return 0; fi
  done

  c_warn "No tienes ningun helper del AUR (yay o paru), y hacen falta"        >&2
  c_warn "para instalar Caelestia."                                            >&2
  if ! confirmar "Instalo yay?" >&2; then return 1; fi

  sudo pacman -S --needed --noconfirm git base-devel >&2 || return 1
  local tmp
  tmp="$(mktemp -d)"
  git clone -q https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" >&2 || { rm -rf "$tmp"; return 1; }
  ( cd "$tmp/yay-bin" && makepkg -si --noconfirm >&2 ) || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  command -v yay >/dev/null 2>&1 && { echo yay; return 0; }
  return 1
}

instalar_repo() { sudo pacman -S --needed --noconfirm "$@"; }

instalar_aur() {
  local helper
  helper="$(helper_aur)" || return 1
  "$helper" -S --needed "$@"
}

# ---------------------------------------------------------------- 1. Requisitos
if ! command -v pacman >/dev/null 2>&1; then
  c_warn "No es Arch: no puedo instalar nada por ti."
  c_warn "Necesitas Caelestia (shell + cli) y python3 antes de seguir."
fi

# --- Caelestia: imprescindible, es quien calcula la paleta ---
FALTA_CAE=""
command -v "$CAELESTIA_BIN" >/dev/null 2>&1 || FALTA_CAE="caelestia-cli"
[ -d "$CAELESTIA_QML" ] || FALTA_CAE="$FALTA_CAE caelestia-shell"

if [ -n "$FALTA_CAE" ]; then
  c_warn "Falta Caelestia, que es quien calcula la paleta del fondo."
  c_warn "Paquetes del AUR que hacen falta:$FALTA_CAE"

  if ! command -v pacman >/dev/null 2>&1; then
    c_err "Instalalo a mano:  https://github.com/caelestia-dots/shell"
    exit 1
  fi

  if confirmar "Lo instalo ahora?"; then
    # shellcheck disable=SC2086
    if instalar_aur $FALTA_CAE; then
      c_ok "Caelestia instalada."
    else
      c_err "No he podido instalarla. Hazlo a mano y vuelve a ejecutarme:"
      c_err "    yay -S$FALTA_CAE"
      exit 1
    fi
  else
    c_err "Sin Caelestia esto no tiene nada de donde sacar los colores."
    c_err "Cuando la tengas, vuelve a ejecutarme."
    exit 1
  fi
fi

# --- python3: el hook esta escrito en Python ---
if ! command -v python3 >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1 && confirmar "Falta python3. Lo instalo?"; then
    instalar_repo python || { c_err "No he podido instalar python3."; exit 1; }
  else
    c_err "Falta python3 (el hook esta escrito en Python)."
    exit 1
  fi
fi

# --- Nemo y kitty: opcionales, cada uno se salta si no esta ---
USAR_NEMO="si"
if ! command -v nemo >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1 && confirmar "No tienes Nemo. Lo instalo?"; then
    instalar_repo nemo || USAR_NEMO="no"
  else
    USAR_NEMO="no"
    c_warn "Sin Nemo: genero su CSS igual, no estorba, pero no veras el efecto."
  fi
fi

USAR_KITTY="si"
if ! command -v kitty >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1 && confirmar "No tienes kitty. Lo instalo?"; then
    instalar_repo kitty || USAR_KITTY="no"
  else
    USAR_KITTY="no"
    c_warn "Sin kitty: me salto su tema."
  fi
fi

# ------------------------------------------------------------------- 2. Hook
mkdir -p "$BIN_DIR"
install -Dm755 "$REPO_DIR/theming/caelestia-to-nemo" "$HOOK"
c_ok "Hook instalado en $HOOK"

# -------------------------------------------------------------- 3. Plantillas
mkdir -p "$CAE_DIR"
copia_con_backup "$REPO_DIR/theming/nemo.css.template"   "$CAE_DIR/nemo.css.template"
copia_con_backup "$REPO_DIR/theming/kitty.conf.template" "$CAE_DIR/kitty.conf.template"
c_ok "Plantillas en $CAE_DIR (edita estas, nunca los archivos generados)."

# ------------------------------------------------------- 4. Registrar el hook
# cli.json puede tener mas ajustes tuyos: solo se toca theme.postHook.
if [ -f "$CLI_JSON" ]; then
  cp "$CLI_JSON" "$CLI_JSON.bak-$STAMP"
  c_ok "Backup: $CLI_JSON.bak-$STAMP"
fi

python3 - "$CLI_JSON" "$HOOK" <<'PY'
import json, os, sys

path, hook = sys.argv[1], sys.argv[2]
try:
    with open(path) as fh:
        cfg = json.load(fh)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as exc:
    sys.exit(f"cli.json no es JSON valido ({exc}); arreglalo o borralo y repite.")

if not isinstance(cfg, dict):
    sys.exit("cli.json no contiene un objeto JSON; arreglalo y repite.")

cfg.setdefault("theme", {})["postHook"] = hook

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=4)
    fh.write("\n")
PY
c_ok "theme.postHook registrado en $CLI_JSON"

# -------------------------------------------------------------- 5. kitty
# El hook escribe el tema en kitty-themes/01-Wallust.conf (nombre heredado de
# wallust); kitty solo lo carga si su config lo incluye.
if [ "$USAR_KITTY" = "si" ]; then
  # Marcador para que kitty no avise de un include inexistente mientras no
  # hayas cambiado de fondo por primera vez.
  KITTY_THEME_OUT="$CONFIG_HOME/kitty/$KITTY_INCLUDE"
  if [ ! -f "$KITTY_THEME_OUT" ]; then
    mkdir -p "$(dirname "$KITTY_THEME_OUT")"
    printf '# Lo rellena caelestia-to-nemo en el primer cambio de fondo.\n' > "$KITTY_THEME_OUT"
  fi

  if [ ! -f "$KITTY_CONF" ]; then
    mkdir -p "$(dirname "$KITTY_CONF")"
    printf 'include %s\n' "$KITTY_INCLUDE" > "$KITTY_CONF"
    c_ok "kitty.conf creado con el include del tema."
  elif grep -q "$KITTY_INCLUDE" "$KITTY_CONF"; then
    c_ok "kitty.conf ya incluye el tema generado."
  else
    cp "$KITTY_CONF" "$KITTY_CONF.bak-$STAMP"
    printf '\n# Tema dinamico generado por caelestia-to-nemo\ninclude %s\n' "$KITTY_INCLUDE" >> "$KITTY_CONF"
    c_ok "include anadido a kitty.conf (backup: $KITTY_CONF.bak-$STAMP)"
  fi
fi

# ------------------------------------- 5.4 Reparar el enlace con skwd
# Si instalaste skwd ANTES que Caelestia, su install.sh dejo postProcessing
# vacio a proposito (no habia nada que aplicara el fondo). Ahora que Caelestia
# esta, ese hueco significa que elegir fondo no dispara absolutamente nada.
SKWD_CONF="$CONFIG_HOME/skwd-wall/config.json"
if [ -f "$SKWD_CONF" ]; then
  if python3 -c "
import json, sys
try:
    cfg = json.load(open('$SKWD_CONF'))
except Exception:
    sys.exit(1)
sys.exit(0 if not cfg.get('postProcessing') else 1)
" 2>/dev/null; then
    c_warn "skwd esta instalado pero no aplica el fondo con Caelestia"
    c_warn "(postProcessing vacio: pasa si instalaste skwd antes que Caelestia)."
    if confirmar "Lo conecto?"; then
      cp "$SKWD_CONF" "$SKWD_CONF.bak-$STAMP"
      python3 -c "
import json
p = '$SKWD_CONF'
cfg = json.load(open(p))
cfg['postProcessing'] = [{'command': 'caelestia wallpaper -n -f \"%path%\"', 'type': 'all'}]
json.dump(cfg, open(p, 'w'), indent=2)
open(p, 'a').write('\n')
"
      systemctl --user restart skwd-daemon.service 2>/dev/null || true
      c_ok "skwd conectado con Caelestia (backup: $(basename "$SKWD_CONF").bak-$STAMP)."
    fi
  fi
fi

# ------------------------------------------------ 5.5 Esquema dinamico
# LO MAS IMPORTANTE, y lo que mas despista: Caelestia trae de fabrica un
# esquema FIJO (catppuccin, gruvbox...). Con un esquema fijo la paleta no sale
# del fondo, asi que puedes tener el hook perfectamente instalado y no ver
# cambiar ni un color al cambiar de wallpaper.
SCHEME_ACTUAL="$("$CAELESTIA_BIN" scheme get -n 2>/dev/null || true)"

if [ "$SCHEME_ACTUAL" = "dynamic" ]; then
  c_ok "Esquema de color: dynamic (sale del fondo)."
elif [ -z "$SCHEME_ACTUAL" ]; then
  c_warn "No he podido leer el esquema actual (la shell puede estar parada)."
  c_warn "Comprueba luego:  caelestia scheme get -n   ->  tiene que decir 'dynamic'"
else
  c_warn "Tu esquema es '$SCHEME_ACTUAL', no 'dynamic': los colores salen de una"
  c_warn "paleta fija y NO del fondo. Es justo lo que impide ver cambios."
  if confirmar "Lo pongo en dynamic?"; then
    if "$CAELESTIA_BIN" scheme set -n dynamic; then
      c_ok "Esquema dinamico activado."
    else
      c_err "No he podido cambiarlo. Hazlo a mano:  caelestia scheme set -n dynamic"
    fi
  else
    c_warn "Sin 'dynamic' no veras ningun cambio. Cuando quieras:"
    c_warn "    caelestia scheme set -n dynamic"
  fi
fi

# ------------------------------------------------------ 6. Primera pasada
if [ -f "$SCHEME" ]; then
  if "$HOOK"; then
    c_ok "Colores aplicados con la paleta actual."
  else
    c_err "El hook ha fallado. Ejecutalo a mano para ver el error:  $HOOK"
    exit 1
  fi
else
  c_warn "Aun no existe $SCHEME."
  c_warn "Aplica un fondo (Super + Shift + T) y los colores se generaran solos."
fi

# ------------------------------------------------------ 7. Comprobacion
# Nada de "listo" a ciegas: se comprueba una por una cada pieza.
fallos=0
avisos=0

# check: piezas que instala este script. Si fallan, es un fallo de verdad.
check() {
  if eval "$2" >/dev/null 2>&1; then
    printf '    \033[1;32m[ok]\033[0m    %s\n' "$1"
  else
    printf '    \033[1;31m[FALLA]\033[0m %s\n' "$1"
    fallos=$((fallos + 1))
  fi
}

# aviso: cosas que dependen de que Caelestia ya haya pintado alguna vez.
# En una instalacion recien hecha es normal que aun no esten.
aviso() {
  if eval "$2" >/dev/null 2>&1; then
    printf '    \033[1;32m[ok]\033[0m    %s\n' "$1"
  else
    printf '    \033[1;33m[aviso]\033[0m %s\n' "$1"
    printf '             %s\n' "$3"
    avisos=$((avisos + 1))
  fi
}

echo
echo "------------------------------------------------------------------"
echo "  COMPROBACION"
echo "------------------------------------------------------------------"
check "hook ejecutable en ~/.local/bin"      "[ -x '$HOOK' ]"
check "plantilla de Nemo"                    "[ -f '$CAE_DIR/nemo.css.template' ]"
check "plantilla de kitty"                   "[ -f '$CAE_DIR/kitty.conf.template' ]"
aviso "esquema dinamico activo"               "[ \"\$('$CAELESTIA_BIN' scheme get -n 2>/dev/null)\" = dynamic ]" \
      "sin esto los colores no salen del fondo:  caelestia scheme set -n dynamic"
check "cli.json es JSON valido"              "python3 -c \"import json;json.load(open('$CLI_JSON'))\""
check "postHook apunta al hook"              "python3 -c \"import json,sys;sys.exit(0 if json.load(open('$CLI_JSON')).get('theme',{}).get('postHook')=='$HOOK' else 1)\""
[ "$USAR_KITTY" = "si" ] && check "kitty.conf incluye el tema" "grep -q '$KITTY_INCLUDE' '$KITTY_CONF'"

if [ -f "$SCHEME" ]; then
  check "nemo.css generado (gtk-3.0)"        "[ -s '$CONFIG_HOME/gtk-3.0/nemo.css' ]"
  aviso "gtk.css lo importa"                 "grep -q 'nemo.css' '$CONFIG_HOME/gtk-3.0/gtk.css'" \
        "lo escribe Caelestia al aplicar un tema; aplica un fondo y se arregla solo"
fi

echo "------------------------------------------------------------------"
if [ "$fallos" -eq 0 ] && [ "$avisos" -gt 0 ]; then
  c_warn "Instalado correctamente, con $avisos aviso(s) arriba: se resuelven"
  c_warn "solos en cuanto apliques un fondo con Caelestia."
elif [ "$fallos" -eq 0 ]; then
  if [ -f "$SCHEME" ]; then
    c_ok "Todo en orden. Cambia de fondo y Nemo y kitty cambiaran con el."
  else
    c_ok "Todo en orden. Aplica un fondo y ya cambiaran solos."
    c_warn "Si acabas de instalar Caelestia, arrancala antes:  caelestia shell -d"
  fi
else
  c_err "$fallos comprobacion(es) han fallado; mira las lineas [FALLA] de arriba."
  exit 1
fi
