function CheckPyalienBeacon()
    if script.active_mods["pyalienlife"] then
        for _, surface in pairs(game.surfaces) do
            local entities = surface.find_entities_filtered { type = "beacon" }
            for _, v in pairs(entities) do
                if string.find(v.prototype.name, "hidden") then
                    if v.quality.name ~= "normal" then
                        v.destroy()
                    end
                end
            end
        end
    end
end
