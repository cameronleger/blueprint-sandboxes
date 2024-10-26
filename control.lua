-- Required by basically everything immediately
BPSB = require("scripts.bpsb")
Events = require("scripts.events")
Settings = require("scripts.settings")
Debug = require("scripts.debug")
Queue = require("scripts.queue")

-- Required by some
Illusion = require("scripts.illusion")
EditorExtensionsCheats = require("scripts.editor-extensions-cheats")
Permissions = require("scripts.permissions")
RemoteView = require("scripts.remote-view")

-- Required, but not ordered importantly
Init = require("scripts.init")
Chat = require("scripts.chat")
Equipment = require("scripts.equipment")
Factorissimo = require("scripts.factorissimo")
Force = require("scripts.force")
God = require("scripts.god")
Inventory = require("scripts.inventory")
Lab = require("scripts.lab")
Migrate = require("scripts.migrate")
Research = require("scripts.research")
Resources = require("scripts.resources")
Tiles = require("scripts.tiles")

-- Required by Sandbox
SpaceExploration = require("scripts.space-exploration")

-- Requires SpaceExploration method immediately
Sandbox = require("scripts.sandbox")

-- GUIs, they likely depend on the above
SurfacePropsGUI = require("scripts.surface-props-gui")
ToggleGUI = require("scripts.toggle-gui")

require('scripts.remote-interface')

-- Initializations

script.on_init(function()
    Init.FirstTimeInit()
    Settings.SetupConditionalHandlers()
    SurfacePropsGUI.InitPresets()
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    log("on_player_created index: " .. event.player_index)
    Force.Init(player.force)
    Init.Player(player)
end)

script.on_event(defines.events.on_player_removed, function(event)
    local playerData = storage.players[event.player_index]
    log("on_player_removed index: " .. event.player_index)
    Lab.DeleteLab(playerData.labName)
    if playerData.sandboxInventory then
        playerData.sandboxInventory.destroy()
    end
    if playerData.preSandboxInventory then
        playerData.preSandboxInventory.destroy()
    end
    storage.players[event.player_index] = nil
end)

script.on_event(defines.events.on_force_created, function(event)
    log("on_force_created name: " .. event.force.name)
    Force.Init(event.force)
    if Sandbox.IsSandboxForce(event.force) then
        RemoteView.HideEverythingInSandboxes(event.force)
    else
        RemoteView.HideAllSandboxes(event.force)
    end
end)

-- Conditional Event Listeners

script.on_load(function()
    Settings.SetupConditionalHandlers()
    SurfacePropsGUI.InitPresets()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, Settings.OnRuntimeSettingChanged)

-- Important Game Events

script.on_configuration_changed(function(event)
    for _, sandboxForceData in pairs(storage.sandboxForces) do
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
    Migrate.RecreateGuis()
    Research.SyncAllForces()
end)

script.on_event(defines.events.on_player_changed_force, function(event)
    local player = game.players[event.player_index]
    Force.Init(player.force)
    Sandbox.OnPlayerForceChanged(player)
end)

script.on_event(defines.events.on_forces_merged, function(event)
    Force.Init(event.destination)
    Force.Merge(event.source_name, event.destination)
end)

script.on_event(defines.events.on_player_promoted, function(event)
    local player = game.players[event.player_index]
    ToggleGUI.Update(player)
end)

script.on_event(defines.events.on_player_demoted, function(event)
    local player = game.players[event.player_index]
    ToggleGUI.Update(player)
end)

script.on_event(defines.events.on_console_chat, Chat.OnChat)

script.on_event(defines.events.on_research_finished, Research.OnResearched)
script.on_event(defines.events.on_research_reversed, Research.OnResearched)
script.on_event(defines.events.on_research_moved, Research.OnResearchReordered)
script.on_event(defines.events.on_research_started, Research.OnResearchStarted)

script.on_event(defines.events.on_player_changed_surface, function(event)
    local player = game.players[event.player_index]
    Sandbox.OnPlayerSurfaceChanged(player)
    ToggleGUI.Update(player)
end)

script.on_event(defines.events.on_surface_created, function(event)
    local surface = game.surfaces[event.surface_index]
    RemoteView.HideFromAllSandboxes(surface)

    if not Sandbox.IsSandbox(surface) then
        return
    end
    RemoteView.HideSandboxFromEveryone(surface)
    local _ = Lab.AfterCreate(surface) or SpaceExploration.AfterCreate(surface)
    local _ = Lab.Equip(surface) or SpaceExploration.Equip(surface)
end)

script.on_event(defines.events.on_surface_cleared, function(event)
    local _ = Lab.Equip(game.surfaces[event.surface_index])
            or SpaceExploration.Equip(game.surfaces[event.surface_index])
end)

script.on_event(defines.events.on_chunk_generated, function(event)
    local equipmentData = storage.equipmentInProgress[event.surface.name]
    if equipmentData then
        Equipment.BuildBlueprint(
                equipmentData.stack,
                equipmentData.surface,
                equipmentData.forceName
        )
    end
end)

