skipped_entities = {}
local skipped_setting = settings.startup["skipped_entities"].value

for ent in string.gmatch(skipped_setting,'([^,]+)') do
	table.insert(skipped_entities, ent)
end

if script.active_mods["factorissimo-2-notnotmelon"] then
    table.insert(skipped_entities,"factory-1")
    table.insert(skipped_entities,"factory-2")
    table.insert(skipped_entities,"factory-3")
end
if script.active_mods["pyalienlife"] then
    table.insert(skipped_entities,"dino-dig-site")
end