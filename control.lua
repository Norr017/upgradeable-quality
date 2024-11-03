require("util")
require("mod-gui")
local filter = { { filter = "type", type = "ammo-turret" },
	{ filter = "type", type = "assembling-machine" },
	{ filter = "type", type = "furnace" },
	{ filter = "type", type = "lab" },
	{ filter = "type", type = "mining-drill" },
	{ filter = "type", type = "boiler" },
	{ filter = "type", type = "generator" },
	{ filter = "type", type = "solar-panel" },
	{ filter = "type", type = "accumulator" },
	{ filter = "type", type = "reactor" },
	{ filter = "type", type = "beacon" }
}
if script.active_mods["space-age"] then
	table.insert(filter, { filter = "type", type = "asteroid-collector" })
end

local s_filter = get_lite_filter(filter)
function get_lite_filter(input)
	local temp_filter = {}
	for _,v in pairs(input) do
		table.insert(temp_filter,v.type)
	end
	return temp_filter
end

local base_time = settings.startup["base_time_to_level_up"].value
local multiplier = settings.startup["multiplier_time_to_level_up"].value
local is_update_module = settings.startup["randomly_upgrade_inside_module"].value
local base_time_module = settings.startup["time_to_randomly_levelup_inside_module"].value
local respect_technology = settings.startup["respect_technology"].value
local quality_tech = {}
script.on_init(function()
	get_built_machine()
end)

script.on_configuration_changed(function()

end)
script.on_load(function()
	quality_tech = check_quality_unlock_tech()
end)
script.on_nth_tick(60, function(event)
	local upgrade_machine_list = {}
	local upgrade_module_list = {}
	for _, ent in pairs(storage.built_machine) do
		while true do
			if not ent.entity.valid then
				storage.built_machine[ent.unit_number] = nil
				break
			end
			local next_tech = ent.entity.quality.next
			if not next_tech then break end
			if not check_quality_unlock(next_tech) and respect_technology then break end
			if ent.level_time < base_time * multiplier ^ next_tech.level then
				if ent.entity.status == defines.entity_status.working then
					ent.level_time = ent.level_time + 1
				end
			else
				table.insert(upgrade_machine_list, ent)
				ent.level_time = 0
			end
			if ent.level_time > base_time_module and is_update_module then
				table.insert(upgrade_module_list, ent)
			end
			break
		end
	end
	for _, v in pairs(upgrade_machine_list) do
		upgrade_machines(v)
	end
	for _, v in pairs(upgrade_module_list) do
		upgrade_module(v)
	end
end)
function check_quality_unlock_tech()
	local q_t = {}
	for k, v in pairs(prototypes.technology) do
		for k1, v1 in pairs(v.effects) do
			if v1["type"] == "unlock-quality" then
				q_t[v1["quality"]] = k
			end
		end
	end
	return q_t
end

function check_quality_unlock(tech)
	local name = tech.name
	local tech_name = quality_tech[name]
	return game.forces["player"].technologies[tech_name].researched
end

function upgrade_machines(ent)
	if not ent.entity.quality.next then return end
	local new_eneity = ent.entity.surface.create_entity {
		name = ent.entity.name,
		position = ent.entity.position,
		direction = ent.entity.direction,
		quality = ent.entity.quality.next or ent.entity.quality,
		force = ent.entity.force,
		fast_replace = true
	}
	local temp_ent = new_eneity.surface.find_entities(new_eneity.bounding_box)
	for _, v in pairs(temp_ent) do
		if v.type == "item-entity" then
			v.destroy()
		end
	end
	storage.built_machine[ent.unit_number] = nil
	Add_storage(new_eneity)
end

function replace_inventory(inventory, contents)
	if inventory == nil or not inventory.is_empty() then
		return
	end
	local con = contents.get_contents()
	for _, item in pairs(con) do
		inventory.insert(item)
	end
end

function upgrade_module(ent)
	if not ent.entity.get_module_inventory() then return end
	local inv = ent.entity.get_module_inventory()
	if not inv then return end
	local content = inv.get_contents()
	if not content then return end
	local content1 = span_c(content)
	inv.clear()
	local upgrade = true
	for _, v in pairs(content1) do
		if prototypes.quality[v.quality].next and upgrade then
			upgrade = false
			inv.insert { name = v.name, quality = prototypes.quality[v.quality].next.name, count = v.count }
			storage.built_machine[ent.unit_number].level_time = 0
		else
			inv.insert { name = v.name, quality = v.quality, count = v.count }
		end
	end
end

function span_c(content)
	local spac_content = {}
	for _, v in pairs(content) do
		for i = 1, v.count do
			table.insert(spac_content, { name = v.name, quality = v.quality, count = 1 })
		end
	end
	return spac_content
end

function get_built_machine()
	storage.built_machine = storage.built_machine or {}
	if next(storage.built_machine) ~= nil then
		for unit_number, machine in pairs(storage.built_machines) do
			if not machine.entity or not machine.entity.valid then
				storage.built_machines[unit_number] = nil
			end
		end
	end

	for _, surface in pairs(game.surfaces) do
		local entities = surface.find_entities_filtered { type = s_filter }
		for _, v in pairs(entities) do
			Add_storage(v)
		end
	end
end

function On_built_entity(event)
	if not event.entity then return end
	Add_storage(event.entity)
end

function On_mined_entity(event)
	if not event.entity then return end
	if not storage.built_machine[event.entity.unit_number] then return end
	storage.built_machine[event.entity.unit_number] = nil
end

function Add_storage(v)
	if storage.built_machine[v.unit_number] then return end
	storage.built_machine[v.unit_number] = {
		unit_number = v.unit_number,
		entity = v,
		level_time = 0
	}
end

script.on_event(
	defines.events.on_player_mined_entity,
	On_mined_entity,
	filter
)
script.on_event(
	defines.events.on_robot_mined_entity,
	On_mined_entity,
	filter)
script.on_event(
	defines.events.on_post_entity_died,
	On_mined_entity,
	filter)
script.on_event(
	defines.events.on_robot_built_entity,
	On_built_entity,
	filter)

script.on_event(
	defines.events.on_built_entity,
	On_built_entity,
	filter)
