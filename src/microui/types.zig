//! MicroUI Core Types, Constants & Enums
//!
//! Định nghĩa các hằng số, cờ cấu hình (Opt), kết quả trả về (Res),
//! mã nút chuột (Mouse), phím điều khiển (Key), biểu tượng (Icon) và Clipping.

/// Mã định danh của widget/control trong MicroUI (32-bit FNV-1a hash).
pub const Id = u32;

/// Độ dài chuỗi tối đa cho việc format số thực.
pub const MAX_FMT: usize = 127;

/// Chuỗi định dạng mặc định cho slider.
pub const SLIDER_FMT = "%.2f";

/// Cắt khung hiển thị (Clipping).
pub const Clip = struct {
    pub const PART: i32 = 1;
    pub const ALL: i32 = 2;
};

/// Tùy chọn cấu hình cho Cửa sổ (Window), Bảng (Panel) và Widget.
pub const Opt = struct {
    pub const ALIGNCENTER: i32 = (1 << 0);
    pub const ALIGNRIGHT: i32 = (1 << 1);
    pub const NOINTERACT: i32 = (1 << 2);
    pub const NOFRAME: i32 = (1 << 3);
    pub const NORESIZE: i32 = (1 << 4);
    pub const NOSCROLL: i32 = (1 << 5);
    pub const NOCLOSE: i32 = (1 << 6);
    pub const NOTITLE: i32 = (1 << 7);
    pub const HOLDFOCUS: i32 = (1 << 8);
    pub const AUTOSIZE: i32 = (1 << 9);
    pub const POPUP: i32 = (1 << 10);
    pub const CLOSED: i32 = (1 << 11);
    pub const EXPANDED: i32 = (1 << 12);
};

/// Kết quả phản hồi từ tương tác của người dùng trên widget.
pub const Res = struct {
    pub const ACTIVE: i32 = (1 << 0);
    pub const SUBMIT: i32 = (1 << 1);
    pub const CHANGE: i32 = (1 << 2);
};

/// Mã các nút chuột.
pub const Mouse = struct {
    pub const LEFT: i32 = (1 << 0);
    pub const RIGHT: i32 = (1 << 1);
    pub const MIDDLE: i32 = (1 << 2);
};

/// Mã các phím bổ trợ và phím điều khiển bàn phím.
pub const Key = struct {
    pub const SHIFT: i32 = (1 << 0);
    pub const CTRL: i32 = (1 << 1);
    pub const ALT: i32 = (1 << 2);
    pub const BACKSPACE: i32 = (1 << 3);
    pub const RETURN: i32 = (1 << 4);
};

/// Định danh các biểu tượng (Icon) chuẩn.
pub const Icon = struct {
    pub const CLOSE: i32 = 1;
    pub const CHECK: i32 = 2;
    pub const COLLAPSED: i32 = 3;
    pub const EXPANDED: i32 = 4;
};

// =============================================================================
// Backward Compatibility Aliases (C-API style)
// =============================================================================

pub const MU_CLIP_PART = Clip.PART;
pub const MU_CLIP_ALL = Clip.ALL;

pub const MU_OPT_ALIGNCENTER = Opt.ALIGNCENTER;
pub const MU_OPT_ALIGNRIGHT = Opt.ALIGNRIGHT;
pub const MU_OPT_NOINTERACT = Opt.NOINTERACT;
pub const MU_OPT_NOFRAME = Opt.NOFRAME;
pub const MU_OPT_NORESIZE = Opt.NORESIZE;
pub const MU_OPT_NOSCROLL = Opt.NOSCROLL;
pub const MU_OPT_NOCLOSE = Opt.NOCLOSE;
pub const MU_OPT_NOTITLE = Opt.NOTITLE;
pub const MU_OPT_HOLDFOCUS = Opt.HOLDFOCUS;
pub const MU_OPT_AUTOSIZE = Opt.AUTOSIZE;
pub const MU_OPT_POPUP = Opt.POPUP;
pub const MU_OPT_CLOSED = Opt.CLOSED;
pub const MU_OPT_EXPANDED = Opt.EXPANDED;

pub const MU_RES_ACTIVE = Res.ACTIVE;
pub const MU_RES_SUBMIT = Res.SUBMIT;
pub const MU_RES_CHANGE = Res.CHANGE;

pub const MU_MOUSE_LEFT = Mouse.LEFT;
pub const MU_MOUSE_RIGHT = Mouse.RIGHT;
pub const MU_MOUSE_MIDDLE = Mouse.MIDDLE;

pub const MU_KEY_SHIFT = Key.SHIFT;
pub const MU_KEY_CTRL = Key.CTRL;
pub const MU_KEY_ALT = Key.ALT;
pub const MU_KEY_BACKSPACE = Key.BACKSPACE;
pub const MU_KEY_RETURN = Key.RETURN;

pub const MU_ICON_CLOSE = Icon.CLOSE;
pub const MU_ICON_CHECK = Icon.CHECK;
pub const MU_ICON_COLLAPSED = Icon.COLLAPSED;
pub const MU_ICON_EXPANDED = Icon.EXPANDED;

pub const MU_MAX_FMT = MAX_FMT;
pub const MU_SLIDER_FMT = SLIDER_FMT;
