local ToggleGUI = {}

ToggleGUI.name = BPSB.pfx .. "toggle-gui"
ToggleGUI.pfx = ToggleGUI.name .. "-"
ToggleGUI.toggleShortcut = ToggleGUI.pfx .. "sb-toggle-shortcut"
ToggleGUI.selectedSandboxDropdown = ToggleGUI.pfx .. "selected-sandbox-dropdown"
ToggleGUI.surfacePropsButton = ToggleGUI.pfx .. "surface-props-button"
ToggleGUI.resetButton = ToggleGUI.pfx .. "reset-button"
ToggleGUI.entitySelectionPlannerGenerator = ToggleGUI.pfx .. "entity-selection-planner-generator"
ToggleGUI.tileSelectionPlannerGenerator = ToggleGUI.pfx .. "tile-selection-planner-generator"
ToggleGUI.entranceButton = ToggleGUI.pfx .. "enter"

---@param player LuaPlayer
function ToggleGUI.Init(player)
    if player.gui.left[ToggleGUI.name] then
        return
    end

    local frame = player.gui.left.add {
        type = "frame",
        name = ToggleGUI.name,
        caption = { "gui." .. ToggleGUI.name },
        visible = false,
        index = 0,
        style = BPSB.pfx .. "toggle-frame",
    }

    local innerFrame = frame.add {
        type = "frame",
        name = "innerFrame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding_and_vertical_spacing",
    }

    local topLineFlow = innerFrame.add {
        type = "flow",
        name = "topLineFlow",
        direction = "horizontal",
        style = BPSB.pfx .. "centered-horizontal-flow",
    }

    topLineFlow.add {
        type = "sprite-button",
        name = ToggleGUI.resetButton,
        tooltip = { "gui-description." .. ToggleGUI.resetButton },
        style = "tool_button",
        sprite = "utility/reset_white",
    }

    topLineFlow.add {
        type = "drop-down",
        name = ToggleGUI.selectedSandboxDropdown,
        tooltip = { "gui-description." .. ToggleGUI.selectedSandboxDropdown },
        items = Sandbox.choices,
        selected_index = storage.players[player.index].selectedSandbox,
        style = BPSB.pfx .. "sandbox-dropdown",
    }.style.horizontally_stretchable = true

    topLineFlow.add {
        type = "sprite-button",
        name = ToggleGUI.surfacePropsButton,
        tooltip = { "gui-description." .. ToggleGUI.surfacePropsButton },
        style = "frame_action_button",
        sprite = "tooltip-category-crafting-surface-conditions",
    }

    local entranceFlow = innerFrame.add {
        type = "flow",
        name = "entranceFlow",
        direction = "horizontal",
        style = BPSB.pfx .. "centered-horizontal-flow",
        visible = false,
    }

    entranceFlow.add {
        type = "button",
        name = ToggleGUI.entranceButton,
        caption = { "gui." .. ToggleGUI.entranceButton },
        tooltip = { "gui-description." .. ToggleGUI.entranceButton },
    }.style.horizontally_stretchable = true

    local selectorFlow = innerFrame.add {
        type = "flow",
        name = "selectorFlow",
        direction = "horizontal",
        style = BPSB.pfx .. "centered-horizontal-flow",
    }

    selectorFlow.add {
        type = "label",
        caption = { "gui." .. ToggleGUI.entitySelectionPlannerGenerator },
        tooltip = { "gui-description." .. ToggleGUI.entitySelectionPlannerGenerator },
        style = "caption_label",
    }

    local entitySelectionType = "entity"
    if player.mod_settings[Settings.qualityEntityPlanners].value then
        entitySelectionType = "entity-with-quality"
    end
    selectorFlow.add {
        type = "choose-elem-button",
        name = ToggleGUI.entitySelectionPlannerGenerator,
        tooltip = { "gui-description." .. ToggleGUI.entitySelectionPlannerGenerator },
        elem_type = entitySelectionType,
        elem_filters = {
            { filter = "type", type = "resource" },
            { mode = "or", filter = "type", type = "asteroid" },
            { mode = "or", filter = "type", type = "tree" },
            { mode = "or", filter = "type", type = "plant" },
            { mode = "or", filter = "type", type = "lightning" },
            { mode = "or", filter = "type", type = "unit" },
            { mode = "or", filter = "type", type = "segmented-unit" },
            { mode = "or", filter = "type", type = "spider-unit" },
            { mode = "or", filter = "type", type = "unit-spawner" },
            { mode = "or", filter = "type", type = "turret" },
            { mode = "or", filter = "type", type = "simple-entity" },
            { mode = "and", filter = "name", name = "wube-logo-space-platform", invert = true }, -- TODO: Wube's problem
        },
    }

    selectorFlow.add {
        type = "label",
        caption = { "gui." .. ToggleGUI.tileSelectionPlannerGenerator },
        tooltip = { "gui-description." .. ToggleGUI.tileSelectionPlannerGenerator },
        style = "caption_label",
    }

    selectorFlow.add {
        type = "choose-elem-button",
        tooltip = { "gui-description." .. ToggleGUI.tileSelectionPlannerGenerator },
        name = ToggleGUI.tileSelectionPlannerGenerator,
        elem_type = "tile",
    }

    ToggleGUI.Update(player)
