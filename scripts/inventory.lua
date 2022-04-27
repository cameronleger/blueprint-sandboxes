-- Inventory-related methods
local Inventory = {}

-- TODO: Consider the Cursor Inventory too (otherwise items can be lost during transition)
-- TODO: Consider Filters (otherwise they are lost during transition)

-- Whether a Player's Inventory is vulnerable to going missing due to lack of a body
function Inventory.ShouldPersist(controller)
    return controller ~= defines.controllers.character
end

-- Ensure a Player's Inventory isn't full
function Inventory.Prune(player)
    local inventory = player.get_main_inventory()
    if not inventory then
        return
    end

    if inventory.count_empty_stacks() == 0 then
        player.print("Your inventory is almost full. Please throw some items away.")
        player.surface.spill_item_stack(player.position, inventory[#inventory])
        inventory[#inventory].clear()
    end
end

-- Persist one Inventory into another mod-created one
function Inventory.Persist(from, to)
    if not from then
        return nil
    end
    if not to then
        to = game.create_inventory(#from)
    else
        to.resize(#from)
    end
    for i = 1, #from do
        to[i].set_stack(from[i])
    end
    return to
end

-- Restore one Inventory into another
function Inventory.Restore(from, to)
    if not from or not to then
        return
    end
    local transition = math.min(#from, #to)
    for i = 1, transition do
        to[i].set_stack(from[i])
    end
    if transition < #to then
        for i = transition + 1, #to do
            to[i].set_stack()
        end
    end
end

return Inventory
