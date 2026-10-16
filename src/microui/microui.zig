//! MicroUI - Thư viện Immediate Mode GUI thuần Zig
//!
//! Thiết kế và kiến trúc:
//! 1. Immediate Mode UI: Giao diện được dựng lại mỗi frame theo phong cách phản ứng (declarative/immediate).
//! 2. Zero Runtime Heap Allocation: Sử dụng các Stack tĩnh (BuildStack) và bộ nhớ đệm lệnh (FixedBufferAllocator)
//!    giúp loại bỏ cấp phát heap trong vòng lặp render chính.
//! 3. Layout Engine: Hệ thống bố cục theo hàng (Row Layout) linh hoạt, hỗ trợ độ rộng cố định, tự động chia đều,
//!    lùi dòng (indentation) và chia cột đa tầng (nested columns).
//! 4. State Pools: Quản lý trạng thái mở/đóng của TreeNode và vị trí scroll của Container thông qua các pool tĩnh.

const std = @import("std");
const stack = @import("stack.zig");
pub const math = @import("math.zig");
pub const Rect = math.Rect;
pub const Vec2 = math.Vec2;
const style_mod = @import("style.zig");
pub const style = style_mod;
const command_mod = @import("command.zig");

// =============================================================================
// 1. CONSTANTS, ENUMS & COMPATIBILITY ALIASES
// =============================================================================

pub const Id = u32;
pub const Font = style_mod.Font;
pub const MAX_WIDTHS: usize = 16;
pub const MAX_FMT: usize = 127;
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

// Aliases tương thích ngược với API gốc
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

pub const MU_MAX_WIDTHS = MAX_WIDTHS;
pub const MU_MAX_FMT = MAX_FMT;
pub const MU_SLIDER_FMT = SLIDER_FMT;

// =============================================================================
// 2. CORE LAYOUT & CONTAINER TYPES
// =============================================================================

/// Trạng thái bố cục của một hàng hoặc vùng chứa hiện tại.
pub const Layout = struct {
    body: math.Rect = .{},
    next: math.Rect = .{},
    position: math.Vec2 = .{},
    size: math.Vec2 = .{},
    max: math.Vec2 = .{},
    widths: [MAX_WIDTHS]i32 = [_]i32{0} ** MAX_WIDTHS,
    items: i32 = 0,
    item_index: i32 = 0,
    next_row: i32 = 0,
    next_type: i32 = 0,
    indent: i32 = 0,
};

/// Phần tử lưu vết trong pool lưu trữ trạng thái tồn tại qua các frame.
pub const PoolItem = struct {
    id: Id = 0,
    last_update: i32 = 0,
};

/// Vùng chứa (Cửa sổ, Panel, Popup) quản lý chuỗi lệnh vẽ và vị trí cuộn.
pub const Container = struct {
    head: ?*command_mod.Command = null,
    tail: ?*command_mod.Command = null,
    rect: math.Rect = .{},
    body: math.Rect = .{},
    content_size: math.Vec2 = .{},
    scroll: math.Vec2 = .{},
    zindex: i32 = 0,
    open: i32 = 0,
};

// =============================================================================
// 3. TEXT & NUMERIC FORMATTING HELPERS
// =============================================================================

/// Định dạng số thực (f32) thành chuỗi kết thúc bằng null theo định dạng printf (ví dụ: "%.2f", "%.0f").
fn formatReal(buf: []u8, fmt: [*c]const u8, val: f32) [:0]const u8 {
    if (buf.len == 0) return "";
    const span = if (fmt != null) std.mem.span(fmt) else "";
    var precision: ?usize = null;
    if (std.mem.indexOfScalar(u8, span, '.')) |dot_idx| {
        var p: usize = 0;
        var i = dot_idx + 1;
        while (i < span.len and std.ascii.isDigit(span[i])) : (i += 1) {
            p = p * 10 + (span[i] - '0');
        }
        if (i > dot_idx + 1) {
            precision = p;
        }
    }
    if (precision) |prec| {
        return switch (prec) {
            0 => std.fmt.bufPrintSentinel(buf, "{d:.0}", .{val}, 0) catch "",
            1 => std.fmt.bufPrintSentinel(buf, "{d:.1}", .{val}, 0) catch "",
            2 => std.fmt.bufPrintSentinel(buf, "{d:.2}", .{val}, 0) catch "",
            3 => std.fmt.bufPrintSentinel(buf, "{d:.3}", .{val}, 0) catch "",
            4 => std.fmt.bufPrintSentinel(buf, "{d:.4}", .{val}, 0) catch "",
            5 => std.fmt.bufPrintSentinel(buf, "{d:.5}", .{val}, 0) catch "",
            else => std.fmt.bufPrintSentinel(buf, "{d:.2}", .{val}, 0) catch "",
        };
    } else {
        return std.fmt.bufPrintSentinel(buf, "{d}", .{val}, 0) catch "";
    }
}

// =============================================================================
// 4. MICRON UI CONTEXT STRUCT
// =============================================================================

