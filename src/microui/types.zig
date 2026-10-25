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
pub const Clip = enum(i32) {
    none = 0,
    part = 1,
    all = 2,

    pub inline fn toInt(self: Clip) i32 {
        return @intFromEnum(self);
    }
};

/// Tùy chọn cấu hình cho Cửa sổ (Window), Bảng (Panel) và Widget.
pub const Opt = enum(i32) {
    none = 0,
    align_center = (1 << 0),
    align_right = (1 << 1),
    no_interact = (1 << 2),
    no_frame = (1 << 3),
    no_resize = (1 << 4),
    no_scroll = (1 << 5),
    no_close = (1 << 6),
    no_title = (1 << 7),
    hold_focus = (1 << 8),
    auto_size = (1 << 9),
    popup = (1 << 10),
    closed = (1 << 11),
    expanded = (1 << 12),

    pub inline fn toInt(self: Opt) i32 {
        return @intFromEnum(self);
    }

    pub inline fn has(val: i32, opt: Opt) bool {
        return (val & opt.toInt()) != 0;
    }

    pub inline fn combine(opts: anytype) i32 {
        var res: i32 = 0;
        inline for (opts) |opt| {
            const o: Opt = opt;
            res |= o.toInt();
        }
        return res;
    }
};

/// Kết quả phản hồi từ tương tác của người dùng trên widget.
pub const Res = enum(i32) {
    none = 0,
    active = (1 << 0),
    submit = (1 << 1),
    change = (1 << 2),

    pub inline fn toInt(self: Res) i32 {
        return @intFromEnum(self);
    }

    pub inline fn has(val: i32, res: Res) bool {
        return (val & res.toInt()) != 0;
    }
};

/// Mã các nút chuột.
pub const Mouse = enum(i32) {
    none = 0,
    left = (1 << 0),
    right = (1 << 1),
    middle = (1 << 2),

    pub inline fn toInt(self: Mouse) i32 {
        return @intFromEnum(self);
    }
};

/// Mã các phím bổ trợ và phím điều khiển bàn phím.
pub const Key = enum(i32) {
    none = 0,
    shift = (1 << 0),
    ctrl = (1 << 1),
    alt = (1 << 2),
    backspace = (1 << 3),
    @"return" = (1 << 4),

    pub inline fn toInt(self: Key) i32 {
        return @intFromEnum(self);
    }
};

/// Định danh các biểu tượng (Icon) chuẩn.
pub const Icon = enum(i32) {
    none = 0,
    close = 1,
    check = 2,
    collapsed = 3,
    expanded = 4,

    pub inline fn toInt(self: Icon) i32 {
        return @intFromEnum(self);
    }
};
