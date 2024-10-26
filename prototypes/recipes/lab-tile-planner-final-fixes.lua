PlannerIcons = require("scripts.planner-icons")
Tiles = require("scripts.tiles")

data:extend({
    {
        type = "selection-tool",
        name = Tiles.labTilePlanner,
        icons = PlannerIcons.CreateLayeredIcon(data.raw.tile["lab-dark-1"]),
        subgroup = Tiles.name,
        order = "0",
        hidden_in_factoriopedia = true,
        stack_size = 1,
        select = {
            border_color = { r = 0, g = 0, b = 1 },
            cursor_box_type = "pair",
            mode = { "any-tile" },
        },
        alt_select = {
            border_color = { r = 0, g = 0, b = 1 },
            cursor_box_type = "pair",
            mode = { "any-tile" },
        },
        always_include_tiles = true,
        flags = { "not-stackable", "only-in-cursor" },
    },
    {
        type = "recipe",
        name = Tiles.labTilePlanner,
        hidden_in_factoriopedia = true,
        energy_required = 1,
        enabled = false,
        ingredients = {},
        results = {
            { type = "item", name = Tiles.labTilePlanner, amount = 1 },
        },
        hide_from_stats = true,
    }
})
