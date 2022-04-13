-- Required by basically everything immediately
BPSB = require("scripts.bpsb")
Settings = require("scripts.settings")
Debug = require("scripts.debug")

-- Required, but not ordered importantly
Init = require("scripts.init")
God = require("scripts.god")
Lab = require("scripts.lab")
Migrate = require("scripts.migrate")
Research = require("scripts.research")
Resources = require("scripts.resources")
ToggleGUI = require("scripts.toggle-gui")

-- Required by Sandbox
SpaceExploration = require("scripts.space-exploration")

-- Requires SpaceExploration method immediately
Sandbox = require("scripts.sandbox")

-- Initializations

script.on_init(function()
    Init.FirstTimeInit()
    Settings.SetupConditionalHandlers()
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    Init.Force(player.force)
    Init.Player(player)
end)

script.on_event(defines.events.on_player_removed, function(event)
    Lab.DeleteLab(global.players[event.player_index].labName)
    global.players[event.player_index] = nil
end)

script.on_event(defines.events.on_force_created, function(event)
    Init.Force(event.force)
end)

-- Conditional Event Listeners

script.on_load(Settings.SetupConditionalHandlers)

script.on_event(defines.events.on_runtime_mod_setting_changed, Settings.OnRuntimeSettingChanged)

-- Important Game Events

script.on_configuration_changed(function(event)
    for _, sandboxForceData in pairs(global.sandboxForces) do
        -- Ensure that new automatic recipes aren't hidden
        sandboxForceData.hiddenItemsUnlocked = false
    end
    --[[ TODO:
            There's a bug related to this section if a Player is currently
            inside of a Sandbox while loading a Save where the Configuration
            Changed. The above hiddenItemsUnlocked flag is reset, since for
            some reason the Recipes will have disappeared again, but of
            course there's nothing here to enable them again!
            That's because the enabling code doesn't seem to work anywhere
            outside of right-after the Player has been swapped to their
            Sandbox Force (see the to-do over there).
            Currently, if that same code is used here, the flag will be true,
            but the Recipes are still hidden, so they'll be stuck hidden!
    ]]
    Migrate.Run()
end)

script.on_event(defines.events.on_player_changed_force, function(event)
    local player = game.players[event.player_index]
    Init.Force(player.force)
    Sandbox.OnPlayerForceChanged(player)
end)

script.on_event(defines.events.on_forces_merged, function(event)
    Init.Force(event.destination)
    Init.MergeForce(event.source_name, event.destination)
end)

script.on_event(defines.events.on_research_finished, Research.OnResearched)
script.on_event(defines.events.on_research_reversed, Research.OnResearched)
script.on_event(defines.events.on_research_started, Research.OnResearchStarted)

script.on_event(defines.events.on_player_changed_surface, function(event)
    local player = game.players[event.player_index]
    Sandbox.OnPlayerSurfaceChanged(player)
    ToggleGUI.Update(player)
end)

script.on_event(defines.events.on_surface_created, function(event)
    return Lab.Equip(game.surfaces[event.surface_index])
            or SpaceExploration.Equip(game.surfaces[event.surface_index])
end)

script.on_event(defines.events.on_surface_cleared, function(event)
    return Lab.Equip(game.surfaces[event.surface_index])
            or SpaceExploration.Equip(game.surfaces[event.surface_index])
end)

script.on_event(defines.events.on_marked_for_deconstruction, God.OnMarkedForDeconstruct)
script.on_event(defines.events.on_marked_for_upgrade, God.OnMarkedForUpgrade)
script.on_event(defines.events.on_built_entity, God.OnBuiltEntity)
script.on_event(defines.events.on_player_crafted_item, God.OnPlayerCraftedItem)
script.on_event(defines.events.on_player_main_inventory_changed, God.OnInventoryChanged)

-- TODO: on_entity_settings_pasted

script.on_event(defines.events.on_player_selected_area, function(event)
    Resources.OnAreaSelected(event, true)
end)
script.on_event(defines.events.on_player_alt_selected_area, function(event)
    Resources.OnAreaSelected(event, false)
end)

-- Shortcuts

script.on_event(ToggleGUI.toggleShortcut, ToggleGUI.OnToggleShortcut)
script.on_event(defines.events.on_lua_shortcut, ToggleGUI.OnToggleShortcut)

-- GUI

script.on_event(defines.events.on_gui_click, ToggleGUI.OnGuiClick)
script.on_event(defines.events.on_gui_selection_state_changed, ToggleGUI.OnGuiDropdown)
