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
const container_mod = @import("container.zig");
const layout_mod = @import("layout.zig");
const Layout = layout_mod.Layout;
const pool_mod = @import("pool.zig");
const Pool = pool_mod.Pool;

const types_mod = @import("types.zig");
pub const types = types_mod;
pub const Id = types_mod.Id;
pub const Font = style_mod.Font;
pub const Opt = types_mod.Opt;
pub const Res = types_mod.Res;
pub const Mouse = types_mod.Mouse;
pub const Key = types_mod.Key;
pub const Icon = types_mod.Icon;
pub const Clip = types_mod.Clip;
pub const MAX_FMT = types_mod.MAX_FMT;
pub const SLIDER_FMT = types_mod.SLIDER_FMT;

// Aliases tương thích ngược với API gốc
pub const MU_CLIP_PART = types_mod.MU_CLIP_PART;
pub const MU_CLIP_ALL = types_mod.MU_CLIP_ALL;
pub const MU_OPT_ALIGNCENTER = types_mod.MU_OPT_ALIGNCENTER;
pub const MU_OPT_ALIGNRIGHT = types_mod.MU_OPT_ALIGNRIGHT;
pub const MU_OPT_NOINTERACT = types_mod.MU_OPT_NOINTERACT;
pub const MU_OPT_NOFRAME = types_mod.MU_OPT_NOFRAME;
pub const MU_OPT_NORESIZE = types_mod.MU_OPT_NORESIZE;
pub const MU_OPT_NOSCROLL = types_mod.MU_OPT_NOSCROLL;
pub const MU_OPT_NOCLOSE = types_mod.MU_OPT_NOCLOSE;
pub const MU_OPT_NOTITLE = types_mod.MU_OPT_NOTITLE;
pub const MU_OPT_HOLDFOCUS = types_mod.MU_OPT_HOLDFOCUS;
pub const MU_OPT_AUTOSIZE = types_mod.MU_OPT_AUTOSIZE;
pub const MU_OPT_POPUP = types_mod.MU_OPT_POPUP;
pub const MU_OPT_CLOSED = types_mod.MU_OPT_CLOSED;
pub const MU_OPT_EXPANDED = types_mod.MU_OPT_EXPANDED;
pub const MU_RES_ACTIVE = types_mod.MU_RES_ACTIVE;
pub const MU_RES_SUBMIT = types_mod.MU_RES_SUBMIT;
pub const MU_RES_CHANGE = types_mod.MU_RES_CHANGE;
pub const MU_MOUSE_LEFT = types_mod.MU_MOUSE_LEFT;
pub const MU_MOUSE_RIGHT = types_mod.MU_MOUSE_RIGHT;
pub const MU_MOUSE_MIDDLE = types_mod.MU_MOUSE_MIDDLE;
pub const MU_KEY_SHIFT = types_mod.MU_KEY_SHIFT;
pub const MU_KEY_CTRL = types_mod.MU_KEY_CTRL;
pub const MU_KEY_ALT = types_mod.MU_KEY_ALT;
pub const MU_KEY_BACKSPACE = types_mod.MU_KEY_BACKSPACE;
pub const MU_KEY_RETURN = types_mod.MU_KEY_RETURN;
pub const MU_ICON_CLOSE = types_mod.MU_ICON_CLOSE;
pub const MU_ICON_CHECK = types_mod.MU_ICON_CHECK;
pub const MU_ICON_COLLAPSED = types_mod.MU_ICON_COLLAPSED;
pub const MU_ICON_EXPANDED = types_mod.MU_ICON_EXPANDED;
pub const MU_MAX_FMT = types_mod.MU_MAX_FMT;
pub const MU_SLIDER_FMT = types_mod.MU_SLIDER_FMT;

