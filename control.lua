require "util"
require "scripts.gui"
require "scripts.skip_entities"

storage.built_machine = storage.built_machine or {}
local is_update_module = settings.startup["upgrade_module"].value
local respect_technology = settings.startup["respect_technology"].value

local base_time = settings.global["base_time_to_level_up"].value
local multiplier = settings.global["multiplier_time_to_level_up"].value
local base_time_module = settings.global["time_to_randomly_levelup_inside_module"].value
local to_max = settings.global["direct_to_max_quality"].value
local first_search = true

local processed_machine_index = nil -- Tracks the current position in the randomized list
local max_per_tick = 30             -- Max items to process per tick

script.on_init(function()

end)
script.on_load(function()

end)
script.on_event(defines.events.on_runtime_mod_setting_changed, function()
	base_time = settings.global["base_time_to_level_up"].value
	multiplier = settings.global["multiplier_time_to_level_up"].value
	base_time_modue = settings.global["time_to_randomly_levelup_inside_module"].value
	to_max = settings.global["direct_to_max_quality"].value
	change_exp_gui(settings.global["show_exp_gui"].value)
end)

script.on_nth_tick(6, function()
	-- First run initialization
	if first_search then
		first_search = false
		get_built_machine()
		initialize_gui()
		return
	end

	-- Initialize lists for upgrade within the tick
	local upgrade_machine_list = {}
	local upgrade_module_list = {}
	local new_entity_list = {}
	local delete_entity_list = {}
	-- Process up to `max_per_tick` items in each tick
	if next(storage.built_machine) == nil then return end
	local machine_check_list = get_machine_check_list(max_per_tick) or {}
	if next(machine_check_list) == nil then return end
	for unit_number, ent in pairs(machine_check_list) do
		if not ent.last_tick then ent.last_tick = game.tick end
		local ticks_elapsed = game.tick - ent.last_tick
		ent.last_tick = game.tick
		local sec_passed = ticks_elapsed / 60

		-- Main logic for machine processing
		while true do
			-- check for machine valid
			if not ent.entity.valid then -- Remove invalid entity
				table.insert(delete_entity_list, unit_number)
				break
			end
			-- check entitys in blacklist

			if not blacklist_check(ent.entity) or not flags_check(ent.entity) then
				table.insert(delete_entity_list, unit_number)
				break
			end
			-- Remove fully upgraded entity,with no next level and no module space
			if ent.machine_max and ent.no_module then
				table.insert(delete_entity_list, unit_number)
				break
			end

			-- Working check
			if ent.entity.status == defines.entity_status.working or
				ent.entity.status == defines.entity_status.fully_charged or
				ent.entity.status == defines.entity_status.normal or
				ent.entity.status == nil then
				local machine_check = can_upgrade_machine(ent)
				local module_check = can_upgrade_module(ent)
				local target_time = base_time * multiplier ^ (ent.entity.quality.level + 1)

				if ent.level_time < target_time and ent.level_time < 999999 then
					ent.level_time = ent.level_time + sec_passed
					-- machine update check
				elseif ent.level_time >= target_time and machine_check then
					table.insert(upgrade_machine_list, ent)
					ent.level_time = 0
					-- Module update check
				elseif ent.level_time >= base_time_module and is_update_module and module_check then
					table.insert(upgrade_module_list, ent)
					ent.level_time = 0
				end
			end
			break
		end
	end

	-- Perform upgrades based on lists created

	for _, v in pairs(upgrade_machine_list) do
		local number = v.entity.unit_number
		local new_entity = upgrade_machines(v)
		if new_entity then
			table.insert(new_entity_list, new_entity)
		end
		table.insert(delete_entity_list, number)
	end
	for _, v in pairs(upgrade_module_list) do
		upgrade_module(v)
	end
	for _, v in pairs(new_entity_list) do
		Add_storage(v)
	end
	for _, v in pairs(delete_entity_list) do
		storage.built_machine[v] = nil
	end
end)
function get_max_quality()
	local qualitys = prototypes.quality
	local max = {0,0}
	for _,v in pairs(qualitys) do
		local temp = {v.level,v.name}
		if(temp[1]>max[1]) then
			max = temp
		end
	end
	return max[2]
end
local max_quality = get_max_quality()
function get_machine_check_list(count)
	local list = {}
	local res
	for i = 1, count do
		res = next(storage.built_machine, processed_machine_index)
		if res then
			processed_machine_index = res
			list[res] = storage.built_machine[processed_machine_index]
		else
			processed_machine_index = nil
			break
		end
	end
	return list
end

