pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Theme = struct {
    background: Color,
    background2: Color,

    surface: Color,
    surface_hover: Color,
    surface_active: Color,

    panel: Color,
    panel2: Color,

    border: Color,
    border_strong: Color,

    text: Color,
    text_muted: Color,
    text_disabled: Color,
    text_inverse: Color,

    accent: Color,
    accent_hover: Color,
    accent_active: Color,

    selection: Color,
    selection_inactive: Color,

    success: Color,
    warning: Color,
    danger: Color,
    info: Color,

    shadow: Color,
    overlay: Color,

    button: Color,
    button_hover: Color,
    button_active: Color,

    input: Color,
    input_focus: Color,

    scrollbar: Color,
    scrollbar_hover: Color,

    titlebar: Color,
    menubar: Color,

    resize_handle: Color,
    docking_preview: Color,
};

fn rgba(
    r: u8,
    g: u8,
    b: u8,
) Color {
    return .{
        .r = r,
        .g = g,
        .b = b,
        .a = 255,
    };
}

fn rgbaA(
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) Color {
    return .{
        .r = r,
        .g = g,
        .b = b,
        .a = a,
    };
}

// ============================================================
// NORD
// ============================================================

pub const Nord = Theme{
    .background = rgba(46, 52, 64),
    .background2 = rgba(52, 61, 76),

    .surface = rgba(59, 66, 82),
    .surface_hover = rgba(67, 76, 94),
    .surface_active = rgba(76, 86, 106),

    .panel = rgba(43, 48, 59),
    .panel2 = rgba(50, 56, 68),

    .border = rgba(76, 86, 106),
    .border_strong = rgba(94, 129, 172),

    .text = rgba(236, 239, 244),
    .text_muted = rgba(216, 222, 233),
    .text_disabled = rgba(136, 146, 176),
    .text_inverse = rgba(46, 52, 64),

    .accent = rgba(136, 192, 208),
    .accent_hover = rgba(143, 188, 187),
    .accent_active = rgba(129, 161, 193),

    .selection = rgba(94, 129, 172),
    .selection_inactive = rgba(76, 86, 106),

    .success = rgba(163, 190, 140),
    .warning = rgba(235, 203, 139),
    .danger = rgba(191, 97, 106),
    .info = rgba(129, 161, 193),

    .shadow = rgba(0, 0, 0),
    .overlay = rgbaA(0, 0, 0, 128),

    .button = rgba(67, 76, 94),
    .button_hover = rgba(76, 86, 106),
    .button_active = rgba(94, 129, 172),

    .input = rgba(59, 66, 82),
    .input_focus = rgba(94, 129, 172),

    .scrollbar = rgba(76, 86, 106),
    .scrollbar_hover = rgba(94, 129, 172),

    .titlebar = rgba(43, 48, 59),
    .menubar = rgba(50, 56, 68),

    .resize_handle = rgba(129, 161, 193),
    .docking_preview = rgbaA(94, 129, 172, 120),
};

// ============================================================
// CATPPUCCIN MOCHA
// ============================================================

pub const Catppuccin = Theme{
    .background = rgba(30, 30, 46),
    .background2 = rgba(24, 24, 37),

    .surface = rgba(49, 50, 68),
    .surface_hover = rgba(69, 71, 90),
    .surface_active = rgba(88, 91, 112),

    .panel = rgba(24, 24, 37),
    .panel2 = rgba(49, 50, 68),

    .border = rgba(88, 91, 112),
    .border_strong = rgba(137, 180, 250),

    .text = rgba(205, 214, 244),
    .text_muted = rgba(166, 173, 200),
    .text_disabled = rgba(127, 132, 156),
    .text_inverse = rgba(30, 30, 46),

    .accent = rgba(137, 180, 250),
    .accent_hover = rgba(116, 199, 236),
    .accent_active = rgba(203, 166, 247),

    .selection = rgba(88, 91, 112),
    .selection_inactive = rgba(69, 71, 90),

    .success = rgba(166, 227, 161),
    .warning = rgba(249, 226, 175),
    .danger = rgba(243, 139, 168),
    .info = rgba(116, 199, 236),

    .shadow = rgba(0, 0, 0),
    .overlay = rgbaA(0, 0, 0, 128),

    .button = rgba(69, 71, 90),
    .button_hover = rgba(88, 91, 112),
    .button_active = rgba(137, 180, 250),

    .input = rgba(49, 50, 68),
    .input_focus = rgba(137, 180, 250),

    .scrollbar = rgba(88, 91, 112),
    .scrollbar_hover = rgba(137, 180, 250),

    .titlebar = rgba(24, 24, 37),
    .menubar = rgba(30, 30, 46),

    .resize_handle = rgba(137, 180, 250),
    .docking_preview = rgbaA(137, 180, 250, 120),
};

