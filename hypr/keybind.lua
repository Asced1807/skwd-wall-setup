-- Selector de wallpapers skwd-wall
-- Para Hyprland con configuracion en LUA (existe ~/.config/hypr/hyprland.lua).
-- Si tu Hyprland usa el .conf clasico, esta linea NO hace nada: usa keybind.conf.
--
-- Destino: ~/.config/hypr/hyprland.lua
--          o ~/.config/caelestia/hypr-user.lua en un setup Caelestia.

hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("skwd wall toggle"))
