-- data.lua
data:extend({
    {
        type = "shortcut",
        name = "toggle-machine-exp-gui",  -- Update this to match your control.lua listener
        order = "a[machine-exp]",
        action = "lua",  -- This triggers a Lua event
        localised_name = {"shortcut.toggle-machine-exp-gui"},  -- Ensure this key exists in your locale
        associated_control_input = "toggle-machine-exp-key",  -- Connects to the keybinding
        icon = "__base__/graphics/icons/shortcut-toolbar/mip/alt-mode-x56.png",  -- Use a base game icon path
        icon_size = 56,  -- Size of the icon
        small_icon = "__base__/graphics/icons/shortcut-toolbar/mip/alt-mode-x24.png",  -- Small icon path
        small_icon_size = 24,  -- Size of the small icon
        toggleable = true  -- Makes the button act as a toggle
    },
    {
        type = "custom-input",
        name = "toggle-machine-exp-key",
        key_sequence = "CONTROL + M",  -- Key sequence for the keybind
        consuming = "none"
    }
})
