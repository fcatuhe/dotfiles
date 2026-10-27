-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 2

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. G34WQCP 25015B005144", mode = "preferred", position = "auto-center-up", scale = 1.25 })
hl.monitor({ output = "desc:LG Electronics LG ULTRAFINE", mode = "preferred", position = "auto-center-up", scale = 2 })

-- Make the LG UltraFine the main display when connected: workspaces 1-10 move to it.
for workspace = 1, 10 do
  hl.workspace_rule({ workspace = tostring(workspace), monitor = "desc:LG Electronics LG ULTRAFINE" })
end

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