end

---@param player LuaPlayer
function ToggleGUI.Destroy(player)
    if not player.gui.left[ToggleGUI.name] then
        return
    end
    player.gui.left[ToggleGUI.name].destroy()
end

---@param instance LuaGuiElement
---@param name string
---@return LuaGuiElement | nil
function ToggleGUI.FindDescendantByName(instance, name)
    for _, child in pairs(instance.children) do
        if child.name == name then
            return child
        end
        local found = ToggleGUI.FindDescendantByName(child, name)
        if found then return found end
    end
end

---@param player LuaPlayer
---@param name string
---@return LuaGuiElement | nil
function ToggleGUI.FindByName(player, name)
    return ToggleGUI.FindDescendantByName(player.gui.left[ToggleGUI.name], name)
end

---@param player LuaPlayer
function ToggleGUI.Update(player)
    if not player.gui.left[ToggleGUI.name] then
        return
    end

    ToggleGUI.FindByName(player, ToggleGUI.selectedSandboxDropdown).selected_index = Sandbox.GetSandboxChoiceFor(player, player.surface) or storage.players[player.index].selectedSandbox

    if Sandbox.IsPlayerInsideSandbox(player) then
        local playerData = storage.players[player.index]

        player.set_shortcut_toggled(ToggleGUI.toggleShortcut, true)
        player.gui.left[ToggleGUI.name].visible = true

        local resetButton = ToggleGUI.FindByName(player, ToggleGUI.resetButton)
        if game.is_multiplayer
                and not player.admin
                and playerData.selectedSandbox ~= Sandbox.player
                and settings.global[Settings.onlyAdminsForceReset].value
        then
            resetButton.enabled = false
            resetButton.tooltip = { "gui-description." .. ToggleGUI.resetButton .. "-only-admins" }
        else
            resetButton.enabled = true
            resetButton.tooltip = { "gui-description." .. ToggleGUI.resetButton }
        end

        ToggleGUI.FindByName(player, ToggleGUI.entranceButton).enabled = Sandbox.CanEnter(player)
    else
        player.set_shortcut_toggled(ToggleGUI.toggleShortcut, false)
        player.gui.left[ToggleGUI.name].visible = false
        ToggleGUI.FindByName(player, ToggleGUI.resetButton).enabled = false
        ToggleGUI.FindByName(player, ToggleGUI.entranceButton).enabled = false
    end
end

---@param event EventData.on_gui_selection_state_changed
function ToggleGUI.OnGuiDropdown(event)
    local player = game.players[event.player_index]
    if event.element.name == ToggleGUI.selectedSandboxDropdown then
        local choice = event.element.selected_index
        if Sandbox.IsEnabled(choice) then
            storage.players[player.index].selectedSandbox = event.element.selected_index
            Sandbox.Toggle(event.player_index)
        else
            player.print("That Sandbox is not possible.")
            event.element.selected_index = storage.players[player.index].selectedSandbox
            ToggleGUI.Update(player)
        end
        return true
    end
    return false
end

---@param event EventData.on_gui_click
function ToggleGUI.OnGuiClick(event)
    local player = game.players[event.player_index]
    if event.element.name == ToggleGUI.toggleShortcut then
        Sandbox.Toggle(event.player_index)
        return true
    elseif event.element.name == ToggleGUI.entranceButton then
        Sandbox.SwapToGod(player)
        return true
    elseif event.element.name == ToggleGUI.surfacePropsButton then
        SurfacePropsGUI.Init(player)
        return true
    elseif event.element.name == ToggleGUI.resetButton then
        if event.shift then
            return Lab.ResetEquipmentBlueprint(player.surface)
        else
            local blueprintString = Inventory.GetCursorBlueprintString(player)
            if blueprintString then
                return Lab.SetEquipmentBlueprint(player.surface, blueprintString)
            else
                return Lab.Reset(player)
            end
        end
        return true
    end
    return false
end

---@param event EventData.on_lua_shortcut | EventData.CustomInputEvent
function ToggleGUI.OnToggleShortcut(event)
    if (event.input_name or event.prototype_name) == ToggleGUI.toggleShortcut then
        Sandbox.Toggle(event.player_index)
    end
end

return ToggleGUI
