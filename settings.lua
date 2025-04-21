data:extend({
    {
        type = "bool-setting",
        name = "upgrade_module",
        order = "a",
        setting_type = "startup",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "upgrade_space_age",
        order = "b",
        setting_type = "startup",
        default_value = true
    },
    -- {
    --     type = "bool-setting",
    --     name = "upgrade_armor",
    --     order = "c",
    --     setting_type = "startup",
    --     default_value = true
    -- },
    {
        type = "string-setting",
        name = "skipped_entities",
        setting_type = "startup",
		order = "d",
        default_value = "belt,splitter,loader,pipe,rail,combinator",
        allow_blank = true
    },
    {
        type = "int-setting",
        name = "base_time_to_level_up",
        setting_type = "runtime-global",
        default_value = 3600,
        minimum_value = 1,
        maximum_value = 99999,
    },
    {
        type = "double-setting",
        name = "multiplier_time_to_level_up",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 10,
    },
    {
        type = "int-setting",
        name = "time_to_randomly_levelup_inside_module",
        setting_type = "runtime-global",
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
    {
        type = "bool-setting",
        name = "show_exp_gui",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "direct_to_max_quality",
        setting_type = "runtime-global",
        default_value = false
    }
})
