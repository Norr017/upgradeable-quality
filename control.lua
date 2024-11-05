require("util")

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


function get_lite_filter()
	local temp_filter = {}
	for _, v in pairs(filter) do
		table.insert(temp_filter, v.type)
	end
	return temp_filter
end

local s_filter = get_lite_filter()

local base_time = settings.startup["base_time_to_level_up"].value
local multiplier = settings.startup["multiplier_time_to_level_up"].value
local is_update_module = settings.startup["randomly_upgrade_inside_module"].value
local base_time_module = settings.startup["time_to_randomly_levelup_inside_module"].value
local respect_technology = settings.startup["respect_technology"].value
local quality_tech = {}
local active_gui = false
local first_search = true

local processed_machine_index = 1 -- Tracks the current position in the randomized list
local machine_order = {}          -- Stores the randomized order of machines to process
local max_per_tick = 50           -- Max items to process per tick

script.on_init(function()
	for _, player in pairs(game.players) do
		player.set_shortcut_toggled('toggle-machine-exp-gui', active_gui)
	end
end)

script.on_event(defines.events.on_player_created, function(event)
	local player = game.players[event.player_index]
	-- Set the toggle state of the shortcut for the newly created player
	player.set_shortcut_toggled('toggle-machine-exp-gui', active_gui)
end)

