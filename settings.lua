BPSB = require("scripts/bpsb")
Settings = require("scripts/settings")

data:extend({
    {
        type = "bool-setting",
        name = Settings.allowAllTech,
        setting_type = "runtime-global",
        order = "a[common]-a",
        default_value = false,
    },
    {
        type = "bool-setting",
        name = Settings.scanSandboxes,
        setting_type = "runtime-global",
        order = "a[common]-b",
        default_value = false,
    },
    {
        type = "bool-setting",
        name = Settings.craftToCursor,
        setting_type = "runtime-per-user",
        order = "a[player]-a",
        default_value = true,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncTick,
        setting_type = "runtime-global",
        order = "b[god]-a",
        default_value = 15,
        minimum_value = 1,
        maximum_value = 120,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncCreateRequestsPerTick,
        setting_type = "runtime-global",
        order = "b[god]-b",
        default_value = 1000,
        minimum_value = 0,
        maximum_value = 10000,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncUpgradeRequestsPerTick,
        setting_type = "runtime-global",
        order = "b[god]-c",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 10000,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncDeleteRequestsPerTick,
        setting_type = "runtime-global",
        order = "b[god]-d",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 10000,
    },
})