// ============================================================
// TOKYO NIGHT
// ============================================================

pub const TokyoNight = Theme{
    .background = rgba(26, 27, 38),
    .background2 = rgba(22, 22, 30),

    .surface = rgba(36, 40, 59),
    .surface_hover = rgba(41, 46, 66),
    .surface_active = rgba(68, 71, 90),

    .panel = rgba(22, 22, 30),
    .panel2 = rgba(36, 40, 59),

    .border = rgba(68, 71, 90),
    .border_strong = rgba(122, 162, 247),

    .text = rgba(192, 202, 245),
    .text_muted = rgba(162, 177, 214),
    .text_disabled = rgba(86, 95, 137),
    .text_inverse = rgba(26, 27, 38),

    .accent = rgba(122, 162, 247),
    .accent_hover = rgba(125, 207, 255),
    .accent_active = rgba(187, 154, 247),

    .selection = rgba(51, 61, 88),
    .selection_inactive = rgba(41, 46, 66),

    .success = rgba(158, 206, 106),
    .warning = rgba(224, 175, 104),
    .danger = rgba(247, 118, 142),
    .info = rgba(125, 207, 255),

    .shadow = rgba(0, 0, 0),
    .overlay = rgbaA(0, 0, 0, 128),

    .button = rgba(41, 46, 66),
    .button_hover = rgba(68, 71, 90),
    .button_active = rgba(122, 162, 247),

    .input = rgba(36, 40, 59),
    .input_focus = rgba(122, 162, 247),

    .scrollbar = rgba(68, 71, 90),
    .scrollbar_hover = rgba(122, 162, 247),

    .titlebar = rgba(22, 22, 30),
    .menubar = rgba(26, 27, 38),

    .resize_handle = rgba(122, 162, 247),
    .docking_preview = rgbaA(122, 162, 247, 120),
};

// ============================================================
// ONE DARK
// ============================================================

pub const OneDark = Theme{
    .background = rgba(40, 44, 52),
    .background2 = rgba(33, 37, 43),

    .surface = rgba(49, 54, 63),
    .surface_hover = rgba(56, 62, 73),
    .surface_active = rgba(92, 99, 112),

    .panel = rgba(33, 37, 43),
    .panel2 = rgba(49, 54, 63),

    .border = rgba(92, 99, 112),
    .border_strong = rgba(97, 175, 239),

    .text = rgba(171, 178, 191),
    .text_muted = rgba(130, 137, 151),
    .text_disabled = rgba(92, 99, 112),
    .text_inverse = rgba(40, 44, 52),

    .accent = rgba(97, 175, 239),
    .accent_hover = rgba(86, 182, 194),
    .accent_active = rgba(198, 120, 221),

    .selection = rgba(62, 68, 81),
    .selection_inactive = rgba(49, 54, 63),

    .success = rgba(152, 195, 121),
    .warning = rgba(229, 192, 123),
    .danger = rgba(224, 108, 117),
    .info = rgba(86, 182, 194),

    .shadow = rgba(0, 0, 0),
    .overlay = rgbaA(0, 0, 0, 128),

    .button = rgba(56, 62, 73),
    .button_hover = rgba(92, 99, 112),
    .button_active = rgba(97, 175, 239),

    .input = rgba(49, 54, 63),
    .input_focus = rgba(97, 175, 239),

    .scrollbar = rgba(92, 99, 112),
    .scrollbar_hover = rgba(97, 175, 239),

    .titlebar = rgba(33, 37, 43),
    .menubar = rgba(40, 44, 52),

    .resize_handle = rgba(97, 175, 239),
    .docking_preview = rgbaA(97, 175, 239, 120),
};

