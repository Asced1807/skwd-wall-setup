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

# ---------------------------------------------------------------- 1. Requisitos
if ! command -v caelestia >/dev/null 2>&1; then
  c_err "Esto es una extension de Caelestia y no lo encuentro."
  c_err "Sin Caelestia no hay paleta que copiar:  https://github.com/caelestia-dots/shell"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  c_err "Falta python3 (el hook esta escrito en Python)."
  exit 1
fi

command -v nemo  >/dev/null 2>&1 || c_warn "Nemo no esta instalado: el CSS se generara igual, sin efecto visible."
command -v kitty >/dev/null 2>&1 || c_warn "kitty no esta instalado: se omitira su parte."

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
if command -v kitty >/dev/null 2>&1; then
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

echo "------------------------------------------------------------------"
echo "  Listo. Cambia de fondo y Nemo y kitty cambiaran con el."
echo "------------------------------------------------------------------"
