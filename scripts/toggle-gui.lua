local ToggleGUI = {}

ToggleGUI.name = BPSB.pfx .. "toggle-gui"
ToggleGUI.pfx = ToggleGUI.name .. "-"
ToggleGUI.toggleShortcut = ToggleGUI.pfx .. "sb-toggle-shortcut"
ToggleGUI.selectedSandboxDropdown = ToggleGUI.pfx .. "selected-sandbox-dropdown"
ToggleGUI.resetButton = ToggleGUI.pfx .. "reset-button"

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
        style = "inside_shallow_frame_with_padding",
    }

    local topLineFlow = innerFrame.add {
        type = "flow",
        name = "topLineFlow",
        direction = "horizontal",
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
        selected_index = global.players[player.index].selectedSandbox,
    }

    ToggleGUI.Update(player)
end

function ToggleGUI.findDescendantByName(instance, name)
    for _, child in pairs(instance.children) do
        if child.name == name then
            return child
        end
        local found = ToggleGUI.findDescendantByName(child, name)
        if found then return found end
    end
end

function ToggleGUI.findByName(player, name)
    return ToggleGUI.findDescendantByName(player.gui.left[ToggleGUI.name], name)
end

function ToggleGUI.Update(player)
    ToggleGUI.findByName(player, ToggleGUI.selectedSandboxDropdown).selected_index = global.players[player.index].selectedSandbox

    if Sandbox.IsSandbox(player.surface) then
        player.set_shortcut_toggled(ToggleGUI.toggleShortcut, true)
        player.gui.left[ToggleGUI.name].visible = true
        ToggleGUI.findByName(player, ToggleGUI.resetButton).enabled = true
    else
        player.set_shortcut_toggled(ToggleGUI.toggleShortcut, false)
        player.gui.left[ToggleGUI.name].visible = false
        ToggleGUI.findByName(player, ToggleGUI.resetButton).enabled = false
    end
end

function ToggleGUI.OnGuiDropdown(event)
    local player = game.players[event.player_index]
    if event.element.name == ToggleGUI.selectedSandboxDropdown then
        local choice = event.element.selected_index
        if Sandbox.IsEnabled(choice) then
            global.players[player.index].selectedSandbox = event.element.selected_index
            Sandbox.Toggle(event.player_index)
        else
            player.print("That Sandbox is not possible.")
            event.element.selected_index = global.players[player.index].selectedSandbox
            ToggleGUI.Update(player)
        end
    end
end

function ToggleGUI.OnGuiClick(event)
    local player = game.players[event.player_index]
    if event.element.name == ToggleGUI.toggleShortcut then
        Sandbox.Toggle(event.player_index)
    elseif event.element.name == ToggleGUI.resetButton then
        return Lab.Reset(player)
                or SpaceExploration.Reset(player)
    end
end

function ToggleGUI.OnToggleShortcut(event)
    if (event.input_name or event.prototype_name) == ToggleGUI.toggleShortcut then
        Sandbox.Toggle(event.player_index)
    end
end

return ToggleGUI