script.on_event(defines.events.on_pre_surface_deleted, function(event)
    local surface = game.surfaces[event.surface_index]
    if storage.labSurfaces[surface.name] then
        storage.labSurfaces[surface.name] = nil
    end
    local surfaceData = storage.seSurfaces[surface.name]
    if surfaceData then
        local sandboxForceData = storage.sandboxForces[surfaceData.sandboxForceName]
        SpaceExploration.PreDeleteSandbox(sandboxForceData, surface.name)
    end
end)

script.on_event(defines.events.on_surface_renamed, function(event)
    -- TODO: Renaming surfaces likely doesn't really work
    if storage.labSurfaces[event.old_name] then
        storage.labSurfaces[event.new_name] = storage.labSurfaces[event.old_name]
        storage.labSurfaces[event.old_name] = nil
    end
    local surfaceData = storage.seSurfaces[event.old_name]
    if surfaceData then
        local sandboxForceData = storage.sandboxForces[surfaceData.sandboxForceName]
        if sandboxForceData.sePlanetaryLabZoneName == event.old_name then
            sandboxForceData.sePlanetaryLabZoneName = event.new_name
        end
        if sandboxForceData.seOrbitalSandboxZoneName == event.old_name then
            sandboxForceData.seOrbitalSandboxZoneName = event.new_name
        end
        storage.seSurfaces[event.new_name] = storage.seSurfaces[event.old_name]
        storage.seSurfaces[event.old_name] = nil
    end
end)

script.on_event(defines.events.on_marked_for_deconstruction, God.OnMarkedForDeconstruct)
script.on_event(defines.events.on_marked_for_upgrade, God.OnMarkedForUpgrade)
script.on_event(defines.events.on_built_entity, God.OnBuiltEntity, God.onBuiltEntityFilters)
script.on_event(defines.events.script_raised_built, God.OnBuiltEntity, God.onBuiltEntityFilters)
script.on_event(defines.events.on_player_crafted_item, God.OnPlayerCraftedItem)
script.on_event(defines.events.on_player_main_inventory_changed, God.OnInventoryChanged)

-- TODO: Changed file:///home/cameron/src/factorio/factorio_expansion/doc-html/events.html#on_player_setup_blueprint
script.on_event(defines.events.on_player_setup_blueprint, Illusion.OnBlueprintSetup)

-- TODO: on_entity_settings_pasted

-- TODO: Changed file:///home/cameron/src/factorio/factorio_expansion/doc-html/events.html#on_player_selected_area
script.on_event(defines.events.on_player_selected_area, function(event)
    local _ = Resources.OnAreaSelected(event, true) or Tiles.OnAreaSelected(event)
end)

-- TODO: Changed file:///home/cameron/src/factorio/factorio_expansion/doc-html/events.html#on_player_alt_selected_area
script.on_event(defines.events.on_player_alt_selected_area, function(event)
    local _ = Resources.OnAreaSelected(event, false) or Tiles.OnAreaSelected(event)
end)

-- Internal

script.on_event(Events.on_daylight_changed_event, function(event)
    log("on_daylight_changed_event from player: " .. event.player_index)
    for _, player in pairs(game.players) do
        if player.index ~= event.player_index
                and player.surface.name == event.surface_name
        then
            ToggleGUI.Update(player)
        end
    end
end)

-- Shortcuts

script.on_event(ToggleGUI.toggleShortcut, ToggleGUI.OnToggleShortcut)
script.on_event(defines.events.on_lua_shortcut, ToggleGUI.OnToggleShortcut)

---@param event EventData.CustomInputEvent
script.on_event(SurfacePropsGUI.cancel, function(event)
    local player = game.players[event.player_index]
    if SurfacePropsGUI.IsOpen(player) then
        SurfacePropsGUI.Destroy(player)
    end
end)

---@param event EventData.CustomInputEvent
script.on_event(SurfacePropsGUI.confirm, function(event)
    local player = game.players[event.player_index]
    if SurfacePropsGUI.IsOpen(player) then
        SurfacePropsGUI.Apply(player)
        player.play_sound({ path = "utility/confirm" })
        SurfacePropsGUI.Destroy(player)
    end
end)

-- GUI
---@param event EventData.on_gui_click
script.on_event(defines.events.on_gui_click, function (event)
    local _ = ToggleGUI.OnGuiClick(event) or SurfacePropsGUI.OnGuiClick(event)
end)
script.on_event(defines.events.on_gui_value_changed, ToggleGUI.OnGuiValueChanged)
---@param event EventData.on_gui_selection_state_changed
script.on_event(defines.events.on_gui_selection_state_changed, function (event)
    local _ = ToggleGUI.OnGuiDropdown(event) or SurfacePropsGUI.OnGuiDropdown(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if (event.gui_type == defines.gui_type.blueprint_library) then
        -- We know this won't work, but we'll do it to print a message anyway
        Illusion.OnBlueprintGUIClosed(event)
    elseif (event.gui_type == defines.gui_type.item) then
        Illusion.OnBlueprintGUIClosed(event)
    end
end)
