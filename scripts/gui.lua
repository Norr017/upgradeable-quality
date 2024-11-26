
function On_select_changed(event)
	if not active_gui then return end
	if event.last_entity then
		local player = game.players[event.player_index]
		local gui_container = player.gui.left
		local existing_gui = gui_container["machine-exp"]

		-- Check if "quality-module" technology is researched
		-- local has_technology = player.force.technologies["quality-module"].researched

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