function can_upgrade_machine(ent)
	if ent.machine_max then
		return false
	end
	local quality_next = ent.entity.quality.next
	if quality_next then
		if respect_technology and not check_quality_unlock(quality_next) then
			return false
		end
		return true
	else
		ent.machine_max = true
		return false
	end
end

function can_upgrade_module(ent)
	if ent.no_module then return end
	local module_inv = ent.entity.get_module_inventory()
	if not module_inv then
		ent.no_module = true
		return false
	end
	local contents = module_inv.get_contents()
	if not contents or contents == {} then return false end
	for _, v in pairs(contents) do
		local next_quality = prototypes.quality[v.quality].next
		if respect_technology then
			return next_quality and check_quality_unlock(next_quality)
		else
			return next_quality
		end
	end
end

function check_quality_unlock(tech)
	return game.forces["player"].is_quality_unlocked(tech)
end

function upgrade_machines(ent)
	if not ent.entity.quality.next then return end
	local temp_name = ent.entity.name
	local mirr = ent.entity.mirroring
	local qua
	if to_max then
		qua = max_quality
	else
		qua = ent.entity.quality.next
	end
	local new_eneity = ent.entity.surface.create_entity {
		name = ent.entity.name,
		position = ent.entity.position,
		direction = ent.entity.direction,
		quality = qua,
		force = ent.entity.force,
		fast_replace = true,
		raise_built = true
	}
	if new_eneity == nil then
		game.print(temp_name .. ",this entity cant upgrade normal,try add it to block list")
		return nil
	end
	new_eneity.mirroring = mirr
	-- destroy leaving items
	local bounding = new_eneity.bounding_box
	local expand = 5
	bounding["left_top"]["x"] = bounding["left_top"]["x"] - expand
	bounding["left_top"]["y"] = bounding["left_top"]["y"] - expand
	bounding["right_bottom"]["x"] = bounding["right_bottom"]["x"] + expand
	bounding["right_bottom"]["y"] = bounding["right_bottom"]["y"] + expand

	local temp_ent = new_eneity.surface.find_entities(bounding)
	for _, v in pairs(temp_ent) do
		if v.type == "item-entity" then
			v.destroy()
		end
	end
	return new_eneity
end

function upgrade_module(ent)
	local inv = ent.entity.get_module_inventory()
	if not inv then return end
	local content = inv.get_contents()
	if not content then return end
	local content1 = span_c(content)
	inv.clear()
	local upgrade = true
	local qua
	if to_max then
		qua = max_quality
	else
		qua = ent.entity.quality.next
	end
	for _, v in pairs(content1) do
		if prototypes.quality[v.quality].next and upgrade then
			upgrade = false
			inv.insert { name = v.name, quality = qua, count = v.count }
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
	for _, surface in pairs(game.surfaces) do
		local entities = surface.find_entities_filtered { force = "player" }
		for _, v in pairs(entities) do
			if storage.built_machine[v.unit_number] then break end
			if flags_check(v) and blacklist_check(v) then
				Add_storage(v)
			end
		end
	end
end

function flags_check(ent)
	flags = ent.prototype.flags
	if not ent.minable_flag then return false end
	if flags == nil or flags == {} then return false end
	local player_creation = false
	for k, _ in pairs(flags) do
		if k == "player-creation" then
			player_creation = true
		elseif k == "not-selectable-in-game" or
			k == "not-deconstructable" or
			k == "not-blueprintable" or
			k == "placeable-off-grid" then
			return false
		end
	end
	return player_creation
end

function blacklist_check(ent)
	for _, v in pairs(skipped_entities) do
		if string.find(ent.name, v, 1, true) then
			return false
		end
	end
	return true
end

function On_built_entity(event)
	if not event.entity then return end
	if flags_check(event.entity) and blacklist_check(event.entity) then
		Add_storage(event.entity)
	end
end

function Add_storage(v)
	if storage.built_machine[v.unit_number] then return end
	storage.built_machine[v.unit_number] = {
		entity = v,
		level_time = 0
	}
end

function is_include(value, tab)
	for k, v in ipairs(tab) do
		if v == value then
			return true
		end
	end
	return false
end

script.on_event(
	defines.events.on_robot_built_entity,
	On_built_entity)

script.on_event(
	defines.events.on_built_entity,
	On_built_entity)

script.on_event(
	defines.events.on_space_platform_built_entity,
	On_built_entity
)
commands.add_command("uq-show-checklist-num", nil, function()
	local num = 0
	for _, _ in pairs(storage.built_machine) do
		num = num + 1
	end
	game.print(num)
end)
