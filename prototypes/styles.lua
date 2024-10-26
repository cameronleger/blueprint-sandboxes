data.raw["gui-style"]["default"][BPSB.pfx .. "padded-horizontal-flow"] = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    horizontal_spacing = 6,
}

data.raw["gui-style"]["default"][BPSB.pfx .. "centered-horizontal-flow"] = {
    type = "horizontal_flow_style",
    parent = BPSB.pfx .. "padded-horizontal-flow",
    vertical_align = "center",
}

data.raw["gui-style"]["default"][BPSB.pfx .. "drag-handle"] = {
    type = "empty_widget_style",
    parent = "draggable_space",
    height = 32,
    horizontally_stretchable = "on",
    right_margin = 4,
}

data.raw["gui-style"]["default"][BPSB.pfx .. "sprite-like-tool-button"] = {
    type = "image_style",
    parent = "image",
    natural_size = 28,
    stretch_image_to_widget_size = true,
}

data.raw["gui-style"]["default"][BPSB.pfx .. "left-padded-checkbox"] = {
    type = "checkbox_style",
    parent = "checkbox",
    left_margin = 8,
}

data.raw["gui-style"]["default"][BPSB.pfx .. "surface-property-table"] = {
    type = "table_style",
    wide_as_column_count = true,
    margin = 8,
    column_alignments = {
        { -- property
            column = 1,
            alignment = "right",
        },
        { -- input
            column = 2,
            alignment = "center",
        },
        { -- unit
            column = 3,
            alignment = "left",
        },
    },
}

data.raw["gui-style"]["default"][BPSB.pfx .. "surface-property-description"] = {
    type = "label_style",
    single_line = false,
    maximal_width = 300,
    margin = 12,
}