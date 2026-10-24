-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- INFO: fc 11sep26 AltGr + Caps Lock moves the digit lock, which Hyprland raises no event for
hl.bind("Caps_Lock", hl.dsp.event("digitlock"), { non_consuming = true, release = true, ignore_mods = true })

-- INFO: fc 25sep26 the ThinkPad star key reports press and release together, so it can only toggle
o.bind("XF86Favorites", "Toggle dictation", "voxtype record toggle")

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

-- INFO: fc 17oct26 down and up are split like Omarchy's clipboard.lua, send_shortcut can leave keys stuck
local function send_keys(chords)
  local delay = 0
  for _, chord in ipairs(chords) do
    for _, state in ipairs({ "down", "up" }) do
      hl.timer(function()
        hl.dispatch(hl.dsp.send_key_state({ mods = chord[1], key = chord[2], state = state }))
      end, { timeout = delay + 1, type = "oneshot" })
      delay = delay + 20
    end
  end
end

o.bind("CTRL + BACKSPACE", "Delete previous word", function()
  if active_window_is_terminal() then
    send_keys({ { "ALT", "BackSpace" } })
  else
    send_keys({ { "CTRL", "BackSpace" } })
  end
end, { repeating = true })

o.bind("ALT + BACKSPACE", "Delete to start of line", function()
  if active_window_is_terminal() then
    send_keys({ { "CTRL", "U" } })
  else
    send_keys({ { "SHIFT", "Home" }, { "", "BackSpace" } })
  end
end)

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
