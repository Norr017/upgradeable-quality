data:extend({
    {
        type = "int-setting",
        name = "base_time_to_level_up",
        setting_type = "startup",
        default_value = 3600,
        minimum_value = 1,
        maximum_value = 99999,
    },
    {
        type = "double-setting",
        name = "multiplier_time_to_level_up",
        setting_type = "startup",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 10,
    },
    {
        type = "bool-setting",
        name = "randomly_upgrade_inside_module",
        setting_type = "startup",
        default_value = true
    },
    {
        type = "int-setting",
        name = "time_to_randomly_levelup_inside_module",
        setting_type = "startup",
        default_value = 3600,
        minimum_value = 1,
        maximum_value = 99999,
    },
    {
        type = "bool-setting",
        name = "respect_technology",
        setting_type = "startup",
        default_value = true
    },
})
