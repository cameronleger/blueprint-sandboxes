-- New Group for New Recipes
data:extend({
    {
        type = "item-group",
        name = BPSB.name,
        icon = BPSB.path .. "/graphics/icon-x64.png",
        icon_size = 64,
        inventory_order = "z",
        order = "z",
    },
    {
        type = "item-subgroup",
        name = BPSB.pfx .. "loaders",
        group = BPSB.name,
        order = "a[loaders]",
    },
    {
        type = "item-subgroup",
        name = BPSB.pfx .. "infinity",
        group = BPSB.name,
        order = "b[infinity]",
    },
})

function createLockedRecipeForHiddenItem(name)
    return
    {
        type = "recipe",
        name = BPSB.pfx .. name,
        energy_required = 1,
        enabled = false,
        ingredients = {},
        result = name,
    }
end

-- Recipes for hidden/infinity items, only unlocked in Lab
data:extend({
    createLockedRecipeForHiddenItem("loader"),
    createLockedRecipeForHiddenItem("fast-loader"),
    createLockedRecipeForHiddenItem("express-loader"),
    createLockedRecipeForHiddenItem("electric-energy-interface"),
    createLockedRecipeForHiddenItem("infinity-chest"),
    createLockedRecipeForHiddenItem("infinity-pipe"),
})