script.on_nth_tick(6, function(event)
	-- Ensure GUI toggle for all players
	for _, player in pairs(game.players) do
		player.set_shortcut_toggled('toggle-machine-exp-gui', active_gui)
	end

	-- First run initialization
	if first_search then
		get_built_machine()
		quality_tech = check_quality_unlock_tech()
		first_search = false
		refresh_machine_order()
	end

	-- If we reach the end of the machine list, refresh it to randomize the order again
	if processed_machine_index > #machine_order then
		processed_machine_index = 1
		refresh_machine_order()
	end

	-- Initialize lists for upgrades within the tick
	local upgrade_machine_list = {}
	local upgrade_module_list = {}

	-- Process up to `max_per_tick` items in each tick
	local count = 0
	while count < max_per_tick and processed_machine_index <= #machine_order do
		local ent = machine_order[processed_machine_index]
		processed_machine_index = processed_machine_index + 1
		count = count + 1

		local ticks_elapsed = game.tick - ent.last_tick
		ent.last_tick = game.tick

		local sec_passed = ticks_elapsed / 60

		-- Main logic for machine processing
		while true do
			if not ent.entity.valid then
				storage.built_machine[ent.unit_number] = nil -- Remove invalid entity
				break
			end

			local next_tech = ent.entity.quality.next
			local module_count = ent.entity.get_module_inventory()
			local have_upgradeable_module = can_upgrade_module(ent.entity)
			if not next_tech and not module_count then
				storage.built_machine[ent.unit_number] = nil -- Remove fully upgraded entity
				break
			end
			if not check_quality_unlock(next_tech) and respect_technology then break end
			if not next_tech and not have_upgradeable_module then break end         -- check if upgradeable
			if ent.level_time < base_time * multiplier ^ (ent.entity.quality.level + 1) then -- Upgrade check based on level time and base time
				--if ent.entity.status == defines.entity_status.working or ent.entity.status == defines.entity_status.fully_charged then
				ent.level_time = ent.level_time + sec_passed
				--end
			else
				table.insert(upgrade_machine_list, ent)
				ent.level_time = 0
			end

			-- Module update check
			if ent.level_time > base_time_module and is_update_module and have_upgradeable_module then
				table.insert(upgrade_module_list, ent)
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

-- Function to shuffle the table of machines for randomized order
function shuffle_table(tbl)
	local n = #tbl
	for i = 1, n do
		local j = math.random(i, n)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

-- Function to update the machine order list (shuffles only if it needs a new iteration)
function refresh_machine_order()
	machine_order = {}
	for unit_number, ent in pairs(storage.built_machine) do
		if ent.entity and ent.entity.valid then
			-- Initialize last_tick if it does not exist
			if not ent.last_tick then
				ent.last_tick = game.tick -- Set to the current tick on first encounter
			end
			table.insert(machine_order, ent)
		else
			storage.built_machine[ent.unit_number] = nil
		end
	end
	shuffle_table(machine_order) -- Shuffle once to randomize the processing order
end

function can_upgrade_module(ent)
	local module_inv = ent.get_module_inventory()
	if not module_inv then return false end
	local contents = module_inv.get_contents()
	if not contents or contents == {} then return false end
	for _, v in pairs(contents) do
		if prototypes.quality[v.quality].next then return true end
	end
	return false
end

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
	if not tech then return true end
	local name = tech.name
	local tech_name = quality_tech[name]
	if tech_name == nil then return true end
	return game.forces["player"].technologies[tech_name].researched
end

function upgrade_machines(ent)
	if not ent.entity.quality.next then return end
	local old_inv = ent.entity.get_output_inventory()
	local content
	if old_inv then -- preclear the inventory to prevent output drop to ground
		content = old_inv.get_contents()
		old_inv.clear()
	end
	local new_eneity = ent.entity.surface.create_entity {
		name = ent.entity.name,
		position = ent.entity.position,
		direction = ent.entity.direction,
		quality = ent.entity.quality.next or ent.entity.quality,
		force = ent.entity.force,
		fast_replace = true
	}
	if content then 
		for _,v in pairs(content) do
			new_eneity.get_output_inventory().insert({name = v.name,count = v.count,quality = v.quality})
		end
	end
	
	-- destroy leaving items
	local temp_ent = new_eneity.surface.find_entities(new_eneity.bounding_box)
	for _, v in pairs(temp_ent) do
		if v.type == "item-entity" then
			v.destroy()
		end
	end

	storage.built_machine[ent.unit_number] = nil
	Add_storage(new_eneity)
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

function is_include(value, tab)
	for k, v in ipairs(tab) do
		if v == value then
			return true
		end
	end
	return false
end

function On_select_changed(event)
	if not active_gui then return end
	if event.last_entity then
		local player = game.players[event.player_index]
		local gui_container = player.gui.left
		local existing_gui = gui_container["machine-exp"]

		-- Check if "quality-module" technology is researched
		local has_technology = player.force.technologies["quality-module"].researched

		-- Check if there is a last entity and if it matches the filter
		local matches_filter = false
		-- if event.last_entity then
		for _, condition in ipairs(filter) do
			if event.last_entity.type == condition.type then
				matches_filter = true
				break
			end
		end
		-- end
		if not matches_filter then return end
		-- If technology is researched and entity matches filter, show or update the GUI
		local ent_name = event.last_entity.name -- Store the raw entity name
		if not existing_gui then
			existing_gui = gui_container.add({
				type = "frame",
				name = "machine-exp",
				caption = { "", { "entity-name." .. ent_name }, " EXP" }, -- Getting the localized name
				direction = "vertical",
			})
			existing_gui.style.maximal_width = 250
			storage.gui = existing_gui.add({ type = "label", name = "exp-num", caption = "none" })
		else
			existing_gui.caption = { "", { "entity-name." .. ent_name }, " EXP" }
		end

		-- Update the GUI with EXP information if available
		if storage.built_machine[event.last_entity.unit_number] then
			storage.gui.visible = true -- Show the GUI when there is no data
			storage.gui.caption = (math.floor(storage.built_machine[event.last_entity.unit_number].level_time) or "0")
		else
			storage.gui.visible = false -- Hide the GUI when there is no data
		end
	end
end

function toggle_machine_exp_gui(player)
	local existing_gui = player.gui.left["machine-exp"]
	-- Toggle the shortcut
	player.set_shortcut_toggled('toggle-machine-exp-gui', not active_gui)

	if existing_gui then
		-- If GUI exists, destroy it
		existing_gui.destroy()
		active_gui = false
	else
		active_gui = true
	end
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
script.on_event(
	defines.events.on_selected_entity_changed,
	On_select_changed
)

script.on_event("toggle-machine-exp-key", function(event)
	local player = game.players[event.player_index]
	toggle_machine_exp_gui(player)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
	if event.prototype_name == 'toggle-machine-exp-gui' then
		local player = game.players[event.player_index]
		toggle_machine_exp_gui(player)
	end
end)
