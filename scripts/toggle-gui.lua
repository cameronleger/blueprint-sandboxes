local ToggleGUI = {}

ToggleGUI.name = BPSB.pfx .. "toggle-gui"
ToggleGUI.pfx = ToggleGUI.name .. "-"
ToggleGUI.toggleShortcut = ToggleGUI.pfx .. "sb-toggle-shortcut"
ToggleGUI.selectedSandboxDropdown = ToggleGUI.pfx .. "selected-sandbox-dropdown"
ToggleGUI.resetButton = ToggleGUI.pfx .. "reset-button"
ToggleGUI.daytimeSlider = ToggleGUI.pfx .. "daytime-slider"
ToggleGUI.globalElectricNetworkCheckbox = ToggleGUI.pfx .. "global-eletric-network-checkbox"

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
    }.style.horizontally_stretchable = true

    local daylightFlow = innerFrame.add {
        type = "flow",
        name = "daylightFlow",
        direction = "horizontal",
        style = BPSB.pfx .. "centered-horizontal-flow",
    }

    daylightFlow.add {
        type = "sprite",
        tooltip = { "gui-description." .. ToggleGUI.daytimeSlider },
        sprite = "utility/select_icon_white",
        resize_to_sprite = false,
        style = BPSB.pfx .. "sprite-like-tool-button",
    }

    daylightFlow.add {
        type = "slider",
        name = ToggleGUI.daytimeSlider,
        value = 0.0,
        minimum_value = 0.5,
        maximum_value = 0.975,
        value_step = 0.025,
        style = "notched_slider",
    }.style.horizontally_stretchable = true

    local globalElectricNetworkFlow = innerFrame.add {
        type = "flow",
        name = "globalElectricNetworkFlow",
        direction = "horizontal",
        style = BPSB.pfx .. "centered-horizontal-flow",
    }

    globalElectricNetworkFlow.add {
        type = "checkbox",
        name = ToggleGUI.globalElectricNetworkCheckbox,
        caption = { "gui." .. ToggleGUI.globalElectricNetworkCheckbox },
        tooltip = { "gui-description." .. ToggleGUI.globalElectricNetworkCheckbox },
        state = false,
        style = BPSB.pfx .. "left-padded-checkbox",
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
function ToggleGUI.FindByName(player, name)
    return ToggleGUI.FindDescendantByName(player.gui.left[ToggleGUI.name], name)
end

---@param player LuaPlayer
function ToggleGUI.Update(player)
    if not player.gui.left[ToggleGUI.name] then
        return
    end

    ToggleGUI.FindByName(player, ToggleGUI.selectedSandboxDropdown).selected_index = storage.players[player.index].selectedSandbox

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

        ToggleGUI.FindByName(player, ToggleGUI.daytimeSlider).slider_value = player.surface.daytime
        ToggleGUI.FindByName(player, ToggleGUI.globalElectricNetworkCheckbox).state = Sandbox.HasGlobalElectricalNetwork(player.surface)
    else
        player.set_shortcut_toggled(ToggleGUI.toggleShortcut, false)
        player.gui.left[ToggleGUI.name].visible = false
        ToggleGUI.FindByName(player, ToggleGUI.resetButton).enabled = false
    end
end

---@param event EventData.on_gui_value_changed
function ToggleGUI.OnGuiValueChanged(event)
    local player = game.players[event.player_index]
    if event.element.name == ToggleGUI.daytimeSlider then
        local daytime = event.element.slider_value
        return Lab.SetDayTime(player, player.surface, daytime)
                or SpaceExploration.SetDayTime(player, player.surface, daytime)
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
    end
end

---@param event EventData.on_gui_click
function ToggleGUI.OnGuiClick(event)
    local player = game.players[event.player_index]
    if event.element.name == ToggleGUI.toggleShortcut then
        Sandbox.Toggle(event.player_index)
    elseif event.element.name == ToggleGUI.globalElectricNetworkCheckbox then
        local newState = Sandbox.ToggleGlobalElectricalNetwork(game.players[event.player_index].surface)
        ToggleGUI.FindByName(player, ToggleGUI.globalElectricNetworkCheckbox).state = newState
    elseif event.element.name == ToggleGUI.resetButton then
        if event.shift then
            return Lab.ResetEquipmentBlueprint(player.surface)
                    or SpaceExploration.ResetEquipmentBlueprint(player.surface)
        else
            local blueprintString = Inventory.GetCursorBlueprintString(player)
            if blueprintString then
                return Lab.SetEquipmentBlueprint(player.surface, blueprintString)
                        or SpaceExploration.SetEquipmentBlueprint(player.surface, blueprintString)
            else
                return Lab.Reset(player)
                        or SpaceExploration.Reset(player)
            end
        end
    end
end

---@param event EventData.on_lua_shortcut | EventData.CustomInputEvent
function ToggleGUI.OnToggleShortcut(event)
    if (event.input_name or event.prototype_name) == ToggleGUI.toggleShortcut then
        Sandbox.Toggle(event.player_index)
    end
end

return ToggleGUI
