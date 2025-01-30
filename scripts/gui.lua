function On_select_changed(event)
	if not active_gui then return end
	if event.last_entity then
		if not storage.built_machine[event.last_entity.unit_number] then return end
		local player = game.players[event.player_index]
		local gui_container = player.gui.left
		local existing_gui = gui_container["machine-exp"]
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
		storage.gui.parent.visible = true
		storage.gui.visible = true -- Show the GUI when there is no data
		storage.gui.caption = (math.floor(storage.built_machine[event.last_entity.unit_number].level_time) or "0")
	end
end

function change_exp_gui(option)
	for _, player in pairs(game.players) do
		local existing_gui = player.gui.left["machine-exp"]
		if option.value then
			active_gui = true
		else
			if existing_gui then existing_gui.destroy() end
			active_gui = false
		end
	end
end

function initialize_gui()
	gui_option = settings.global["show_exp_gui"]
	change_exp_gui(gui_option)
end

script.on_event(
	defines.events.on_selected_entity_changed,
	On_select_changed
)
