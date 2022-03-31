BPSB = require("scripts/bpsb")
Settings = require("scripts/settings")

data:extend({
    {
        type = "bool-setting",
        name = Settings.allowAllTech,
        setting_type = "runtime-global",
        order = "a",
        default_value = false,
    },
    {
        type = "bool-setting",
        name = Settings.scanSandboxes,
        setting_type = "runtime-global",
        order = "b",
        default_value = false,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncTick,
        setting_type = "runtime-global",
        order = "c",
        default_value = 15,
        minimum_value = 1,
        maximum_value = 120,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncCreateRequestsPerTick,
        setting_type = "runtime-global",
        order = "d",
        default_value = 1000,
        minimum_value = 0,
        maximum_value = 10000,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncUpgradeRequestsPerTick,
        setting_type = "runtime-global",
        order = "e",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 10000,
    },
    {
        type = "int-setting",
        name = Settings.godAsyncDeleteRequestsPerTick,
        setting_type = "runtime-global",
        order = "f",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 10000,
    },
})
