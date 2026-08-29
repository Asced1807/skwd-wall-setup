#!/usr/bin/env python3
"""Cuenta binds Super+Shift+<tecla> en la salida de 'hyprctl binds -j'."""
import json
import sys

try:
    binds = json.load(sys.stdin)
except Exception:
    print(-1)
    raise SystemExit

tecla = sys.argv[1].upper()
print(sum(1 for b in binds if b.get("key", "").upper() == tecla and b.get("modmask") == 65))
