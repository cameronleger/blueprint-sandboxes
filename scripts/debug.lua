local Debug = {}

Debug.enabled = false
Debug.pfx = BPSB.pfx .. "debug | "

function Debug.log(message)
    log(Debug.pfx .. message)
    if Debug.enabled then
        game.print(Debug.pfx .. message)
    end
end

function Debug.ItemStack(value)
    data = {}
    if (value == nil) then
        data["nil"] = true
        return data
    end

    data["nil"] = false
    data["valid"] = value.valid
    data["valid_for_read"] = value.valid_for_read
    if not value.valid_for_read then
        return data
    end

    data["is_blueprint"] = value.is_blueprint
    if value.is_blueprint then
        data["is_blueprint_setup"] = value.is_blueprint_setup()
    end

    local entities = value.get_blueprint_entities()
    if entities then
        data["entities"] = #entities
    else
        data["entities"] = "nil"
    end

    return data
end

return Debug
