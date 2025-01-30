require("util")
require "scripts.gui"
require "scripts.skip_entities"

if storage.built_machine == nil then
	storage.built_machine = {}
end
local is_update_module = settings.startup["upgrade_module"].value
local respect_technology = settings.startup["respect_technology"].value

local base_time = settings.global["base_time_to_level_up"].value
local multiplier = settings.global["multiplier_time_to_level_up"].value
local base_time_module = settings.global["time_to_randomly_levelup_inside_module"].value

local first_search = true

local processed_machine_index = 1 -- Tracks the current position in the randomized list
local max_per_tick = 50           -- Max items to process per tick

script.on_init(function()

end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function()
	base_time = settings.global["base_time_to_level_up"].value
	multiplier = settings.global["multiplier_time_to_level_up"].value
	base_time_modue = settings.global["time_to_randomly_levelup_inside_module"].value
	gui_option = settings.global["show_exp_gui"]
	change_exp_gui(gui_option)
end)

script.on_nth_tick(6, function(event)
	-- First run initialization
	if first_search then
		first_search = false
		get_built_machine()
		initialize_gui()
	end

	-- Initialize lists for upgrade within the tick
	local upgrade_machine_list = {}
	local upgrade_module_list = {}

	-- Process up to `max_per_tick` items in each tick
	if next(storage.built_machine) == nil then return end
	local index = 0
	while index < max_per_tick do
		local ent = get_next_machine()
		if not ent then break end
		if not ent.last_tick then ent.last_tick = game.tick end
		local ticks_elapsed = game.tick - ent.last_tick
		ent.last_tick = game.tick
		local sec_passed = ticks_elapsed / 60

		-- Main logic for machine processing
		while true do
			-- check for machine valid
			if not ent.entity.valid then -- Remove invalid entity
				storage.built_machine[ent.unit_number] = nil
				break
			end
			-- check entitys in blacklist
			local skip = false
			for _, v in pairs(skipped_entities) do
				if string.find(ent.entity.name, v, 1, true) then
					skip = true
					break
				end
			end
			if skip then
				storage.built_machine[ent.unit_number] = nil
				break
			end
			-- Remove fully upgraded entity,with no next level and no module space
			if not ent.entity.quality.next and not ent.entity.get_module_inventory() then
				storage.built_machine[ent.unit_number] = nil
				break
			end
			-- Remove hidden entity
			local flags = ent.entity.prototype.flags
			if not flags_check(ent.entity) then
				storage.built_machine[ent.unit_number] = nil
				break
			end

			-- Working check
			if ent.entity.status == defines.entity_status.working or
				ent.entity.status == defines.entity_status.fully_charged or
				ent.entity.status == defines.entity_status.normal or
				ent.entity.status == nil then
				local machine_check = can_upgrade_machine(ent.entity)
				local module_check = can_upgrade_module(ent.entity)
				local target_time = base_time * multiplier ^ (ent.entity.quality.level + 1)

				if ent.level_time < target_time and ent.level_time < 999999 then
					ent.level_time = ent.level_time + sec_passed
				end
				-- machine update check
				if ent.level_time >= target_time and machine_check then
					table.insert(upgrade_machine_list, ent)
					ent.level_time = 0
				end
				-- Module update check
				if ent.level_time >= base_time_module and is_update_module and module_check then
					table.insert(upgrade_module_list, ent)
					ent.level_time = 0
				end
			end

			break
		end
	end

	-- Perform upgrades based on lists created
	for _, v in pairs(upgrade_machine_list) do
		upgrade_machines(v)
	end
	for _, v in pairs(upgrade_module_list) do
		upgrade_module(v)
	end
end)

function get_next_machine()
	local res = next(storage.built_machine, processed_machine_index)
	if res then
		processed_machine_index = res
		return storage.built_machine[processed_machine_index]
	else
		processed_machine_index = 1
		return nil
	end
end

function can_upgrade_machine(ent)
	if respect_technology then
		return check_quality_unlock(ent.quality.next)
	else
		return ent.quality.next
	end
end

function can_upgrade_module(ent)
	local module_inv = ent.get_module_inventory()
	if not module_inv then return false end
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
	if not tech then return false end
	return game.forces["player"].is_quality_unlocked(tech)
end

function upgrade_machines(ent)
	if not ent.entity.quality.next then return end
	local temp_name = ent.entity.name
	local new_eneity = ent.entity.surface.create_entity {
		name = ent.entity.name,
		position = ent.entity.position,
		direction = ent.entity.direction,
		quality = ent.entity.quality.next,
		force = ent.entity.force,
		fast_replace = true,
		raise_built = true
	}
	if new_eneity == nil then
		game.print(temp_name .. ",this entity cant upgrade normal,try add it to block list")
		storage.built_machine[ent.unit_number] = nil
		return
	end
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

	storage.built_machine[ent.unit_number] = nil
	Add_storage(new_eneity)
end

function upgrade_module(ent)
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

	for _, surface in pairs(game.surfaces) do
		local entities = surface.find_entities_filtered { force = "player" }
		for _, v in pairs(entities) do
			if flags_check(v) then
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

function On_built_entity(event)
	if not event.entity then return end
	if flags_check(event.entity) then
		Add_storage(event.entity)
	end
end

function Add_storage(v)
	if storage.built_machine[v.unit_number] then return end
	storage.built_machine[v.unit_number] = {
		unit_number = v.unit_number,
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