/// Đối tượng trung tâm quản lý toàn bộ trạng thái vòng lặp giao diện MicroUI.
pub const MicroUI = struct {
    pub const Rect = math.Rect;
    pub const Vec2 = math.Vec2;
    pub const Style = style_mod.Style;
    pub const Color = style_mod.Color;
    pub const ColorId = style_mod.ColorId;

    pub const COLOR_TEXT = style_mod.COLOR_TEXT;
    pub const COLOR_BORDER = style_mod.COLOR_BORDER;
    pub const COLOR_WINDOWBG = style_mod.COLOR_WINDOWBG;
    pub const COLOR_TITLEBG = style_mod.COLOR_TITLEBG;
    pub const COLOR_TITLETEXT = style_mod.COLOR_TITLETEXT;
    pub const COLOR_PANELBG = style_mod.COLOR_PANELBG;
    pub const COLOR_BUTTON = style_mod.COLOR_BUTTON;
    pub const COLOR_BUTTONHOVER = style_mod.COLOR_BUTTONHOVER;
    pub const COLOR_BUTTONFOCUS = style_mod.COLOR_BUTTONFOCUS;
    pub const COLOR_BASE = style_mod.COLOR_BASE;
    pub const COLOR_BASEHOVER = style_mod.COLOR_BASEHOVER;
    pub const COLOR_BASEFOCUS = style_mod.COLOR_BASEFOCUS;
    pub const COLOR_SCROLLBASE = style_mod.COLOR_SCROLLBASE;
    pub const COLOR_SCROLLTHUMB = style_mod.COLOR_SCROLLTHUMB;

    pub const TextWidthFn = *const fn (font: Font, text: [*c]const u8, len: c_int) callconv(.c) c_int;
    pub const TextHeightFn = *const fn (font: Font) callconv(.c) c_int;

    // 4.1 State Fields & Stacks
    style: Style = style_mod.default_style,
    text_width: ?TextWidthFn = null,
    text_height: ?TextHeightFn = null,

    hover: Id = 0,
    focus: Id = 0,
    last_id: Id = 0,
    last_rect: math.Rect = .{},

    id_stack: stack.BuildStack(Id, 32) = .{},
    clip_stack: stack.BuildStack(math.Rect, 32) = .{},
    layout_stack: stack.BuildStack(Layout, 16) = .{},
    container_stack: stack.BuildStack(*Container, 32) = .{},
    root_list: stack.BuildStack(*Container, 32) = .{},
    hover_root: ?*Container = null,
    next_hover_root: ?*Container = null,
    scroll_target: ?*Container = null,

    container_pool: [48]PoolItem = [_]PoolItem{.{}} ** 48,
    containers: [48]Container = [_]Container{.{}} ** 48,
    treenode_pool: [48]PoolItem = [_]PoolItem{.{}} ** 48,

    mouse_pos: math.Vec2 = .{},
    last_mouse_pos: math.Vec2 = .{},
    mouse_delta: math.Vec2 = .{},
    scroll_delta: math.Vec2 = .{},
    mouse_down: i32 = 0,
    mouse_pressed: i32 = 0,
    key_down: i32 = 0,
    key_pressed: i32 = 0,
    input_text: [32:0]u8 = [_:0]u8{0} ** 32,

    number_edit: Id = 0,
    number_edit_buf: [MAX_FMT:0]u8 = [_:0]u8{0} ** MAX_FMT,

    last_zindex: i32 = 0,
    updated_focus: bool = false,
    frame: i32 = 0,

    command_list: command_mod.CommandList = undefined,

    // =========================================================================
    // 4.2 Lifecycle Management
    // =========================================================================

    /// Lấy con trỏ tham chiếu đến cấu hình Style giao diện hiện tại.
    pub fn getStyle(self: *MicroUI) *Style {
        return &self.style;
    }

    /// Khởi tạo instance MicroUI thuần Zig.
    pub fn init(
        allocator: std.mem.Allocator,
        text_width: TextWidthFn,
        text_height: TextHeightFn,
    ) !MicroUI {
        const command_list = try command_mod.CommandList.init(allocator);
        errdefer command_list.deinit(allocator);

        return .{
            .text_width = text_width,
            .text_height = text_height,
            .command_list = command_list,
        };
    }

    /// Hủy instance MicroUI và giải phóng tài nguyên buffer lệnh.
    pub fn deinit(self: *MicroUI, allocator: std.mem.Allocator) void {
        self.command_list.deinit(allocator);
    }

    // =========================================================================
    // 4.3 Command Buffer API
    // =========================================================================

    /// Xóa toàn bộ lệnh vẽ trong buffer.
    pub fn clearCommandList(self: *MicroUI) void {
        self.command_list.clear();
    }

    /// Đẩy một lệnh vẽ hình chữ nhật vào danh sách lệnh.
    pub fn pushRect(self: *MicroUI, draw_rect: math.Rect, color: Color) void {
        _ = self.command_list.pushRect(draw_rect, color) catch unreachable;
    }

    /// Đẩy một lệnh vẽ biểu tượng vào danh sách lệnh.
    pub fn pushIcon(self: *MicroUI, id: i32, draw_rect: math.Rect, color: Color) void {
        _ = self.command_list.pushIcon(id, draw_rect, color) catch unreachable;
    }

    /// Đẩy một lệnh cắt khung nhìn (clipping) vào danh sách lệnh.
    pub fn pushClip(self: *MicroUI, r: math.Rect) void {
        _ = self.command_list.pushClip(r) catch unreachable;
    }

    /// Đẩy một lệnh vẽ văn bản vào danh sách lệnh.
    pub fn pushText(
        self: *MicroUI,
        text: []const u8,
        pos: math.Vec2,
        color: Color,
        font: Font,
    ) void {
        _ = self.command_list.pushText(text, pos, color, font) catch unreachable;
    }

    /// Lấy con trỏ đến lệnh đầu tiên trong danh sách lệnh.
    pub fn getBegin(self: *MicroUI) ?*command_mod.Command {
        return self.command_list.getBegin();
    }

    /// Lấy con trỏ đến lệnh cuối cùng trong danh sách lệnh.
    pub fn getEnd(self: *MicroUI) ?*command_mod.Command {
        return self.command_list.getEnd();
    }

    /// Duyệt lệnh vẽ tiếp theo trong command buffer (Iterator).
    pub fn nextCommand(self: *MicroUI, cmd: *?*command_mod.Command) bool {
        return self.command_list.getNextCommand(cmd);
    }

    // =========================================================================
    // 4.4 Frame Lifecycle
    // =========================================================================

    /// Bắt đầu một frame giao diện mới, chuẩn bị danh sách lệnh và cập nhật input.
    pub fn begin(self: *MicroUI) void {
        std.debug.assert(self.text_width != null and self.text_height != null);

        self.clearCommandList();
        self.root_list.clear();
        self.scroll_target = null;
        self.hover_root = self.next_hover_root;
        self.next_hover_root = null;
        self.mouse_delta.x = self.mouse_pos.x - self.last_mouse_pos.x;
        self.mouse_delta.y = self.mouse_pos.y - self.last_mouse_pos.y;
        self.frame += 1;
    }

    /// Hàm so sánh trật tự chiều sâu Z-Index giữa hai root container phục vụ thuật toán sắp xếp.
    fn compareContainersByZIndex(_: void, a: *Container, b: *Container) bool {
        return a.*.zindex < b.*.zindex;
    }

    /// Kết thúc frame giao diện hiện tại và liên kết chuỗi lệnh render của các root container theo Z-Index.
    pub fn end(self: *MicroUI) void {
        std.debug.assert(self.id_stack.idx == 0);
        std.debug.assert(self.clip_stack.idx == 0);
        std.debug.assert(self.layout_stack.idx == 0);
        std.debug.assert(self.container_stack.idx == 0);

        if (self.scroll_target) |st| {
            st.scroll.x += self.scroll_delta.x;
            st.scroll.y += self.scroll_delta.y;
        }

        if (!self.updated_focus) {
            self.focus = 0;
        }
        self.updated_focus = false;

        if (self.mouse_pressed != 0 and
            self.next_hover_root != null and
            self.next_hover_root.?.zindex < self.last_zindex and
            self.next_hover_root.?.zindex >= 0)
        {
            self.bringToFront(self.next_hover_root.?);
        }

        self.key_pressed = 0;
        self.input_text[0] = 0;
        self.mouse_pressed = 0;
        self.scroll_delta = .{ .x = 0, .y = 0 };
        self.last_mouse_pos = self.mouse_pos;

        const root_items = self.root_list.getSlice();
        if (root_items.len > 0) {
            std.mem.sort(*Container, root_items, {}, compareContainersByZIndex);
            self.command_list.begin.?.jump.dst = root_items[0].head.?.base.next;
            for (root_items[1..], 0..) |cnt, i| {
                root_items[i].tail.?.jump.dst = cnt.head.?.base.next;
            }
            root_items[root_items.len - 1].tail.?.jump.dst = null;
        }
    }

    // =========================================================================
    // 4.5 Event & Input Handling
    // =========================================================================

    /// Cập nhật toạ độ con trỏ chuột.
    pub fn inputMousemove(self: *MicroUI, x: i32, y: i32) void {
        self.mouse_pos = math.vec2(x, y);
    }

    /// Ghi nhận sự kiện nhấn nút chuột.
    pub fn inputMousedown(self: *MicroUI, x: i32, y: i32, btn: i32) void {
        self.inputMousemove(x, y);
        self.mouse_down |= btn;
        self.mouse_pressed |= btn;
    }

    /// Ghi nhận sự kiện nhả nút chuột.
    pub fn inputMouseup(self: *MicroUI, x: i32, y: i32, btn: i32) void {
        self.inputMousemove(x, y);
        self.mouse_down &= ~btn;
    }

    /// Ghi nhận sự kiện cuộn con lăn chuột.
    pub fn inputScroll(self: *MicroUI, x: i32, y: i32) void {
        self.scroll_delta.x += x;
        self.scroll_delta.y += y;
    }

    /// Ghi nhận sự kiện nhấn phím bàn phím.
    pub fn inputKeydown(self: *MicroUI, key: i32) void {
        self.key_pressed |= key;
        self.key_down |= key;
    }

    /// Ghi nhận sự kiện nhả phím bàn phím.
    pub fn inputKeyup(self: *MicroUI, key: i32) void {
        self.key_down &= ~key;
    }

    /// Ghi nhận sự kiện nhập chuỗi ký tự UTF-8 (Text Input).
    pub fn inputText(self: *MicroUI, text: [*c]const u8) void {
        if (text == null) return;
        const span = std.mem.span(text);
        const input_buf = &self.input_text;
        const current_len = std.mem.sliceTo(input_buf, 0).len;
        const remaining = input_buf.len - 1 - current_len;
        const copy_len = @min(span.len, remaining);
        if (copy_len > 0) {
            @memcpy(input_buf[current_len..][0..copy_len], span[0..copy_len]);
            input_buf[current_len + copy_len] = 0;
        }
    }

    // =========================================================================
    // 4.6 Drawing Primitives & Clipping
    // =========================================================================

    /// Kiểm tra trạng thái cắt clip của hình chữ nhật `r` so với vùng clip hiện tại.
    pub fn checkClip(self: *MicroUI, r: math.Rect) i32 {
        const cr = self.clip_stack.getValue();
        if (r.x > cr.x + cr.w or r.x + r.w < cr.x or r.y > cr.y + cr.h or r.y + r.h < cr.y) {
            return Clip.ALL;
        }
        if (r.x >= cr.x and r.x + r.w <= cr.x + cr.w and r.y >= cr.y and r.y + r.h <= cr.y + cr.h) {
            return 0;
        }
        return Clip.PART;
    }

    /// Đẩy một vùng cắt mới vào ngăn xếp clip (giao thoa với vùng clip cũ).
    pub fn pushClipRect(self: *MicroUI, r: math.Rect) void {
        const last = self.clip_stack.getValue();
        self.clip_stack.push(r.intersect(last));
    }

    /// Vẽ một hình chữ nhật với màu tương ứng (có kiểm tra clip).
    pub fn drawRect(self: *MicroUI, r: math.Rect, col: Color) void {
        const draw_rect = r.intersect(self.clip_stack.getValue());
        if (draw_rect.w > 0 and draw_rect.h > 0) {
            self.pushRect(draw_rect, col);
        }
    }

    /// Vẽ khung nền và viền của control theo color_id.
    fn drawFrame(self: *MicroUI, r: math.Rect, color_id: i32) void {
        const style_ptr = self.getStyle();
        const colors = style_ptr.colors;
        self.drawRect(r, colors[@intCast(color_id)]);
        if (color_id == style_mod.COLOR_SCROLLBASE or color_id == style_mod.COLOR_SCROLLTHUMB or
            color_id == style_mod.COLOR_TITLEBG)
        {
            return;
        }
        const border_col = colors[style_mod.ColorId.border_idx];
        if (border_col.a != 0) {
            const b = r.expand(1);
            self.drawRect(math.rect(b.x + 1, b.y, b.w - 2, 1), border_col);
            self.drawRect(math.rect(b.x + 1, b.y + b.h - 1, b.w - 2, 1), border_col);
            self.drawRect(math.rect(b.x, b.y, 1, b.h), border_col);
            self.drawRect(math.rect(b.x + b.w - 1, b.y, 1, b.h), border_col);
        }
    }

    /// Vẽ biểu tượng (Icon) có kiểm tra clip.
    pub fn drawIcon(self: *MicroUI, id: i32, r: math.Rect, col: Color) void {
        const clipped = r.intersect(self.clip_stack.getValue());
        if (clipped.w > 0 and clipped.h > 0) {
            self.pushIcon(id, clipped, col);
        }
    }

    /// Vẽ văn bản với font, vị trí và màu chỉ định (tự động cắt clip một phần hoặc toàn bộ).
    pub fn drawTextEx(
        self: *MicroUI,
        font: Font,
        text: []const u8,
        pos: math.Vec2,
        col: Color,
    ) void {
        if (text.len == 0) return;
        const text_width = self.text_width.?(font, &text[0], @intCast(text.len));
        const text_height = self.text_height.?(font);
        const rect_val = math.rect(pos.x, pos.y, text_width, text_height);
        const clipped = self.checkClip(rect_val);
        if (clipped == Clip.ALL) {
            return;
        }
        if (clipped == Clip.PART) {
            self.pushClip(self.clip_stack.getValue());
        }
        self.pushText(text, pos, col, font);
        if (clipped != 0) {
            self.pushClip(math.rect(0, 0, 0x1000000, 0x1000000));
        }
    }

    /// Vẽ khung nền của widget điều khiển, tự động đổi màu khi hover hoặc focus.
    pub fn drawControlFrame(self: *MicroUI, id: Id, rect_val: math.Rect, color_id: i32, opt: i32) void {
        if ((opt & Opt.NOFRAME) != 0) {
            return;
        }
        var color_val = color_id;
        if (self.focus == id) {
            color_val += 2;
        } else if (self.hover == id) {
            color_val += 1;
        }
        self.drawFrame(rect_val, color_val);
    }

    /// Vẽ văn bản bên trong một widget điều khiển theo căn lề (trái, giữa, phải).
    pub fn drawControlText(self: *MicroUI, text: [*c]const u8, rect_val: math.Rect, color_id: i32, opt: i32) void {
        if (text == null) return;
        const style_ptr = self.getStyle();
        const font = style_ptr.font;
        const tw = self.text_width.?(font, text, -1);
        self.pushClipRect(rect_val);
        defer _ = self.clip_stack.pop();

        var pos: math.Vec2 = undefined;
        pos.y = rect_val.y + @divTrunc(rect_val.h - self.text_height.?(font), 2);
        if ((opt & Opt.ALIGNCENTER) != 0) {
            pos.x = rect_val.x + @divTrunc(rect_val.w - tw, 2);
        } else if ((opt & Opt.ALIGNRIGHT) != 0) {
            pos.x = rect_val.x + rect_val.w - tw - style_ptr.padding;
        } else {
            pos.x = rect_val.x + style_ptr.padding;
        }
        const col = style_ptr.colors[@intCast(color_id)];
        const span = std.mem.span(text);
        self.drawTextEx(font, span, pos, col);
    }

    // =========================================================================
    // 4.7 Control ID & Focus System
    // =========================================================================

    /// Băm dữ liệu định danh kết hợp với ID cha để tạo mã Id (FNV-1a 32-bit).
    pub fn getId(self: *MicroUI, data: ?*const anyopaque, size: usize) Id {
        const idx = self.id_stack.idx;
        var res: u32 = if (idx > 0) self.id_stack.getValue() else 2166136261;

        if (data) |p| {
            const bytes: [*]const u8 = @ptrCast(p);
            var i: usize = 0;
            while (i < size) : (i += 1) {
                res = (res ^ bytes[i]) *% 16777619;
            }
        }
        self.last_id = res;
        return res;
    }

    /// Đặt tiêu điểm nhập liệu (focus) cho widget có mã ID tương ứng.
    pub fn setFocus(self: *MicroUI, id: Id) void {
        self.focus = id;
        self.updated_focus = true;
    }

    /// Kiểm tra con trỏ chuột có đang lơ lửng (hover) trên hình chữ nhật `r` hay không.
    pub fn mouseOver(self: *MicroUI, r: math.Rect) bool {
        if (!r.overlapsVec2(self.mouse_pos) or
            !self.clip_stack.getValue().overlapsVec2(self.mouse_pos))
        {
            return false;
        }
        var i = self.container_stack.idx;
        while (i > 0) {
            i -= 1;
            const cnt = self.container_stack.items[i];
            if (self.hover_root) |hr| {
                if (cnt == hr) {
                    return true;
                }
            }
            if (cnt.*.head != null) {
                break;
            }
        }
        return false;
    }

    /// Cập nhật trạng thái hover và focus của widget theo tương tác chuột.
    pub fn updateControl(self: *MicroUI, id: Id, rect_val: math.Rect, opt: i32) void {
        const mouseover = self.mouseOver(rect_val);

        if (self.focus == id) {
            self.updated_focus = true;
        }
        if ((opt & Opt.NOINTERACT) != 0) {
            return;
        }
        if (mouseover and self.mouse_down == 0) {
            self.hover = id;
        }

        if (self.focus == id) {
            if (self.mouse_pressed != 0 and !mouseover) {
                self.setFocus(0);
            }
            if (self.mouse_down == 0 and (~opt & Opt.HOLDFOCUS) != 0) {
                self.setFocus(0);
            }
        }

        if (self.hover == id) {
            if (self.mouse_pressed != 0) {
                self.setFocus(id);
            } else if (!mouseover) {
                self.hover = 0;
            }
        }
    }

    // =========================================================================
    // 4.8 Layout Engine
    // =========================================================================

    /// Lấy con trỏ đến trạng thái layout hiện tại ở đỉnh stack.
    pub fn getLayout(self: *MicroUI) *Layout {
        return self.layout_stack.getPValue();
    }

    /// Đẩy một layout mới vào stack với vùng thân (body) và vị trí cuộn (scroll).
    pub fn pushLayout(self: *MicroUI, body: math.Rect, scroll: math.Vec2) void {
        var layout: Layout = .{};
        layout.body = math.rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h);
        layout.max = math.vec2(-0x1000000, -0x1000000);
        self.layout_stack.push(layout);
        self.layoutRow(&[_]i32{0}, 0);
    }

    /// Thiết lập cấu hình hàng layout với mảng độ rộng `widths` và chiều cao `height`.
    pub fn layoutRowEx(self: *MicroUI, items: i32, widths: ?[]const i32, height: i32) void {
        const layout = self.getLayout();
        if (widths) |w| {
            std.debug.assert(items <= MAX_WIDTHS);
            for (w, 0..) |width, i| {
                layout.*.widths[i] = width;
            }
        }
        layout.*.items = items;
        layout.*.item_index = 0;
        layout.*.position = math.vec2(layout.*.indent, layout.*.next_row);
        layout.*.size.y = height;
        layout.*.next_type = 0;
    }

    /// Thiết lập cấu hình hàng layout ngắn gọn.
    pub fn layoutRow(self: *MicroUI, widths: []const i32, height: i32) void {
        self.layoutRowEx(@intCast(widths.len), widths, height);
    }

    /// Đặt độ rộng cho widget kế tiếp trong hàng.
    pub fn layoutWidth(self: *MicroUI, width: i32) void {
        self.getLayout().*.size.x = width;
    }

    /// Đặt chiều cao cho hàng hiện tại.
    pub fn layoutHeight(self: *MicroUI, height: i32) void {
        self.getLayout().*.size.y = height;
    }

    /// Đặt vị trí và kích thước thủ công cho widget kế tiếp.
    pub fn layoutSetNext(self: *MicroUI, r: math.Rect, relative: bool) void {
        const layout = self.getLayout();
        layout.*.next = r;
        layout.*.next_type = if (relative) 1 else 2;
    }

    /// Tính toán toạ độ và kích thước cho widget kế tiếp theo cơ chế phân bổ layout.
    pub fn layoutNext(self: *MicroUI) math.Rect {
        const layout = self.getLayout();
        const style_ptr = self.getStyle();
        var res: math.Rect = .{};

        if (layout.*.next_type != 0) {
            const next_type = layout.*.next_type;
            layout.*.next_type = 0;
            res = layout.*.next;
            if (next_type == 2) {
                self.last_rect = res;
                return res;
            }
        } else {
            if (layout.*.item_index == layout.*.items) {
                self.layoutRowEx(layout.*.items, null, layout.*.size.y);
            }

            res.x = layout.*.position.x;
            res.y = layout.*.position.y;
            res.w = layout.*.items;
            res.h = layout.*.size.y;

            if (layout.*.items > 0) {
                res.w = layout.*.widths[@intCast(layout.*.item_index)];
            } else {
                res.w = layout.*.size.x;
            }

            if (res.w == 0) {
                res.w = style_ptr.size.x + style_ptr.padding * 2;
            }
            if (res.h == 0) {
                res.h = style_ptr.size.y + style_ptr.padding * 2;
            }
            if (res.w < 0) {
                res.w += layout.*.body.w - res.x + 1;
            }
            if (res.h < 0) {
                res.h += layout.*.body.h - res.y + 1;
            }

            layout.*.item_index += 1;
        }

        layout.*.position.x += res.w + style_ptr.spacing;
        layout.*.next_row = @max(layout.*.next_row, res.y + res.h + style_ptr.spacing);

        res.x += layout.*.body.x;
        res.y += layout.*.body.y;

        layout.*.max.x = @max(layout.*.max.x, res.x + res.w);
        layout.*.max.y = @max(layout.*.max.y, res.y + res.h);

        self.last_rect = res;
        return res;
    }

    /// Bắt đầu một cột con lồng nhau bên trong layout hàng hiện tại.
    pub fn layoutBeginColumn(self: *MicroUI) void {
        self.pushLayout(self.layoutNext(), math.vec2(0, 0));
    }

    /// Kết thúc cột con, cập nhật lại kích thước cho layout cha.
    pub fn layoutEndColumn(self: *MicroUI) void {
        const b = self.getLayout().*;
        _ = self.layout_stack.pop();
        const a = self.getLayout();
        a.*.position.x = @max(a.*.position.x, b.position.x + b.body.x - a.*.body.x);
        a.*.next_row = @max(a.*.next_row, b.next_row + b.body.y - a.*.body.y);
        a.*.max.x = @max(a.*.max.x, b.max.x);
        a.*.max.y = @max(a.*.max.y, b.max.y);
    }

    // =========================================================================
    // 4.9 Container & State Pool Management
    // =========================================================================

    /// Tra cứu vị trí phần tử trong pool theo ID.
    pub fn poolGet(_: *MicroUI, items: []PoolItem, id: Id) ?usize {
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            if (items[i].id == id) {
                return i;
            }
        }
        return null;
    }

    /// Cập nhật thời điểm sử dụng mới nhất cho phần tử trong pool.
    pub fn poolUpdate(self: *MicroUI, items: []PoolItem, idx: usize) void {
        items[idx].last_update = self.frame;
    }

    /// Khởi tạo hoặc tái sử dụng phần tử ít được dùng nhất (LRU) trong pool.
    pub fn poolInit(self: *MicroUI, items: []PoolItem, id: Id) usize {
        var f: i32 = self.frame;
        var n: usize = 0;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            if (items[i].last_update < f) {
                f = items[i].last_update;
                n = i;
            }
        }
        items[n].id = id;
        self.poolUpdate(items, n);
        return n;
    }

    /// Lấy hoặc tạo mới một Container theo ID.
    pub fn getContainer(self: *MicroUI, id: Id, opt: i32) ?*Container {
        const pool = &self.container_pool;
        var idx = self.poolGet(pool, id);
        if (idx) |val| {
            if (self.containers[val].open != 0 or (opt & Opt.CLOSED) == 0) {
                self.poolUpdate(pool, val);
            }
            return &self.containers[val];
        }
        if ((opt & Opt.CLOSED) != 0) {
            return null;
        }
        idx = self.poolInit(pool, id);
        const cnt = &self.containers[idx.?];
        cnt.* = .{};
        cnt.*.open = 1;
        self.bringToFront(cnt);
        return cnt;
    }

    /// Lấy con trỏ Container theo tên tiêu đề.
    pub fn getContainerByName(self: *MicroUI, name: [:0]const u8) ?*Container {
        const id = self.getId(name.ptr, name.len);
        return self.getContainer(id, 0);
    }

    /// Lấy container hiện tại đang được xử lý ở đỉnh stack.
    pub fn getCurrentContainer(self: *MicroUI) *Container {
        return self.container_stack.getValue();
    }

    /// Đẩy body của container vào layout và tính toán thanh cuộn.
    pub fn pushContainerBody(self: *MicroUI, cnt: *Container, body: math.Rect, opt: i32) void {
        var b = body;
        if ((opt & Opt.NOSCROLL) == 0) {
            self.scrollbars(cnt, &b);
        }
        self.pushLayout(b.expand(-self.getStyle().padding), cnt.*.scroll);
        cnt.*.body = b;
    }

    /// Đóng và đưa container hiện tại ra khỏi ngăn xếp xử lý.
    pub fn popContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        const layout = self.getLayout();
        cnt.*.content_size.x = layout.*.max.x - layout.*.body.x;
        cnt.*.content_size.y = layout.*.max.y - layout.*.body.y;
        _ = self.container_stack.pop();
        _ = self.layout_stack.pop();
        _ = self.id_stack.pop();
    }

    /// Đưa container lên lớp trên cùng (Z-Index cao nhất).
    pub fn bringToFront(self: *MicroUI, cnt: *Container) void {
        cnt.*.zindex = self.last_zindex + 1;
        self.last_zindex += 1;
    }

    // =========================================================================
    // 4.10 Scrollbar System
    // =========================================================================

    pub const ScrollbarAxis = enum {
        vertical,
        horizontal,
    };

    /// Xử lý logic tính toán và vẽ thanh cuộn theo một trục (dọc hoặc ngang).
    pub fn scrollbar(
        self: *MicroUI,
        cnt: *Container,
        body: *math.Rect,
        cs: math.Vec2,
        axis: ScrollbarAxis,
    ) void {
        const style_ptr = self.getStyle();
        const sz = style_ptr.scrollbar_size;
        switch (axis) {
            .vertical => {
                const maxscroll = cs.y - body.h;
                if (maxscroll > 0 and body.h > 0) {
                    const id = self.getId("!scrollbary", 11);
                    var base = body.*;
                    base.x = body.x + body.w;
                    base.w = sz;

                    self.updateControl(id, base, 0);
                    if (self.focus == id and self.mouse_down == Mouse.LEFT) {
                        cnt.scroll.y += @divTrunc(self.mouse_delta.y * cs.y, base.h);
                    }
                    cnt.scroll.y = std.math.clamp(cnt.scroll.y, 0, maxscroll);

                    self.drawFrame(base, style_mod.COLOR_SCROLLBASE);

                    var thumb = base;
                    thumb.h = @max(style_ptr.thumb_size, @divTrunc(base.h * body.h, cs.y));
                    thumb.y += @divTrunc(cnt.scroll.y * (base.h - thumb.h), maxscroll);

                    self.drawFrame(thumb, style_mod.COLOR_SCROLLTHUMB);

                    if (self.mouseOver(body.*)) {
                        self.scroll_target = cnt;
                    }
                } else {
                    cnt.scroll.y = 0;
                }
            },
            .horizontal => {
                const maxscroll = cs.x - body.w;
                if (maxscroll > 0 and body.w > 0) {
                    const id = self.getId("!scrollbarx", 11);
                    var base = body.*;
                    base.y = body.y + body.h;
                    base.h = sz;

                    self.updateControl(id, base, 0);
                    if (self.focus == id and self.mouse_down == Mouse.LEFT) {
                        cnt.scroll.x += @divTrunc(self.mouse_delta.x * cs.x, base.w);
                    }
                    cnt.scroll.x = std.math.clamp(cnt.scroll.x, 0, maxscroll);

                    self.drawFrame(base, style_mod.COLOR_SCROLLBASE);

                    var thumb = base;
                    thumb.w = @max(style_ptr.thumb_size, @divTrunc(base.w * body.w, cs.x));
                    thumb.x += @divTrunc(cnt.scroll.x * (base.w - thumb.w), maxscroll);

                    self.drawFrame(thumb, style_mod.COLOR_SCROLLTHUMB);

                    if (self.mouseOver(body.*)) {
                        self.scroll_target = cnt;
                    }
                } else {
                    cnt.scroll.x = 0;
                }
            },
        }
    }

    /// Tính toán và vẽ toàn bộ thanh cuộn (dọc + ngang) cho container.
    pub fn scrollbars(self: *MicroUI, cnt: *Container, body: *math.Rect) void {
        const style_ptr = self.getStyle();
        const sz = style_ptr.scrollbar_size;
        var content_size = cnt.*.content_size;
        content_size.x += style_ptr.padding * 2;
        content_size.y += style_ptr.padding * 2;
        self.pushClipRect(body.*);
        if (content_size.y > body.h) {
            body.w -= sz;
        }
        if (content_size.x > body.w) {
            body.h -= sz;
        }
        self.scrollbar(cnt, body, content_size, .vertical);
        self.scrollbar(cnt, body, content_size, .horizontal);
        _ = self.clip_stack.pop();
    }

    // =========================================================================
    // 4.11 Windows, Panels & Popups
    // =========================================================================

    /// Bắt đầu một root container (cửa sổ độc lập hoặc popup trên cùng).
    pub fn beginRootContainer(self: *MicroUI, cnt: *Container) void {
        self.container_stack.push(cnt);
        self.root_list.push(cnt);
        cnt.*.head = self.command_list.pushJump(null) catch unreachable;
        if (cnt.rect.overlapsVec2(self.mouse_pos) and
            (self.next_hover_root == null or cnt.*.zindex > self.next_hover_root.?.zindex))
        {
            self.next_hover_root = cnt;
        }
        self.clip_stack.push(math.rect(0, 0, 0x1000000, 0x1000000));
    }

    /// Kết thúc một root container.
    pub fn endRootContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        cnt.*.tail = self.command_list.pushJump(null) catch unreachable;
        cnt.*.head.?.jump.dst = self.command_list.getEnd();
        _ = self.clip_stack.pop();
        self.popContainer();
    }

    /// Bắt đầu một cửa sổ giao diện cơ bản.
    pub fn beginWindow(self: *MicroUI, title: [:0]const u8, rect_val: math.Rect) bool {
        return self.beginWindowEx(title, rect_val, 0);
    }

    /// Bắt đầu một cửa sổ giao diện kèm các tùy chọn cấu hình `Opt`.
    pub fn beginWindowEx(self: *MicroUI, title: [:0]const u8, rect_val: math.Rect, opt: i32) bool {
        const id = self.getId(title.ptr, title.len);
        const cnt = self.getContainer(id, opt);
        if (cnt == null or cnt.?.open == 0) {
            return false;
        }
        self.id_stack.push(id);
        if (cnt.?.rect.w == 0) {
            cnt.?.rect = rect_val;
        }
        self.beginRootContainer(cnt.?);
        var body = cnt.?.rect;
        if (~opt & Opt.NOFRAME != 0) {
            self.drawFrame(body, style_mod.COLOR_WINDOWBG);
        }
        if (~opt & Opt.NOTITLE != 0) {
            var tr = math.rect(
                body.x,
                body.y,
                body.w,
                self.getStyle().title_height,
            );
            self.drawFrame(tr, style_mod.COLOR_TITLEBG);

            // Xử lý kéo thả cửa sổ bằng thanh tiêu đề
            {
                const title_id = self.getId("!title", 6);
                self.updateControl(title_id, tr, opt);
                self.drawControlText(title, tr, style_mod.COLOR_TITLETEXT, opt);
                if (title_id == self.focus and self.mouse_down == Mouse.LEFT) {
                    cnt.?.rect.x += self.mouse_delta.x;
                    cnt.?.rect.y += self.mouse_delta.y;
                }
                body.y += tr.h;
                body.h -= tr.h;
            }

            // Xử lý nút đóng cửa sổ
            if (~opt & Opt.NOCLOSE != 0) {
                const close_id = self.getId("!close", 6);
                const close_rect = math.rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h);
                tr.w -= close_rect.w;
                self.drawIcon(Icon.CLOSE, close_rect, self.getStyle().colors[style_mod.ColorId.title_text_idx]);
                self.updateControl(close_id, close_rect, opt);
                if (self.mouse_pressed == Mouse.LEFT and close_id == self.focus) {
                    cnt.?.open = 0;
                }
            }
        }
        self.pushContainerBody(cnt.?, body, opt);

        // Xử lý thay đổi kích thước cửa sổ
        if (~opt & Opt.NORESIZE != 0) {
            const size = self.getStyle().title_height;
            const resize_id = self.getId("!resize", 7);
            const resize_rect = math.rect(
                body.x + body.w - size,
                body.y + body.h - size,
                size,
                size,
            );
            self.updateControl(resize_id, resize_rect, opt);
            if (resize_id == self.focus and self.mouse_down == Mouse.LEFT) {
                cnt.?.rect.w = @max(96, cnt.?.rect.w + self.mouse_delta.x);
                cnt.?.rect.h = @max(64, cnt.?.rect.h + self.mouse_delta.y);
            }
        }

        // Tự động khớp kích thước theo nội dung bên trong
        if (opt & Opt.AUTOSIZE != 0) {
            const r = self.getLayout().*.body;
            cnt.?.rect.w = cnt.?.content_size.x + (cnt.?.rect.w - r.w);
            cnt.?.rect.h = cnt.?.content_size.y + (cnt.?.rect.h - r.h);
        }

        // Đóng popup khi nhấn ra bên ngoài
        if (opt & Opt.POPUP != 0 and
            self.mouse_pressed != 0 and
            self.hover_root != cnt)
        {
            cnt.?.open = 0;
        }

        self.pushClipRect(cnt.?.body);
        return true;
    }

    /// Kết thúc cửa sổ giao diện.
    pub fn endWindow(self: *MicroUI) void {
        _ = self.clip_stack.pop();
        self.endRootContainer();
    }

    /// Bắt đầu một bảng con (Panel).
    pub fn beginPanel(self: *MicroUI, name: [:0]const u8) void {
        self.beginPanelEx(name, 0);
    }

    /// Bắt đầu một bảng con kèm tùy chọn `Opt`.
    pub fn beginPanelEx(self: *MicroUI, name: [:0]const u8, opt: i32) void {
        const id = self.getId(name.ptr, name.len);
        self.id_stack.push(id);
        const cnt = self.getContainer(self.last_id, opt) orelse return;
        const tmp = self.layoutNext();
        cnt.*.rect = tmp;
        if (~opt & Opt.NOFRAME != 0) {
            self.drawFrame(tmp, style_mod.COLOR_PANELBG);
        }
        self.container_stack.push(cnt);
        self.pushContainerBody(cnt, tmp, opt);
        self.pushClipRect(cnt.*.body);
    }

    /// Kết thúc bảng con.
    pub fn endPanel(self: *MicroUI) void {
        _ = self.clip_stack.pop();
        self.popContainer();
    }

    /// Mở một cửa sổ popup tại vị trí chuột hiện tại.
    pub fn openPopup(self: *MicroUI, name: [:0]const u8) void {
        const cnt = self.getContainerByName(name) orelse return;
        self.hover_root = cnt;
        self.next_hover_root = cnt;
        cnt.*.rect = math.rect(self.mouse_pos.x, self.mouse_pos.y, 1, 1);
        cnt.*.open = 1;
        self.bringToFront(cnt);
    }

    /// Bắt đầu render nội dung của popup đã được mở.
    pub fn beginPopup(self: *MicroUI, name: [:0]const u8) i32 {
        const opt = Opt.POPUP | Opt.AUTOSIZE | Opt.NORESIZE |
            Opt.NOSCROLL | Opt.NOTITLE | Opt.CLOSED;
        return if (self.beginWindowEx(name, math.rect(0, 0, 0, 0), opt)) Res.ACTIVE else 0;
    }

    /// Kết thúc popup.
    pub fn endPopup(self: *MicroUI) void {
        self.endWindow();
    }

    // =========================================================================
    // 4.12 Tree Nodes & Collapsible Headers
    // =========================================================================

    /// Vẽ một thanh tiêu đề thu gọn/mở rộng (Header).
    pub fn header(self: *MicroUI, label: [:0]const u8) i32 {
        return self.headerEx(label, 0);
    }

    /// Vẽ thanh tiêu đề kèm tùy chọn `Opt` (ví dụ: Opt.EXPANDED).
    pub fn headerEx(self: *MicroUI, label: [:0]const u8, opt: i32) i32 {
        return self.headerInternal(label, false, opt);
    }

    /// Hàm xử lý chung logic đóng mở và tương tác cho Header và TreeNode.
    fn headerInternal(self: *MicroUI, label: [:0]const u8, is_treenode: bool, opt: i32) i32 {
        const id = self.getId(label.ptr, label.len);
        const pool = &self.treenode_pool;
        const opt_idx = self.poolGet(pool, id);
        self.layoutRow(&[_]i32{-1}, 0);

        var active = (opt_idx != null);
        const expanded = if ((opt & Opt.EXPANDED) != 0) !active else active;
        var r = self.layoutNext();
        self.updateControl(id, r, 0);

        if (self.mouse_pressed == Mouse.LEFT and self.focus == id) {
            active = !active;
        }

        if (opt_idx) |idx| {
            if (active) {
                self.poolUpdate(pool, idx);
            } else {
                pool[idx] = .{};
            }
        } else if (active) {
            _ = self.poolInit(pool, id);
        }

        if (is_treenode) {
            if (self.hover == id) {
                self.drawFrame(r, style_mod.COLOR_BUTTONHOVER);
            }
        } else {
            self.drawControlFrame(id, r, style_mod.COLOR_BUTTON, 0);
        }

        const icon_id: i32 = if (expanded) Icon.EXPANDED else Icon.COLLAPSED;
        const colors = self.getStyle().colors;
        self.drawIcon(icon_id, math.rect(r.x, r.y, r.h, r.h), colors[style_mod.ColorId.text_idx]);
        r.x += r.h - self.getStyle().padding;
        r.w -= r.h - self.getStyle().padding;
        self.drawControlText(label.ptr, r, style_mod.COLOR_TEXT, 0);

        return if (expanded) Res.ACTIVE else 0;
    }

    /// Bắt đầu một nút dạng cây (TreeNode).
    pub fn beginTreenode(self: *MicroUI, name: [:0]const u8) i32 {
        return self.beginTreenodeEx(name, 0);
    }

    /// Bắt đầu nút dạng cây kèm tùy chọn `Opt`.
    pub fn beginTreenodeEx(self: *MicroUI, label: [:0]const u8, opt: i32) i32 {
        const res = self.headerInternal(label, true, opt);
        if ((res & Res.ACTIVE) != 0) {
            self.getLayout().*.indent += self.getStyle().indent;
            self.id_stack.push(self.last_id);
        }
        return res;
    }

    /// Kết thúc nút dạng cây, thu hồi thụt lề layout.
    pub fn endTreenode(self: *MicroUI) void {
        self.getLayout().*.indent -= self.getStyle().indent;
        _ = self.id_stack.pop();
    }

    // =========================================================================
    // 4.13 Widget Library
    // =========================================================================

    /// Vẽ nhãn văn bản (Label) một dòng.
    pub fn drawLabel(self: *MicroUI, label: [:0]const u8) void {
        self.drawControlText(label.ptr, self.layoutNext(), style_mod.COLOR_TEXT, 0);
    }

    /// Vẽ đoạn văn bản nhiều dòng tự động xuống hàng theo từ (Word Wrapping).
    pub fn drawText(self: *MicroUI, text: []const u8) void {
        self.layoutBeginColumn();
        defer self.layoutEndColumn();
        if (text.len == 0) return;

        const font = self.getStyle().font;
        self.layoutRow(&[_]i32{-1}, self.text_height.?(font));
        const color_val = self.getStyle().colors[style_mod.ColorId.text_idx];

        var p: usize = 0;
        while (p < text.len) {
            const rect_val = self.layoutNext();
            var w: i32 = 0;
            const line_start = p;
            var line_end = p;
            while (p < text.len) {
                const word_start = p;
                while (p < text.len and text[p] != ' ' and text[p] != '\n') {
                    p += 1;
                }
                const word_len = p - word_start;
                if (word_len > 0) {
                    w += self.text_width.?(font, @ptrCast(&text[word_start]), @intCast(word_len));
                }
                if (w > rect_val.w and line_end != line_start) {
                    p = word_start;
                    break;
                }
                if (p < text.len) {
                    const sep = text[p];
                    w += self.text_width.?(font, @ptrCast(&text[p]), 1);
                    line_end = p;
                    p += 1;
                    if (sep == '\n') break;
                } else {
                    line_end = p;
                }
            }
            if (line_end > line_start) {
                self.drawTextEx(font, text[line_start..line_end], math.vec2(rect_val.x, rect_val.y), color_val);
            }
        }
    }

    /// Vẽ nút nhấn đơn giản (Button).
    pub fn button(self: *MicroUI, label: [:0]const u8) i32 {
        return self.buttonEx(label, 0, Opt.ALIGNCENTER);
    }

    /// Vẽ nút nhấn kèm biểu tượng hoặc tùy chọn căn lề.
    pub fn buttonEx(self: *MicroUI, label: ?[:0]const u8, icon: i32, opt: i32) i32 {
        var res: i32 = 0;
        const id = if (label) |l|
            self.getId(l.ptr, l.len)
        else
            self.getId(&icon, @sizeOf(i32));
        const r = self.layoutNext();
        self.updateControl(id, r, opt);
        if (self.mouse_pressed == Mouse.LEFT and self.focus == id) {
            res |= Res.SUBMIT;
        }
        self.drawControlFrame(id, r, style_mod.COLOR_BUTTON, opt);
        if (label) |l| {
            self.drawControlText(l.ptr, r, style_mod.COLOR_TEXT, opt);
        }
        if (icon != 0) {
            self.drawIcon(icon, r, self.getStyle().colors[style_mod.ColorId.text_idx]);
        }
        return res;
    }

    /// Vẽ hộp kiểm tra (CheckBox).
    pub fn checkBox(self: *MicroUI, label: [:0]const u8, value: *i32) i32 {
        var res: i32 = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf(*i32));
        const r = self.layoutNext();
        const box = math.rect(r.x, r.y, r.h, r.h);
        self.updateControl(id, r, 0);
        if (self.mouse_pressed == Mouse.LEFT and self.focus == id) {
            res |= Res.CHANGE;
            value.* = if (value.* != 0) 0 else 1;
        }
        self.drawControlFrame(id, box, style_mod.COLOR_BASE, 0);
        if (value.* != 0) {
            self.drawIcon(Icon.CHECK, box, self.getStyle().colors[style_mod.ColorId.text_idx]);
        }
        const text_rect = math.rect(r.x + box.w, r.y, r.w - box.w, r.h);
        self.drawControlText(label.ptr, text_rect, style_mod.COLOR_TEXT, 0);
        return res;
    }

    /// Vẽ ô nhập văn bản (TextBox).
    pub fn textBox(self: *MicroUI, text: [*c]u8, len: i32) i32 {
        return self.textBoxEx(text, len, 0);
    }

    /// Vẽ ô nhập văn bản kèm tùy chọn cấu hình `Opt`.
    pub fn textBoxEx(self: *MicroUI, text: [*c]u8, len: i32, opt: i32) i32 {
        const addr = @intFromPtr(text);
        const id = self.getId(@ptrCast(&addr), @sizeOf(usize));
        const rect_val = self.layoutNext();
        return self.textBoxRaw(text, len, id, rect_val, opt);
    }

    /// Xử lý logic cấp thấp của ô nhập văn bản (con trỏ nhấp nháy, chỉnh sửa UTF-8, Enter submit).
    pub fn textBoxRaw(self: *MicroUI, buf: [*c]u8, bufsz: i32, id: Id, rect_val: math.Rect, opt: i32) i32 {
        var res: i32 = 0;
        self.updateControl(id, rect_val, opt | Opt.HOLDFOCUS);

        if (self.focus == id) {
            // Xử lý text input
            var len: usize = std.mem.len(buf);
            const input_slice = std.mem.sliceTo(&self.input_text, 0);
            if (bufsz > @as(i32, @intCast(len)) + 1) {
                const avail: usize = @intCast(bufsz - @as(i32, @intCast(len)) - 1);
                const n = @min(avail, input_slice.len);
                if (n > 0) {
                    @memcpy(buf[len .. len + n], input_slice[0..n]);
                    len += n;
                    buf[len] = 0;
                    res |= Res.CHANGE;
                }
            }

            // Xử lý backspace (hỗ trợ xóa đa byte UTF-8)
            if ((self.key_pressed & Key.BACKSPACE) != 0 and len > 0) {
                len -= 1;
                while (len > 0 and (buf[len] & 0xc0) == 0x80) {
                    len -= 1;
                }
                buf[len] = 0;
                res |= Res.CHANGE;
            }

            // Xử lý phím Enter / Return
            if ((self.key_pressed & Key.RETURN) != 0) {
                self.setFocus(0);
                res |= Res.SUBMIT;
            }
        }

        // Vẽ widget
        self.drawControlFrame(id, rect_val, style_mod.COLOR_BASE, opt);
        if (self.focus == id) {
            const colors = self.getStyle().colors;
            const color_val = colors[style_mod.ColorId.text_idx];
            const font = self.getStyle().font;
            const text_span = std.mem.span(buf);
            const textw = if (self.text_width) |tw_fn|
                tw_fn(font, buf, @intCast(text_span.len))
            else
                0;
            const texth = if (self.text_height) |th_fn|
                th_fn(font)
            else
                0;
            const padding = self.getStyle().padding;
            const ofx = rect_val.w - padding - textw - 1;
            const textx = rect_val.x + @min(ofx, padding);
            const texty = rect_val.y + @divTrunc(rect_val.h - texth, 2);

            self.pushClipRect(rect_val);
            self.drawTextEx(font, text_span, .{ .x = textx, .y = texty }, color_val);
            self.drawRect(math.rect(textx + textw, texty, 1, texth), color_val);
            _ = self.clip_stack.pop();
        } else {
            self.drawControlText(buf, rect_val, style_mod.COLOR_TEXT, opt);
        }

        return res;
    }

    /// Hộp nhập số dạng popup khi người dùng Shift + Click chuột trái vào Slider hoặc Number.
    fn numberTextbox(self: *MicroUI, value: *f32, r: math.Rect, id: Id) bool {
        if (self.mouse_pressed == Mouse.LEFT and
            (self.key_down & Key.SHIFT) != 0 and
            self.hover == id)
        {
            self.number_edit = id;
            _ = std.fmt.bufPrintSentinel(&self.number_edit_buf, "{d:.3}", .{value.*}, 0) catch {
                self.number_edit_buf[0] = 0;
            };
        }
        if (self.number_edit == id) {
            const res = self.textBoxRaw(
                @ptrCast(&self.number_edit_buf),
                @sizeOf(@TypeOf(self.number_edit_buf)),
                id,
                r,
                0,
            );
            if ((res & Res.SUBMIT) != 0 or self.focus != id) {
                const str = std.mem.span(@as([*:0]const u8, @ptrCast(&self.number_edit_buf)));
                if (std.fmt.parseFloat(f32, std.mem.trim(u8, str, " \t\r\n"))) |parsed| {
                    value.* = parsed;
                } else |_| {}
                self.number_edit = 0;
            } else {
                return true;
            }
        }
        return false;
    }

    /// Thanh trượt giá trị số thực (Slider).
    pub fn slider(self: *MicroUI, value: *f32, low: f32, high: f32) i32 {
        return self.sliderEx(value, low, high, 0, SLIDER_FMT, Opt.ALIGNCENTER);
    }

    /// Thanh trượt kèm bước nhảy (step), chuỗi định dạng (fmt) và tùy chọn `Opt`.
    pub fn sliderEx(self: *MicroUI, value: *f32, low: f32, high: f32, step: f32, fmt: [*c]const u8, opt: i32) i32 {
        var buf: [MAX_FMT + 1]u8 = undefined;
        var res: i32 = 0;
        const last = value.*;
        var v = last;
        const id = self.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = self.layoutNext();

        if (self.numberTextbox(&v, base, id)) {
            return res;
        }

        self.updateControl(id, base, opt);

        if (self.focus == id and
            ((self.mouse_down | self.mouse_pressed) & Mouse.LEFT) != 0)
        {
            if (base.w > 0) {
                v = low + @as(f32, @floatFromInt(self.mouse_pos.x - base.x)) * (high - low) / @as(f32, @floatFromInt(base.w));
                if (step > 0) {
                    v = @round((v + step / 2.0) / step) * step;
                }
            }
        }

        v = std.math.clamp(v, low, high);
        value.* = v;
        if (last != v) {
            res |= Res.CHANGE;
        }

        self.drawControlFrame(id, base, style_mod.COLOR_BASE, opt);

        var thumb = base;
        const w = self.getStyle().thumb_size;
        thumb.w = w;
        const range = high - low;
        if (range > 0 and base.w > w) {
            thumb.x += @intFromFloat(@as(f32, @floatFromInt(base.w - w)) * (v - low) / range);
        }
        self.drawControlFrame(id, thumb, style_mod.COLOR_BUTTON, opt);

        const formatted = formatReal(&buf, fmt, value.*);
        self.drawControlText(formatted.ptr, base, style_mod.COLOR_TEXT, opt);

        return res;
    }

    /// Điều khiển chỉnh sửa số thực dạng kéo rê chuột (Number Drag).
    pub fn number(self: *MicroUI, value: *f32, step: f32) i32 {
        return self.numberEx(value, step, SLIDER_FMT, Opt.ALIGNCENTER);
    }

    /// Điều khiển chỉnh sửa số thực kéo rê chuột kèm định dạng và tùy chọn `Opt`.
    pub fn numberEx(self: *MicroUI, value: *f32, step: f32, fmt: [*c]const u8, opt: i32) i32 {
        var buf: [MAX_FMT + 1]u8 = undefined;
        var res: i32 = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = self.layoutNext();
        const last = value.*;

        if (self.numberTextbox(value, base, id)) {
            return res;
        }

        self.updateControl(id, base, opt);

        if (self.focus == id and (self.mouse_down & Mouse.LEFT) != 0) {
            value.* += @as(f32, @floatFromInt(self.mouse_delta.x)) * step;
        }

        if (value.* != last) {
            res |= Res.CHANGE;
        }

        self.drawControlFrame(id, base, style_mod.COLOR_BASE, opt);

        const formatted = formatReal(&buf, fmt, value.*);
        self.drawControlText(formatted.ptr, base, style_mod.COLOR_TEXT, opt);

        return res;
    }
};
