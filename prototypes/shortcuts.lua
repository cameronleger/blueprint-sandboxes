data:extend({
    {
        type = "custom-input",
        name = ToggleGUI.toggleShortcut,
        order = "a[toggle]",
        key_sequence = "SHIFT + B"
    },
    {
        type = "shortcut",
        name = ToggleGUI.toggleShortcut,
        order = "b[blueprints]-z[sandbox]",
        action = "lua",
        associated_control_input = ToggleGUI.toggleShortcut,
        style = "blue",
        toggleable = true,
        icon = BPSB.path .. "/graphics/icon-x32.png",
        icon_size = 32,
        -- TODO: Small Icon
        small_icon = BPSB.path .. "/graphics/icon-x32.png",
        small_icon_size = 32,
    },
    {
        type = "custom-input",
        name = SurfacePropsGUI.cancel,
        key_sequence = "",
        linked_game_control = "toggle-menu",
    },
    {
        type = "custom-input",
        name = SurfacePropsGUI.confirm,
        key_sequence = "",
        linked_game_control = "confirm-gui",
    },
})
