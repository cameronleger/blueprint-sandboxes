-- Managing the Research of each Force's Sandboxes
local Research = {}

-- Set a Force's Sandboxes Research equal to that of the Force's (or all research)
function Research.Sync(originalForce, sandboxForce)
    if settings.global[Settings.allowAllTech].value then
        sandboxForce.research_all_technologies()
        Debug.log("Researching everything for: " .. sandboxForce.name)
    else
        for tech, _ in pairs(game.technology_prototypes) do
            sandboxForce.technologies[tech].researched = originalForce.technologies[tech].researched
        end
        Debug.log("Copied all Research from: " .. originalForce.name .. " -> " .. sandboxForce.name)
    end
end

-- Enable the Infinity Input/Output Recipes
function Research.EnableSandboxSpecificResearch(force)
    if global.sandboxForces[force.name].hiddenItemsUnlocked == true then
        return
    end
    Debug.log("Unlocking hidden Recipes for: " .. force.name)
    force.recipes[BPSB.pfx .. "electric-energy-interface"].enabled = true
    force.recipes[BPSB.pfx .. "infinity-chest"].enabled = true
    force.recipes[BPSB.pfx .. "infinity-pipe"].enabled = true
    force.recipes[BPSB.pfx .. "loader"].enabled = true
    force.recipes[BPSB.pfx .. "fast-loader"].enabled = true
    force.recipes[BPSB.pfx .. "express-loader"].enabled = true
    for name, recipe in pairs(force.recipes) do
        if Resources.IsResourcePlanner(name) then
            recipe.enabled = true
        end
    end
    global.sandboxForces[force.name].hiddenItemsUnlocked = true
end

-- For all Forces with Sandboxes, Sync their Research
function Research.SyncAllForces()
    for _, force in pairs(game.forces) do
        if not Sandbox.IsSandboxForce(force) then
            local sandboxForce = game.forces[Sandbox.NameFromForce(force)]
            if sandboxForce then
                Research.Sync(force, sandboxForce)
            end
        end
    end
end

-- As a Force's Research changes, keep the Force's Sandboxes in-sync
function Research.OnResearched(event)
    if not settings.global[Settings.allowAllTech].value then
        local force = event.research.force
        if not Sandbox.IsSandboxForce(force) then
            local sandboxForce = game.forces[Sandbox.NameFromForce(force)]
            if sandboxForce then
                Debug.log("New Research: " .. event.research.name .. " from " .. force.name .. " -> " .. sandboxForce.name)
                sandboxForce.technologies[event.research.name].researched = force.technologies[event.research.name].researched
            end
        end
    end
end

return Research