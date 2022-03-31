local Debug = {}

Debug.enabled = false
Debug.pfx = BPSB.pfx .. "debug | "

function Debug.log(message)
    log(Debug.pfx .. message)
    if Debug.enabled then
        game.print(Debug.pfx .. message)
    end
end

return Debug
