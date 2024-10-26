local SurfacePropsGUI = {}

SurfacePropsGUI.name = BPSB.pfx .. "surface-props-gui"
SurfacePropsGUI.pfx = SurfacePropsGUI.name .. "-"

SurfacePropsGUI.presetDefault = SurfacePropsGUI.pfx .. "preset-default"
SurfacePropsGUI.presetDropDown = SurfacePropsGUI.pfx .. "preset-drop-down"
SurfacePropsGUI.presetReset = SurfacePropsGUI.pfx .. "preset-reset"

SurfacePropsGUI.propertyTable = SurfacePropsGUI.pfx .. "property-table"
SurfacePropsGUI.propertyTag = SurfacePropsGUI.pfx .. "property"

SurfacePropsGUI.cancel = SurfacePropsGUI.pfx .. "cancel"
SurfacePropsGUI.confirm = SurfacePropsGUI.pfx .. "confirm"

SurfacePropsGUI.presets = {}

function SurfacePropsGUI.InitPresets()
    local defaults = {
        name = { "gui." .. SurfacePropsGUI.presetDefault },
        propValues = {},
    }
    for propId, prop in pairs(prototypes.surface_property) do
        defaults.propValues[propId] = prop.default_value
    end
    table.insert(SurfacePropsGUI.presets, defaults)

    for _, location in pairs(prototypes.space_location) do
        if not location.hidden and location.surface_properties then
            local preset = {
                name = {
                    "",
                    "[img=space-location/" .. location.name .. "]",
                    " ",
                    location.localised_name,
                },
                propValues = {},
            }
            for propId, prop in pairs(prototypes.surface_property) do
                preset.propValues[propId] = location.surface_properties[propId] or prop.default_value
            end
            table.insert(SurfacePropsGUI.presets, preset)
        end
    end

    for _, surface in pairs(prototypes.surface) do
        if not surface.hidden and surface.surface_properties then
            local preset = {
                name = {
                    "",
                    "[img=surface/" .. surface.name .. "]",
                    " ",
                    surface.localised_name,
                },
                propValues = {},
            }
            for propId, prop in pairs(prototypes.surface_property) do
                preset.propValues[propId] = surface.surface_properties[propId] or prop.default_value
            end
            table.insert(SurfacePropsGUI.presets, preset)
        end
    end
end

---@param player LuaPlayer
function SurfacePropsGUI.IsOpen(player)
    if player.gui.screen[SurfacePropsGUI.name] then
        return true
    end
    return false
end