const format_mod = @import("format.zig");
pub const formatReal = format_mod.formatReal;
const mouse_mod = @import("mouse_input.zig");
pub const MouseInput = mouse_mod.MouseInput;

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

    id_stack: stack.Stack(Id, 32) = .{},
    clip_stack: stack.Stack(math.Rect, 32) = .{},

    layout_manager: layout_mod.LayoutManager = .{},

    container_manager: container_mod.ContainerManager = .{},

    treenode_pool: Pool(48) = .{},

    mouse_input: MouseInput = .{},

    key_down: i32 = 0,
    key_pressed: i32 = 0,
    input_text: [32:0]u8 = [_:0]u8{0} ** 32,

    number_edit: Id = 0,
    number_edit_buf: [MAX_FMT:0]u8 = [_:0]u8{0} ** MAX_FMT,

    updated_focus: bool = false,
    frame: i32 = 0,

    command_list: command_mod.CommandList = undefined,

    // Container
    //
    /// Lấy container hiện tại đang được xử lý ở đỉnh stack.
    pub inline fn getCurrentContainer(self: *MicroUI) *container_mod.Container {
        return self.container_manager.getCurrent();
    }

    /// Bắt đầu một root container (cửa sổ độc lập hoặc popup trên cùng).
    pub fn beginRootContainer(self: *MicroUI, cnt: *container_mod.Container) !void {
        self.container_manager.pushRoot(cnt);
        cnt.*.head = try self.command_list.pushJump(null);
        if (self.mouse_input.overlaps(cnt.rect)) {
            self.container_manager.setNextHoverRoot(cnt);
        }
        self.clip_stack.push(math.rect(0, 0, 0x1000000, 0x1000000));
    }

    /// Đóng và đưa container hiện tại ra khỏi ngăn xếp xử lý.
    pub fn popContainer(self: *MicroUI) void {
        const cnt = self.container_manager.getCurrent();
        const layout = self.getLayout();
        cnt.*.content_size.x = layout.*.max.x - layout.*.body.x;
        cnt.*.content_size.y = layout.*.max.y - layout.*.body.y;
        _ = self.container_manager.pop();
        _ = self.layout_manager.pop();
        _ = self.id_stack.pop();
    }

    /// Bắt đầu một bảng con kèm tùy chọn `Opt`.
    pub fn beginPanelEx(self: *MicroUI, name: [:0]const u8, opt: i32) !void {
        const id = self.getId(name.ptr, name.len);
        self.id_stack.push(id);
        const cnt = self.getContainer(self.last_id, opt) orelse return;
        const tmp = self.layoutNext();
        cnt.*.rect = tmp;
        if (~opt & Opt.NOFRAME != 0) {
            try self.drawFrame(tmp, style_mod.COLOR_PANELBG);
        }
        self.container_manager.push(cnt);
        try self.pushContainerBody(cnt, tmp, opt);
        self.pushClipRect(cnt.*.body);
    }

    /// Kiểm tra con trỏ chuột có đang lơ lửng (hover) trên hình chữ nhật `r` hay không.
    pub inline fn mouseOver(self: *MicroUI, r: math.Rect) bool {
        if (!self.mouse_input.overlaps(r) or
            !self.mouse_input.overlaps(self.clip_stack.top()))
        {
            return false;
        }
        return self.container_manager.isActiveContainer();
    }

    /// Bắt đầu một frame giao diện mới, chuẩn bị danh sách lệnh và cập nhật input.
    pub fn begin(self: *MicroUI) void {
        self.command_list.clear();
        self.container_manager.begin();
        self.mouse_input.updateDelta();
        self.frame += 1;
    }

    /// Kết thúc frame giao diện hiện tại và liên kết chuỗi lệnh render của các root container theo Z-Index.
    pub fn end(self: *MicroUI) void {
        std.debug.assert(self.id_stack.isEmpty());
        std.debug.assert(self.clip_stack.isEmpty());
        std.debug.assert(self.layout_manager.isEmpty());

        self.container_manager.updateScroll(self.mouse_input.scroll_delta);
        if (!self.updated_focus) {
            self.focus = 0;
        }
        self.updated_focus = false;
        if (self.mouse_input.hasPressed()) {
            self.container_manager.bringHoverRootToFront();
        }

        self.key_pressed = 0;
        self.input_text[0] = 0;
        self.mouse_input.end();
        if (self.command_list.head) |head| {
            self.container_manager.updateRender(head);
        }
    }

    /// Mở một cửa sổ popup tại vị trí chuột hiện tại.
    pub fn openPopup(self: *MicroUI, name: [:0]const u8) void {
        const cnt = self.getContainerByName(name) orelse return;
        self.container_manager.setPopup(cnt);
        cnt.*.rect = math.rect(self.mouse_input.pos.x, self.mouse_input.pos.y, 1, 1);
        cnt.*.open = 1;
        self.bringToFront(cnt);
    }

    // =========================================================================
    // 4.2 Lifecycle Management
    // =========================================================================

    /// Lấy con trỏ tham chiếu đến cấu hình Style giao diện hiện tại.
    pub inline fn getStyle(self: *MicroUI) *Style {
        return &self.style;
    }

    /// Khởi tạo instance MicroUI thuần Zig.
    pub fn init(allocator: std.mem.Allocator, text_width: TextWidthFn, text_height: TextHeightFn) !MicroUI {
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

    /// Đẩy một lệnh vẽ hình chữ nhật vào danh sách lệnh.
    pub inline fn pushRect(self: *MicroUI, draw_rect: math.Rect, color: Color) !*command_mod.Command {
        return self.command_list.pushRect(draw_rect, color);
    }

    /// Đẩy một lệnh vẽ biểu tượng vào danh sách lệnh.
    pub inline fn pushIcon(self: *MicroUI, id: i32, draw_rect: math.Rect, color: Color) !*command_mod.Command {
        return self.command_list.pushIcon(id, draw_rect, color) catch unreachable;
    }

    /// Đẩy một lệnh cắt khung nhìn (clipping) vào danh sách lệnh.
    pub inline fn pushClip(self: *MicroUI, r: math.Rect) !*command_mod.Command {
        return self.command_list.pushClip(r);
    }

    /// Đẩy một lệnh vẽ văn bản vào danh sách lệnh.
    pub fn pushText(self: *MicroUI, text: []const u8, pos: math.Vec2, color: Color, font: Font) !*command_mod.Command {
        return self.command_list.pushText(text, pos, color, font) catch unreachable;
    }

    /// Lấy con trỏ đến lệnh đầu tiên trong danh sách lệnh.
    pub inline fn getBegin(self: *MicroUI) ?*command_mod.Command {
        return self.command_list.first();
    }

    /// Lấy con trỏ đến lệnh cuối cùng trong danh sách lệnh.
    pub inline fn getEnd(self: *MicroUI) ?*command_mod.Command {
        return self.command_list.last();
    }

    /// Duyệt lệnh vẽ tiếp theo trong command buffer (Iterator).
    pub fn nextCommand(self: *MicroUI, cmd: *?*command_mod.Command) bool {
        if (cmd.*) |tmp| {
            if (tmp != self.command_list.tail) {
                cmd.* = tmp.base.next;
            } else if (tmp.type != command_mod.Type.jump) {
                return false;
            }
        } else {
            cmd.* = self.command_list.head;
        }

        while (cmd.*) |tmp| : (cmd.* = tmp.jump.dst) {
            if (tmp.type != command_mod.Type.jump) {
                return cmd.* != null;
            }
        }
        return cmd.* != null;
    }

    pub inline fn getHeadCommand(self: *MicroUI) ?*command_mod.Command {
        return self.command_list.first();
    }

    // =========================================================================
    // 4.5 Event & Input Handling
    // =========================================================================

    /// Cập nhật toạ độ con trỏ chuột.
    pub inline fn inputMousemove(self: *MicroUI, x: i32, y: i32) void {
        self.mouse_input.move(x, y);
    }

    /// Ghi nhận sự kiện nhấn nút chuột.
    pub inline fn inputMousedown(self: *MicroUI, x: i32, y: i32, btn: i32) void {
        self.mouse_input.press(x, y, btn);
    }

    /// Ghi nhận sự kiện nhả nút chuột.
    pub inline fn inputMouseup(self: *MicroUI, x: i32, y: i32, btn: i32) void {
        self.mouse_input.release(x, y, btn);
    }

    /// Ghi nhận sự kiện cuộn con lăn chuột.
    pub inline fn inputScroll(self: *MicroUI, x: i32, y: i32) void {
        self.mouse_input.scroll(x, y);
    }

    /// Ghi nhận sự kiện nhấn phím bàn phím.
    pub inline fn inputKeydown(self: *MicroUI, key: i32) void {
        self.key_pressed |= key;
        self.key_down |= key;
    }

    /// Ghi nhận sự kiện nhả phím bàn phím.
    pub inline fn inputKeyup(self: *MicroUI, key: i32) void {
        self.key_down &= ~key;
    }

    /// Ghi nhận sự kiện nhập chuỗi ký tự UTF-8 (Text Input).
    pub fn inputText(self: *MicroUI, text: [*c]const u8) void {
        if (text == null) {
            return;
        }
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
        const cr = self.clip_stack.top();
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
        const last = self.clip_stack.top();
        self.clip_stack.push(r.intersect(last));
    }

    /// Vẽ một hình chữ nhật với màu tương ứng (có kiểm tra clip).
    pub fn drawRect(self: *MicroUI, r: math.Rect, col: Color) !void {
        const draw_rect = r.intersect(self.clip_stack.top());
        if (draw_rect.w > 0 and draw_rect.h > 0) {
            _ = try self.pushRect(draw_rect, col);
        }
    }

    /// Vẽ khung nền và viền của control theo color_id.
    fn drawFrame(self: *MicroUI, r: math.Rect, color_id: i32) !void {
        const style_ptr = self.getStyle();
        const colors = style_ptr.colors;
        _ = try self.drawRect(r, colors[@intCast(color_id)]);
        if (color_id == style_mod.COLOR_SCROLLBASE or color_id == style_mod.COLOR_SCROLLTHUMB or
            color_id == style_mod.COLOR_TITLEBG)
        {
            return;
        }
        const border_col = colors[style_mod.ColorId.border_idx];
        if (border_col.a != 0) {
            const b = r.expand(1);
            _ = try self.drawRect(math.rect(b.x + 1, b.y, b.w - 2, 1), border_col);
            _ = try self.drawRect(math.rect(b.x + 1, b.y + b.h - 1, b.w - 2, 1), border_col);
            _ = try self.drawRect(math.rect(b.x, b.y, 1, b.h), border_col);
            _ = try self.drawRect(math.rect(b.x + b.w - 1, b.y, 1, b.h), border_col);
        }
    }

    /// Vẽ biểu tượng (Icon) có kiểm tra clip.
    pub fn drawIcon(self: *MicroUI, id: i32, r: math.Rect, col: Color) !void {
        const clipped = r.intersect(self.clip_stack.top());
        if (clipped.w > 0 and clipped.h > 0) {
            _ = try self.pushIcon(id, clipped, col);
        }
    }

    /// Vẽ văn bản với font, vị trí và màu chỉ định (tự động cắt clip một phần hoặc toàn bộ).
    pub fn drawTextEx(self: *MicroUI, font: Font, text: []const u8, pos: math.Vec2, col: Color) !void {
        if (text.len == 0) return;
        const text_width = self.text_width.?(font, &text[0], @intCast(text.len));
        const text_height = self.text_height.?(font);
        const rect_val = math.rect(pos.x, pos.y, text_width, text_height);
        const clipped = self.checkClip(rect_val);
        if (clipped == Clip.ALL) {
            return;
        }
        if (clipped == Clip.PART) {
            _ = try self.pushClip(self.clip_stack.top());
        }
        _ = try self.pushText(text, pos, col, font);
        if (clipped != 0) {
            _ = try self.pushClip(math.rect(0, 0, 0x1000000, 0x1000000));
        }
    }

    /// Vẽ khung nền của widget điều khiển, tự động đổi màu khi hover hoặc focus.
    pub fn drawControlFrame(self: *MicroUI, id: Id, rect_val: math.Rect, color_id: i32, opt: i32) !void {
        if ((opt & Opt.NOFRAME) != 0) {
            return;
        }
        var color_val = color_id;
        if (self.focus == id) {
            color_val += 2;
        } else if (self.hover == id) {
            color_val += 1;
        }
        _ = try self.drawFrame(rect_val, color_val);
    }

    /// Vẽ văn bản bên trong một widget điều khiển theo căn lề (trái, giữa, phải).
    pub fn drawControlText(self: *MicroUI, text: [*c]const u8, rect_val: math.Rect, color_id: i32, opt: i32) !void {
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
        _ = try self.drawTextEx(font, span, pos, col);
    }

    // =========================================================================
    // 4.7 Control ID & Focus System
    // =========================================================================

    /// Băm dữ liệu định danh kết hợp với ID cha để tạo mã Id (FNV-1a 32-bit).
    pub fn getId(self: *MicroUI, data: ?*const anyopaque, size: usize) Id {
        const idx = self.id_stack.idx;
        var res: u32 = if (idx > 0) self.id_stack.top() else 2166136261;

        if (data) |p| {
            const bytes: [*]const u8 = @ptrCast(p);
            for (bytes[0..size]) |b| {
                res = (res ^ b) *% 16777619;
            }
        }
        self.last_id = res;
        return res;
    }

    /// Đặt tiêu điểm nhập liệu (focus) cho widget có mã ID tương ứng.
    pub inline fn setFocus(self: *MicroUI, id: Id) void {
        self.focus = id;
        self.updated_focus = true;
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
        if (mouseover and !self.mouse_input.hasDown()) {
            self.hover = id;
        }

        if (self.focus == id) {
            if (self.mouse_input.hasPressed() and !mouseover) {
                self.setFocus(0);
            }
            if (!self.mouse_input.hasDown() and (~opt & Opt.HOLDFOCUS) != 0) {
                self.setFocus(0);
            }
        }

        if (self.hover == id) {
            if (self.mouse_input.hasPressed()) {
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
    pub inline fn getLayout(self: *MicroUI) *Layout {
        return self.layout_manager.getCurrent();
    }

    /// Đẩy một layout mới vào stack với vùng thân (body) và vị trí cuộn (scroll).
    pub inline fn pushLayout(self: *MicroUI, body: math.Rect, scroll: math.Vec2) void {
        self.layout_manager.push(body, scroll);
    }

    /// Đặt độ rộng cho widget kế tiếp trong hàng.
    pub inline fn layoutWidth(self: *MicroUI, width: i32) void {
        self.getLayout().size.x = width;
    }

    /// Đặt chiều cao cho hàng hiện tại.
    pub inline fn layoutHeight(self: *MicroUI, height: i32) void {
        self.getLayout().size.y = height;
    }

    /// Đặt vị trí và kích thước thủ công cho widget kế tiếp.
    pub inline fn layoutSetNext(self: *MicroUI, r: math.Rect, relative: bool) void {
        self.layout_manager.setNext(r, relative);
    }

    /// Tính toán toạ độ và kích thước cho widget kế tiếp theo cơ chế phân bổ layout.
    pub inline fn layoutNext(self: *MicroUI) math.Rect {
        self.last_rect = self.layout_manager.getNext(self.getStyle());
        return self.last_rect;
    }

    /// Bắt đầu một cột con lồng nhau bên trong layout hàng hiện tại.
    pub inline fn layoutBeginColumn(self: *MicroUI) void {
        self.layout_manager.beginColumn(self.layoutNext());
    }

    /// Kết thúc cột con, cập nhật lại kích thước cho layout cha.
    pub inline fn layoutEndColumn(self: *MicroUI) void {
        self.layout_manager.endColumn();
    }

    pub inline fn setLayoutRow(self: *MicroUI, widths: []const i32, height: i32) void {
        self.layout_manager.setRow(widths, height);
    }

    // =========================================================================
    // 4.9 Container & State Pool Management
    // =========================================================================

    /// Lấy hoặc tạo mới một Container theo ID.
    pub inline fn getContainer(self: *MicroUI, id: Id, opt: i32) ?*container_mod.Container {
        return self.container_manager.getOrAlloc(id, opt, self.frame);
    }

    /// Lấy con trỏ Container theo tên tiêu đề.
    pub inline fn getContainerByName(self: *MicroUI, name: [:0]const u8) ?*container_mod.Container {
        const id = self.getId(name.ptr, name.len);
        return self.getContainer(id, 0);
    }

    /// Đẩy body của container vào layout và tính toán thanh cuộn.
    pub fn pushContainerBody(self: *MicroUI, cnt: *container_mod.Container, body: math.Rect, opt: i32) !void {
        var b = body;
        if ((opt & Opt.NOSCROLL) == 0) {
            try self.scrollbars(cnt, &b);
        }
        self.pushLayout(b.expand(-self.getStyle().padding), cnt.scroll);
        cnt.body = b;
    }

    /// Đưa container lên lớp trên cùng (Z-Index cao nhất).
    pub inline fn bringToFront(self: *MicroUI, cnt: *container_mod.Container) void {
        self.container_manager.bringToFront(cnt);
    }

    // =========================================================================
    // 4.10 Scrollbar System
    // =========================================================================

    pub const ScrollbarAxis = enum {
        vertical,
        horizontal,
    };

    /// Xử lý logic tính toán và vẽ thanh cuộn theo một trục (dọc hoặc ngang).
    pub fn scrollbar(self: *MicroUI, cnt: *container_mod.Container, body: *math.Rect, cs: math.Vec2, axis: ScrollbarAxis) !void {
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
                    if (self.focus == id and self.mouse_input.isDown(Mouse.LEFT)) {
                        cnt.scroll.y += @divTrunc(self.mouse_input.delta.y * cs.y, base.h);
                    }
                    cnt.scroll.y = std.math.clamp(cnt.scroll.y, 0, maxscroll);

                    _ = try self.drawFrame(base, style_mod.COLOR_SCROLLBASE);

                    var thumb = base;
                    thumb.h = @max(style_ptr.thumb_size, @divTrunc(base.h * body.h, cs.y));
                    thumb.y += @divTrunc(cnt.scroll.y * (base.h - thumb.h), maxscroll);

                    try self.drawFrame(thumb, style_mod.COLOR_SCROLLTHUMB);

                    if (self.mouseOver(body.*)) {
                        self.container_manager.setScrollTarget(cnt);
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
                    if (self.focus == id and self.mouse_input.isDown(Mouse.LEFT)) {
                        cnt.scroll.x += @divTrunc(self.mouse_input.delta.x * cs.x, base.w);
                    }
                    cnt.scroll.x = std.math.clamp(cnt.scroll.x, 0, maxscroll);

                    _ = try self.drawFrame(base, style_mod.COLOR_SCROLLBASE);

                    var thumb = base;
                    thumb.w = @max(style_ptr.thumb_size, @divTrunc(base.w * body.w, cs.x));
                    thumb.x += @divTrunc(cnt.scroll.x * (base.w - thumb.w), maxscroll);

                    _ = try self.drawFrame(thumb, style_mod.COLOR_SCROLLTHUMB);

                    if (self.mouseOver(body.*)) {
                        self.container_manager.setScrollTarget(cnt);
                    }
                } else {
                    cnt.scroll.x = 0;
                }
            },
        }
    }

    /// Tính toán và vẽ toàn bộ thanh cuộn (dọc + ngang) cho container.
    pub fn scrollbars(self: *MicroUI, cnt: *container_mod.Container, body: *math.Rect) !void {
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
        try self.scrollbar(cnt, body, content_size, .vertical);
        try self.scrollbar(cnt, body, content_size, .horizontal);
        _ = self.clip_stack.pop();
    }

    // =========================================================================
    // 4.11 Windows, Panels & Popups
    // =========================================================================

    /// Kết thúc một root container.
    pub fn endRootContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        cnt.*.tail = self.command_list.pushJump(null) catch |err| blk: {
            std.log.err("endRootContainer pushJump failed: {s}", .{@errorName(err)});
            break :blk null;
        };
        // head.jump.dst (bỏ qua nội dung khi root lồng trong root khác, vd. popup)
        // được trỏ tới lệnh ngay sau tail trong ContainerManager.updateRender().
        _ = self.clip_stack.pop();
        self.popContainer();
    }

    /// Bắt đầu một cửa sổ giao diện cơ bản.
    pub inline fn beginWindow(self: *MicroUI, title: [:0]const u8, rect_val: math.Rect) !bool {
        return self.beginWindowEx(title, rect_val, 0);
    }

    /// Bắt đầu một cửa sổ giao diện kèm các tùy chọn cấu hình `Opt`.
    pub fn beginWindowEx(self: *MicroUI, title: [:0]const u8, rect_val: math.Rect, opt: i32) !bool {
        const id = self.getId(title.ptr, title.len);
        const cnt = self.getContainer(id, opt) orelse return false;
        if (cnt.open == 0) {
            return false;
        }
        self.id_stack.push(id);
        if (cnt.rect.w == 0) {
            cnt.rect = rect_val;
        }
        try self.beginRootContainer(cnt);
        var body = cnt.rect;
        if (~opt & Opt.NOFRAME != 0) {
            try self.drawFrame(body, style_mod.COLOR_WINDOWBG);
        }
        if (~opt & Opt.NOTITLE != 0) {
            var tr = math.rect(
                body.x,
                body.y,
                body.w,
                self.getStyle().title_height,
            );
            try self.drawFrame(tr, style_mod.COLOR_TITLEBG);

            // Xử lý kéo thả cửa sổ bằng thanh tiêu đề
            {
                const title_id = self.getId("!title", 6);
                self.updateControl(title_id, tr, opt);
                try self.drawControlText(title, tr, style_mod.COLOR_TITLETEXT, opt);
                if (title_id == self.focus and self.mouse_input.isDown(Mouse.LEFT)) {
                    cnt.rect.x += self.mouse_input.delta.x;
                    cnt.rect.y += self.mouse_input.delta.y;
                }
                body.y += tr.h;
                body.h -= tr.h;
            }

            // Xử lý nút đóng cửa sổ
            if (~opt & Opt.NOCLOSE != 0) {
                const close_id = self.getId("!close", 6);
                const close_rect = math.rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h);
                tr.w -= close_rect.w;
                try self.drawIcon(Icon.CLOSE, close_rect, self.getStyle().colors[style_mod.ColorId.title_text_idx]);
                self.updateControl(close_id, close_rect, opt);
                if (self.mouse_input.isPressed(Mouse.LEFT) and close_id == self.focus) {
                    cnt.open = 0;
                }
            }
        }
        try self.pushContainerBody(cnt, body, opt);

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
            if (resize_id == self.focus and self.mouse_input.isDown(Mouse.LEFT)) {
                cnt.rect.w = @max(96, cnt.rect.w + self.mouse_input.delta.x);
                cnt.rect.h = @max(64, cnt.rect.h + self.mouse_input.delta.y);
            }
        }

        // Tự động khớp kích thước theo nội dung bên trong
        if (opt & Opt.AUTOSIZE != 0) {
            const r = self.getLayout().body;
            cnt.rect.w = cnt.content_size.x + (cnt.rect.w - r.w);
            cnt.rect.h = cnt.content_size.y + (cnt.rect.h - r.h);
        }

        // Đóng popup khi nhấn ra bên ngoài
        if (opt & Opt.POPUP != 0 and self.mouse_input.hasPressed() and
            !self.container_manager.isHoverRoot(cnt))
        {
            cnt.open = 0;
        }

        self.pushClipRect(cnt.body);
        return true;
    }

    /// Kết thúc cửa sổ giao diện.
    pub fn endWindow(self: *MicroUI) void {
        _ = self.clip_stack.pop();
        self.endRootContainer();
    }

    /// Bắt đầu một bảng con (Panel).
    pub inline fn beginPanel(self: *MicroUI, name: [:0]const u8) !void {
        try self.beginPanelEx(name, 0);
    }

    /// Kết thúc bảng con.
    pub inline fn endPanel(self: *MicroUI) void {
        _ = self.clip_stack.pop();
        self.popContainer();
    }

    /// Bắt đầu render nội dung của popup đã được mở.
    pub inline fn beginPopup(self: *MicroUI, name: [:0]const u8) !i32 {
        const opt = Opt.POPUP | Opt.AUTOSIZE | Opt.NORESIZE |
            Opt.NOSCROLL | Opt.NOTITLE | Opt.CLOSED;
        return if (try self.beginWindowEx(name, math.rect(0, 0, 0, 0), opt)) Res.ACTIVE else 0;
    }

    /// Kết thúc popup.
    pub inline fn endPopup(self: *MicroUI) void {
        self.endWindow();
    }

    // =========================================================================
    // 4.12 Tree Nodes & Collapsible Headers
    // =========================================================================

    /// Vẽ một thanh tiêu đề thu gọn/mở rộng (Header).
    pub inline fn header(self: *MicroUI, label: [:0]const u8) !i32 {
        return self.headerEx(label, 0);
    }

    /// Vẽ thanh tiêu đề kèm tùy chọn `Opt` (ví dụ: Opt.EXPANDED).
    pub fn headerEx(self: *MicroUI, label: [:0]const u8, opt: i32) !i32 {
        return self.headerInternal(label, false, opt);
    }

    /// Hàm xử lý chung logic đóng mở và tương tác cho Header và TreeNode.
    fn headerInternal(self: *MicroUI, label: [:0]const u8, is_treenode: bool, opt: i32) !i32 {
        const id = self.getId(label.ptr, label.len);
        const opt_idx = self.treenode_pool.getIdToIndex(id);

        self.layout_manager.setRow(&[_]i32{-1}, 0);

        var active = (opt_idx != null);
        const expanded = if ((opt & Opt.EXPANDED) != 0) !active else active;
        var r = self.layoutNext();
        self.updateControl(id, r, 0);

        if (self.mouse_input.isPressed(Mouse.LEFT) and self.focus == id) {
            active = !active;
        }

        if (opt_idx) |idx| {
            if (active) {
                self.treenode_pool.update(idx, self.frame);
            } else {
                self.treenode_pool.reset(idx);
            }
        } else if (active) {
            _ = self.treenode_pool.alloc(id, self.frame);
        }

        if (is_treenode) {
            if (self.hover == id) {
                try self.drawFrame(r, style_mod.COLOR_BUTTONHOVER);
            }
        } else {
            try self.drawControlFrame(id, r, style_mod.COLOR_BUTTON, 0);
        }

        const icon_id: i32 = if (expanded) Icon.EXPANDED else Icon.COLLAPSED;
        const colors = self.getStyle().colors;
        try self.drawIcon(icon_id, math.rect(r.x, r.y, r.h, r.h), colors[style_mod.ColorId.text_idx]);
        r.x += r.h - self.getStyle().padding;
        r.w -= r.h - self.getStyle().padding;
        try self.drawControlText(label.ptr, r, style_mod.COLOR_TEXT, 0);

        return if (expanded) Res.ACTIVE else 0;
    }

    /// Bắt đầu một nút dạng cây (TreeNode).
    pub inline fn beginTreenode(self: *MicroUI, name: [:0]const u8) !i32 {
        return self.beginTreenodeEx(name, 0);
    }

    /// Bắt đầu nút dạng cây kèm tùy chọn `Opt`.
    pub fn beginTreenodeEx(self: *MicroUI, label: [:0]const u8, opt: i32) !i32 {
        const res = try self.headerInternal(label, true, opt);
        if ((res & Res.ACTIVE) != 0) {
            self.getLayout().indent += self.getStyle().indent;
            self.id_stack.push(self.last_id);
        }
        return res;
    }

    /// Kết thúc nút dạng cây, thu hồi thụt lề layout.
    pub inline fn endTreenode(self: *MicroUI) void {
        self.getLayout().indent -= self.getStyle().indent;
        _ = self.id_stack.pop();
    }

    // =========================================================================
    // 4.13 Widget Library
    // =========================================================================

    /// Vẽ nhãn văn bản (Label) một dòng.
    pub inline fn drawLabel(self: *MicroUI, label: [:0]const u8) !void {
        try self.drawControlText(label.ptr, self.layoutNext(), style_mod.COLOR_TEXT, 0);
    }

    /// Vẽ đoạn văn bản nhiều dòng tự động xuống hàng theo từ (Word Wrapping).
    pub fn drawText(self: *MicroUI, text: []const u8) !void {
        self.layoutBeginColumn();
        defer self.layoutEndColumn();

        if (text.len == 0) {
            return;
        }

        const font = self.getStyle().font;
        self.layout_manager.setRow(&[_]i32{-1}, self.text_height.?(font));
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
                try self.drawTextEx(font, text[line_start..line_end], math.vec2(rect_val.x, rect_val.y), color_val);
            }
        }
    }

    /// Vẽ nút nhấn đơn giản (Button).
    pub inline fn button(self: *MicroUI, label: [:0]const u8) !i32 {
        return self.buttonEx(label, 0, Opt.ALIGNCENTER);
    }

    /// Vẽ nút nhấn kèm biểu tượng hoặc tùy chọn căn lề.
    pub fn buttonEx(self: *MicroUI, label: ?[:0]const u8, icon: i32, opt: i32) !i32 {
        var res: i32 = 0;
        const id = if (label) |l|
            self.getId(l.ptr, l.len)
        else
            self.getId(&icon, @sizeOf(i32));
        const r = self.layoutNext();
        self.updateControl(id, r, opt);
        if (self.mouse_input.isPressed(Mouse.LEFT) and self.focus == id) {
            res |= Res.SUBMIT;
        }
        try self.drawControlFrame(id, r, style_mod.COLOR_BUTTON, opt);
        if (label) |l| {
            try self.drawControlText(l.ptr, r, style_mod.COLOR_TEXT, opt);
        }
        if (icon != 0) {
            try self.drawIcon(icon, r, self.getStyle().colors[style_mod.ColorId.text_idx]);
        }
        return res;
    }

    /// Vẽ hộp kiểm tra (CheckBox).
    pub fn checkBox(self: *MicroUI, label: [:0]const u8, value: *i32) !i32 {
        var res: i32 = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf(*i32));
        const r = self.layoutNext();
        const box = math.rect(r.x, r.y, r.h, r.h);
        self.updateControl(id, r, 0);
        if (self.mouse_input.isPressed(Mouse.LEFT) and self.focus == id) {
            res |= Res.CHANGE;
            value.* = if (value.* != 0) 0 else 1;
        }
        try self.drawControlFrame(id, box, style_mod.COLOR_BASE, 0);
        if (value.* != 0) {
            try self.drawIcon(Icon.CHECK, box, self.getStyle().colors[style_mod.ColorId.text_idx]);
        }
        const text_rect = math.rect(r.x + box.w, r.y, r.w - box.w, r.h);
        try self.drawControlText(label.ptr, text_rect, style_mod.COLOR_TEXT, 0);
        return res;
    }

    /// Vẽ ô nhập văn bản (TextBox).
    pub inline fn textBox(self: *MicroUI, text: [*c]u8, len: i32) !i32 {
        return self.textBoxEx(text, len, 0);
    }

    /// Vẽ ô nhập văn bản kèm tùy chọn cấu hình `Opt`.
    pub fn textBoxEx(self: *MicroUI, text: [*c]u8, len: i32, opt: i32) !i32 {
        const addr = @intFromPtr(text);
        const id = self.getId(@ptrCast(&addr), @sizeOf(usize));
        const rect_val = self.layoutNext();
        return self.textBoxRaw(text, len, id, rect_val, opt);
    }

    /// Xử lý logic cấp thấp của ô nhập văn bản (con trỏ nhấp nháy, chỉnh sửa UTF-8, Enter submit).
    pub fn textBoxRaw(self: *MicroUI, buf: [*c]u8, bufsz: i32, id: Id, rect_val: math.Rect, opt: i32) !i32 {
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
        try self.drawControlFrame(id, rect_val, style_mod.COLOR_BASE, opt);
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
            try self.drawTextEx(font, text_span, .{ .x = textx, .y = texty }, color_val);
            try self.drawRect(math.rect(textx + textw, texty, 1, texth), color_val);
            _ = self.clip_stack.pop();
        } else {
            try self.drawControlText(buf, rect_val, style_mod.COLOR_TEXT, opt);
        }

        return res;
    }

    /// Hộp nhập số dạng popup khi người dùng Shift + Click chuột trái vào Slider hoặc Number.
    fn numberTextbox(self: *MicroUI, value: *f32, r: math.Rect, id: Id) !bool {
        if (self.mouse_input.isPressed(Mouse.LEFT) and
            (self.key_down & Key.SHIFT) != 0 and
            self.hover == id)
        {
            self.number_edit = id;
            _ = std.fmt.bufPrintSentinel(&self.number_edit_buf, "{d:.3}", .{value.*}, 0) catch {
                self.number_edit_buf[0] = 0;
            };
        }
        if (self.number_edit == id) {
            const res = try self.textBoxRaw(
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
    pub inline fn slider(self: *MicroUI, value: *f32, low: f32, high: f32) !i32 {
        return self.sliderEx(value, low, high, 0, SLIDER_FMT, Opt.ALIGNCENTER);
    }

    /// Thanh trượt kèm bước nhảy (step), chuỗi định dạng (fmt) và tùy chọn `Opt`.
    pub fn sliderEx(self: *MicroUI, value: *f32, low: f32, high: f32, step: f32, fmt: [*c]const u8, opt: i32) !i32 {
        var buf: [MAX_FMT + 1]u8 = undefined;
        var res: i32 = 0;
        const last = value.*;
        var v = last;
        const id = self.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = self.layoutNext();

        if (try self.numberTextbox(&v, base, id)) {
            return res;
        }

        self.updateControl(id, base, opt);

        if (self.focus == id and self.mouse_input.isDownOrPressed(Mouse.LEFT)) {
            if (base.w > 0) {
                v = low + @as(f32, @floatFromInt(self.mouse_input.pos.x - base.x)) * (high - low) / @as(f32, @floatFromInt(base.w));
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

        try self.drawControlFrame(id, base, style_mod.COLOR_BASE, opt);

        var thumb = base;
        const w = self.getStyle().thumb_size;
        thumb.w = w;
        const range = high - low;
        if (range > 0 and base.w > w) {
            thumb.x += @intFromFloat(@as(f32, @floatFromInt(base.w - w)) * (v - low) / range);
        }
        try self.drawControlFrame(id, thumb, style_mod.COLOR_BUTTON, opt);

        const formatted = formatReal(&buf, fmt, value.*);
        try self.drawControlText(formatted.ptr, base, style_mod.COLOR_TEXT, opt);

        return res;
    }

    /// Điều khiển chỉnh sửa số thực dạng kéo rê chuột (Number Drag).
    pub inline fn number(self: *MicroUI, value: *f32, step: f32) !i32 {
        return self.numberEx(value, step, SLIDER_FMT, Opt.ALIGNCENTER);
    }

    /// Điều khiển chỉnh sửa số thực kéo rê chuột kèm định dạng và tùy chọn `Opt`.
    pub fn numberEx(self: *MicroUI, value: *f32, step: f32, fmt: [*c]const u8, opt: i32) !i32 {
        var buf: [MAX_FMT + 1]u8 = undefined;
        var res: i32 = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = self.layoutNext();
        const last = value.*;

        if (try self.numberTextbox(value, base, id)) {
            return res;
        }

        self.updateControl(id, base, opt);

        if (self.focus == id and self.mouse_input.isDown(Mouse.LEFT)) {
            value.* += @as(f32, @floatFromInt(self.mouse_input.delta.x)) * step;
        }

        if (value.* != last) {
            res |= Res.CHANGE;
        }

        try self.drawControlFrame(id, base, style_mod.COLOR_BASE, opt);

        const formatted = formatReal(&buf, fmt, value.*);
        try self.drawControlText(formatted.ptr, base, style_mod.COLOR_TEXT, opt);

        return res;
    }
};
