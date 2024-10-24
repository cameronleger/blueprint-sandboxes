-- Managing the Research of each Force's Sandboxes
local Research = {}

-- Set a Force's Sandboxes Research equal to that of the Force's (or all research)
---@param originalForce LuaForce
---@param sandboxForce LuaForce
function Research.Sync(originalForce, sandboxForce)
    if settings.global[Settings.allowAllTech].value then
        sandboxForce.research_all_technologies()
        log("Researching everything for: " .. sandboxForce.name)
    else
        for tech, _ in pairs(prototypes.technology) do
            sandboxForce.technologies[tech].researched = originalForce.technologies[tech].researched
            sandboxForce.technologies[tech].level = originalForce.technologies[tech].level
            -- TODO: Consider file:///home/cameron/src/factorio/factorio_expansion/doc-html/classes/LuaTechnology.html#saved_progress
        end
        log("Copied all Research from: " .. originalForce.name .. " -> " .. sandboxForce.name)
    end
end

-- Set a Force's Sandboxes Research Queue equal to that of the Force's
---@param originalForce LuaForce
---@param sandboxForce LuaForce
function Research.SyncQueue(originalForce, sandboxForce)
    if settings.global[Settings.allowAllTech].value then
        sandboxForce.research_queue = nil
        log("Emptying Research Queue for: " .. sandboxForce.name)
    else
        local newQueue = {}
        for _, tech in pairs(originalForce.research_queue) do
            table.insert(newQueue, tech.name)
        end
        sandboxForce.research_queue = newQueue
        log("Copied Research Queue from: " .. originalForce.name .. " -> " .. sandboxForce.name)
    end
end

-- Enable the Infinity Input/Output Recipes
---@param force LuaForce
function Research.EnableSandboxSpecificResearch(force)
    if storage.sandboxForces[force.name].hiddenItemsUnlocked == true then
        return
    end
    log("Unlocking hidden Recipes for: " .. force.name)

    if force.recipes[BPSB.pfx .. "loader"] then
        force.recipes[BPSB.pfx .. "loader"].enabled = true
        force.recipes[BPSB.pfx .. "fast-loader"].enabled = true
        force.recipes[BPSB.pfx .. "express-loader"].enabled = true
    end

    force.recipes[BPSB.pfx .. "electric-energy-interface"].enabled = true
    force.recipes[BPSB.pfx .. "infinity-chest"].enabled = true
    force.recipes[BPSB.pfx .. "infinity-pipe"].enabled = true

    for name, recipe in pairs(force.recipes) do
        if Resources.IsResourcePlanner(name) or Tiles.IsTilePlanner(name) then
            recipe.enabled = true
        end
    end

    EditorExtensionsCheats.EnableTestingRecipes(force)

    storage.sandboxForces[force.name].hiddenItemsUnlocked = true
end

-- For all Forces with Sandboxes, Sync their Research
function Research.SyncAllForces()
    for _, force in pairs(game.forces) do
        if not Sandbox.IsSandboxForce(force) then
            local sandboxForce = game.forces[Sandbox.NameFromForce(force)]
            if sandboxForce then
                Research.Sync(force, sandboxForce)
                Research.SyncQueue(force, sandboxForce)
            end
        end
    end
end

-- As a Force's Research Queue changes, keep the Force's Sandboxes in-sync
---@param event EventData.on_research_moved
function Research.OnResearchReordered(event)
    if not settings.global[Settings.allowAllTech].value then
        if not Sandbox.IsSandboxForce(event.force) then
            local sandboxForce = game.forces[Sandbox.NameFromForce(event.force)]
            if sandboxForce then
                log("Research queue reordered: " .. event.force.name .. " -> " .. sandboxForce.name)
                Research.SyncQueue(event.force, sandboxForce)
            end
        end
    end
end

-- As a Force's Research changes, keep the Force's Sandboxes in-sync
---@param event EventData.on_research_finished | EventData.on_research_reversed
function Research.OnResearched(event)
    if not settings.global[Settings.allowAllTech].value then
        local force = event.research.force
        if not Sandbox.IsSandboxForce(force) then
            local sandboxForce = game.forces[Sandbox.NameFromForce(force)]
            if sandboxForce then
                log("New Research: " .. event.research.name .. " from " .. force.name .. " -> " .. sandboxForce.name)
                sandboxForce.technologies[event.research.name].researched = force.technologies[event.research.name].researched
                sandboxForce.technologies[event.research.name].level = force.technologies[event.research.name].level
                sandboxForce.play_sound { path = "utility/research_completed" }
                Research.SyncQueue(force, sandboxForce)
            end
        end
    end
end

-- As a Force's Research Queue changes, show it in the Force's Sandboxes
---@param event EventData.on_research_started
function Research.OnResearchStarted(event)
    if not settings.global[Settings.allowAllTech].value then
        local force = event.research.force
        if not Sandbox.IsSandboxForce(force) then
            local sandboxForce = game.forces[Sandbox.NameFromForce(force)]
            if sandboxForce then
                log("New Research Queued: " .. event.research.name .. " from " .. force.name .. " -> " .. sandboxForce.name)
                Research.SyncQueue(force, sandboxForce)
            end
        end
    end
end

return Research