// ============================================================
// DRACULA
// ============================================================

pub const Dracula = Theme{
    .background = rgba(40, 42, 54),
    .background2 = rgba(32, 34, 44),

    .surface = rgba(68, 71, 90),
    .surface_hover = rgba(98, 114, 164),
    .surface_active = rgba(139, 233, 253),

    .panel = rgba(32, 34, 44),
    .panel2 = rgba(68, 71, 90),

    .border = rgba(98, 114, 164),
    .border_strong = rgba(139, 233, 253),

    .text = rgba(248, 248, 242),
    .text_muted = rgba(189, 147, 249),
    .text_disabled = rgba(98, 114, 164),
    .text_inverse = rgba(40, 42, 54),

    .accent = rgba(139, 233, 253),
    .accent_hover = rgba(80, 250, 123),
    .accent_active = rgba(255, 121, 198),

    .selection = rgba(68, 71, 90),
    .selection_inactive = rgba(50, 53, 68),

    .success = rgba(80, 250, 123),
    .warning = rgba(241, 250, 140),
    .danger = rgba(255, 85, 85),
    .info = rgba(139, 233, 253),

    .shadow = rgba(0, 0, 0),
    .overlay = rgbaA(0, 0, 0, 128),

    .button = rgba(68, 71, 90),
    .button_hover = rgba(98, 114, 164),
    .button_active = rgba(139, 233, 253),

    .input = rgba(68, 71, 90),
    .input_focus = rgba(139, 233, 253),

    .scrollbar = rgba(98, 114, 164),
    .scrollbar_hover = rgba(139, 233, 253),

    .titlebar = rgba(32, 34, 44),
    .menubar = rgba(40, 42, 54),

    .resize_handle = rgba(139, 233, 253),
    .docking_preview = rgbaA(139, 233, 253, 120),
};

// ============================================================
// DEBUG / HIGH CONTRAST TEST THEME
// ============================================================

pub const DebugHighContrast = Theme{
    .background = rgba(0, 0, 0),
    .background2 = rgba(20, 20, 20),

    .surface = rgba(255, 0, 0),
    .surface_hover = rgba(255, 128, 0),
    .surface_active = rgba(255, 255, 0),

    .panel = rgba(0, 255, 0),
    .panel2 = rgba(0, 180, 0),

    .border = rgba(255, 255, 255),
    .border_strong = rgba(0, 255, 255),

    .text = rgba(255, 255, 255),
    .text_muted = rgba(180, 180, 180),
    .text_disabled = rgba(120, 120, 120),
    .text_inverse = rgba(0, 0, 0),

    .accent = rgba(0, 128, 255),
    .accent_hover = rgba(0, 200, 255),
    .accent_active = rgba(255, 0, 255),

    .selection = rgba(255, 255, 0),
    .selection_inactive = rgba(120, 120, 0),

    .success = rgba(0, 255, 0),
    .warning = rgba(255, 255, 0),
    .danger = rgba(255, 0, 0),
    .info = rgba(0, 255, 255),

    .shadow = rgba(0, 0, 0),
    .overlay = rgbaA(255, 0, 255, 100),

    .button = rgba(0, 0, 255),
    .button_hover = rgba(0, 128, 255),
    .button_active = rgba(0, 255, 255),

    .input = rgba(255, 128, 0),
    .input_focus = rgba(255, 255, 255),

    .scrollbar = rgba(255, 0, 255),
    .scrollbar_hover = rgba(255, 255, 255),

    .titlebar = rgba(255, 0, 0),
    .menubar = rgba(0, 0, 255),

    .resize_handle = rgba(255, 255, 255),
    .docking_preview = rgbaA(0, 255, 255, 180),
};