---@param player LuaPlayer
function SurfacePropsGUI.Init(player)
    if SurfacePropsGUI.IsOpen(player) then
        return
    end

    local frame = player.gui.screen.add {
        type = "frame",
        name = SurfacePropsGUI.name,
        caption = { "gui." .. SurfacePropsGUI.name },
        visible = true,
        direction = "vertical",
    }

    local innerFrame = frame.add {
        type = "frame",
        name = "innerFrame",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    local planetPresetFlow = innerFrame.add {
        type = "frame",
        direction = "horizontal",
        style = "subheader_frame",
    }
    planetPresetFlow.style.horizontally_stretchable = true
    planetPresetFlow.add { type = "empty-widget" }.style.horizontally_stretchable = true

    planetPresetFlow.add {
        type = "label",
        caption = { "gui." .. SurfacePropsGUI.presetDropDown },
        style = "caption_label",
    }

    local planetPresetItems = {}
    for _, preset in pairs(SurfacePropsGUI.presets) do
        table.insert(planetPresetItems, preset.name)
    end
    planetPresetFlow.add {
        type = "drop-down",
        name = SurfacePropsGUI.presetDropDown,
        items = planetPresetItems,
        tooltip = { "gui-description." .. SurfacePropsGUI.presetDropDown },
    }

    planetPresetFlow.add {
        type = "sprite-button",
        name = SurfacePropsGUI.presetReset,
        tooltip = { "gui-description." .. SurfacePropsGUI.presetReset },
        style = "tool_button_red",
        sprite = "utility/reset",
    }

    innerFrame.add {
        type = "label",
        caption = { "gui-description." .. SurfacePropsGUI.name },
        style = BPSB.pfx .. "surface-property-description",
    }

    local propertiesTable = innerFrame.add {
        type = "table",
        name = SurfacePropsGUI.propertyTable,
        column_count = 3,
        style = BPSB.pfx .. "surface-property-table",
    }

    for propId, prop in pairs(prototypes.surface_property) do
        if not prop.hidden then
            propertiesTable.add {
                type = "label",
                caption = { "", prop.localised_name, ":" },
                style = "semibold_caption_label"
            }

            propertiesTable.add {
                type = "textfield",
                text = tostring(player.surface.get_property(propId)),
                numeric = true,
                allow_decimal = true,
                style = "short_number_textfield",
                tags = { [SurfacePropsGUI.propertyTag] = propId }
            }

            propertiesTable.add {
                type = "label",
                caption = { "surface-property-unit." .. propId, "" },
            }
        end
    end

    local actionsFlow = frame.add {
        type = "flow",
        style = "dialog_buttons_horizontal_flow",
    }

    actionsFlow.add {
        type = "button",
        name = SurfacePropsGUI.cancel,
        style = "back_button",
        caption = { "gui.cancel" },
        tags = { action = SurfacePropsGUI.cancel },
    }

    actionsFlow.add {
        type = "empty-widget",
        style = BPSB.pfx .. "drag-handle",
    }.drag_target = frame

    actionsFlow.add {
        type = "button",
        name = SurfacePropsGUI.confirm,
        style = "confirm_button",
        caption = { "gui.confirm" },
        tags = { action = SurfacePropsGUI.confirm },
    }

    player.opened = frame
end

---@param player LuaPlayer
function SurfacePropsGUI.Destroy(player)
    if not SurfacePropsGUI.IsOpen(player) then
        return
    end
    player.gui.screen[SurfacePropsGUI.name].destroy()
end

function SurfacePropsGUI.FindDescendantByName(instance, name)
    for _, child in pairs(instance.children) do
        if child.name == name then
            return child
        end
        local found = SurfacePropsGUI.FindDescendantByName(child, name)
        if found then return found end
    end
end

---@param player LuaPlayer
---@return LuaGuiElement | nil
function SurfacePropsGUI.FindByName(player, name)
    if not SurfacePropsGUI.IsOpen(player) then
        return
    end
    return SurfacePropsGUI.FindDescendantByName(player.gui.screen[SurfacePropsGUI.name], name)
end

---@param player LuaPlayer
function SurfacePropsGUI.LoadPreset(player)
    if not SurfacePropsGUI.IsOpen(player) then
        log("Cannot import Surface Properties without an open GUI")
        return
    end

    local propertiesTable = SurfacePropsGUI.FindByName(player, SurfacePropsGUI.propertyTable)
    if not propertiesTable then
        log("Cannot import Surface Properties without an open GUI")
        return
    end

    local planetIndex = SurfacePropsGUI.FindByName(player, SurfacePropsGUI.presetDropDown).selected_index
    if not planetIndex then
        log("Cannot import Surface Properties without a selected preset")
        return
    end

    local preset = SurfacePropsGUI.presets[planetIndex]
    if not preset then
        log("Cannot import Surface Properties without a matching preset")
        return
    end

    for _, child in pairs(propertiesTable.children) do
        local propId = child.tags[SurfacePropsGUI.propertyTag] --[[@as string]]
        if propId then
            local presetPropValue = preset.propValues[propId]
            child.text = tostring(presetPropValue)
        end
    end
end

---@param player LuaPlayer
function SurfacePropsGUI.Apply(player)
    if not SurfacePropsGUI.IsOpen(player) then
        log("Cannot apply Surface Properties without an open GUI")
        return
    end

    local propertiesTable = SurfacePropsGUI.FindByName(player, SurfacePropsGUI.propertyTable)
    if not propertiesTable then
        log("Cannot apply Surface Properties without an open GUI")
        return
    end

    local sandboxSurface = player.surface
    if not (Lab.IsLab(sandboxSurface) or SpaceExploration.IsSandbox(sandboxSurface)) then
        log("Cannot apply Surface Properties outside of a Sandbox")
        return
    end

    for _, child in pairs(propertiesTable.children) do
        local propId = child.tags[SurfacePropsGUI.propertyTag] --[[@as string]]
        if propId then
            local propValue = tonumber(child.text)
            if propValue ~= nil then
                sandboxSurface.set_property(propId, propValue)
            else
                player.print("Not applying your edits because an invalid value was found for " .. propId)
            end
        end
    end
end

---@param event EventData.on_gui_selection_state_changed
function SurfacePropsGUI.OnGuiDropdown(event)
    local player = game.players[event.player_index]
    if event.element.name == SurfacePropsGUI.presetDropDown then
        SurfacePropsGUI.LoadPreset(player)
        local reset = SurfacePropsGUI.FindByName(player, SurfacePropsGUI.presetReset)
        if reset and reset.enabled == false then
            reset.enabled = true
        end
    end
end

---@param event EventData.on_gui_click
function SurfacePropsGUI.OnGuiClick(event)
    local player = game.players[event.player_index]
    if event.element.name == SurfacePropsGUI.cancel then
        SurfacePropsGUI.Destroy(player)
    elseif event.element.name == SurfacePropsGUI.confirm then
        SurfacePropsGUI.Apply(player)
        SurfacePropsGUI.Destroy(player)
    elseif event.element.name == SurfacePropsGUI.presetReset then
        SurfacePropsGUI.LoadPreset(player)
    end
end

return SurfacePropsGUI
