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
const id_manager_mod = @import("id_manager.zig");
const widget_mod = @import("widget.zig");
pub const widget = widget_mod;

const input_control = @import("input_control.zig");
const InputControl = input_control.InputControl;

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

    pub const TextWidthFn = *const fn (font: Font, text: [*c]const u8, len: c_int) callconv(.c) c_int;
    pub const TextHeightFn = *const fn (font: Font) callconv(.c) c_int;

    // 4.1 State Fields & Stacks
    style: Style = style_mod.default_style,
    text_width: ?TextWidthFn = null,
    text_height: ?TextHeightFn = null,

    input_control: InputControl = .{},

    last_rect: math.Rect = .zero,

    clip_stack: stack.Stack(math.Rect, 32) = .{},

    id_manager: id_manager_mod.IdManager = .{},

    layout_manager: layout_mod.LayoutManager = .{},

    container_manager: container_mod.ContainerManager = .{},

    // treenode_pool: Pool(48) = .{},
    treenode_pool: Pool(widget_mod.TreeNode, 48) = .{},

    key_down: i32 = 0,
    key_pressed: i32 = 0,
    input_text: [32:0]u8 = [_:0]u8{0} ** 32,

    number_edit: Id = 0,
    number_edit_buf: [MAX_FMT:0]u8 = [_:0]u8{0} ** MAX_FMT,

    frame: i32 = 0,

    command_list: command_mod.CommandList = undefined,

    // =========================================================================
    // 4.1 Lifecycle & Frame Control
    // =========================================================================

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

    /// Bắt đầu một frame giao diện mới, chuẩn bị danh sách lệnh và cập nhật input.
    pub fn begin(self: *MicroUI) void {
        self.command_list.clear();
        self.container_manager.begin();
        self.input_control.updateMouseDelta();
        self.frame += 1;
    }

    /// Kết thúc frame giao diện hiện tại và liên kết chuỗi lệnh render của các root container theo Z-Index.
    pub fn end(self: *MicroUI) void {
        std.debug.assert(self.id_manager.isEmpty());
        std.debug.assert(self.clip_stack.isEmpty());
        std.debug.assert(self.layout_manager.isEmpty());

        self.container_manager.updateScroll(self.input_control.getScrollDelta());
        if (self.input_control.hasPressed()) {
            self.container_manager.bringHoverRootToFront();
        }

        self.key_pressed = 0;
        self.input_text[0] = 0;
        self.input_control.endFrame();
        if (self.command_list.head) |head| {
            self.container_manager.updateRender(head);
        }
    }

    /// Lấy con trỏ tham chiếu đến cấu hình Style giao diện hiện tại.
    pub inline fn getStyle(self: *MicroUI) *Style {
        return &self.style;
    }

    // =========================================================================
    // 4.2 Render Command Buffer & Iteration
    // =========================================================================

    /// Duyệt lệnh vẽ tiếp theo trong command buffer (Iterator tuần tự theo chuỗi jump/render).
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

    /// Đẩy một lệnh vẽ hình chữ nhật vào danh sách lệnh.
    pub inline fn pushRect(self: *MicroUI, draw_rect: math.Rect, color: Color) !*command_mod.Command {
        return self.command_list.pushRect(draw_rect, color);
    }

    /// Đẩy một lệnh vẽ biểu tượng vào danh sách lệnh.
    pub inline fn pushIcon(self: *MicroUI, id: Icon, draw_rect: math.Rect, color: Color) !*command_mod.Command {
        return self.command_list.pushIcon(id, draw_rect, color);
    }

    /// Đẩy một lệnh cắt khung nhìn (clipping) vào danh sách lệnh.
    pub inline fn pushClip(self: *MicroUI, r: math.Rect) !*command_mod.Command {
        return self.command_list.pushClip(r);
    }

    /// Đẩy một lệnh vẽ văn bản vào danh sách lệnh.
    pub fn pushText(self: *MicroUI, text: []const u8, pos: math.Vec2, color: Color, font: Font) !*command_mod.Command {
        return self.command_list.pushText(text, pos, color, font);
    }

    // =========================================================================
    // 4.3 Event & Input Handling
    // =========================================================================

    /// Cập nhật toạ độ con trỏ chuột.
    pub inline fn inputMousemove(self: *MicroUI, x: i32, y: i32) void {
        self.input_control.inputMouseMove(x, y);
    }

    /// Ghi nhận sự kiện nhấn nút chuột.
    pub inline fn inputMousedown(self: *MicroUI, x: i32, y: i32, btn: Mouse) void {
        self.input_control.inputMouseDown(x, y, btn);
    }

    /// Ghi nhận sự kiện nhả nút chuột.
    pub inline fn inputMouseup(self: *MicroUI, x: i32, y: i32, btn: Mouse) void {
        self.input_control.inputMouseUp(x, y, btn);
    }

    /// Ghi nhận sự kiện cuộn con lăn chuột.
    pub inline fn inputScroll(self: *MicroUI, x: i32, y: i32) void {
        self.input_control.inputScroll(x, y);
    }

    /// Ghi nhận sự kiện nhấn phím bàn phím.
    pub inline fn inputKeydown(self: *MicroUI, key: Key) void {
        self.key_pressed |= key.toInt();
        self.key_down |= key.toInt();
    }

    /// Ghi nhận sự kiện nhả phím bàn phím.
    pub inline fn inputKeyup(self: *MicroUI, key: Key) void {
        self.key_down &= ~key.toInt();
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

    /// Kiểm tra con trỏ chuột có đang lơ lửng (hover) trên hình chữ nhật `r` hay không (có xét clip stack và active container).
    pub inline fn mouseOver(self: *MicroUI, r: math.Rect) bool {
        if (!self.input_control.mouseOver(r) or
            !self.input_control.mouseOver(self.clip_stack.top()))
        {
            return false;
        }
        return self.container_manager.isActiveContainer();
    }

    /// Kiểm tra nút chuột có đang được giữ đè hay không.
    pub inline fn isMouseDown(self: *const MicroUI, btn: Mouse) bool {
        return self.input_control.isMouseDown(btn);
    }

    /// Kiểm tra nút chuột có vừa được nhấn xuống ở frame này hay không.
    pub inline fn isPressed(self: *const MicroUI, btn: Mouse) bool {
        return self.input_control.isPressed(btn);
    }

    /// Kiểm tra có bất kỳ nút chuột nào vừa được nhấn trong frame này hay không.
    pub inline fn hasPressed(self: *const MicroUI) bool {
        return self.input_control.hasPressed();
    }

    /// Kiểm tra nút chuột đang được giữ hoặc vừa nhấn trong frame này.
    pub inline fn isDownOrPressed(self: *const MicroUI, btn: Mouse) bool {
        return self.input_control.isDownOrPressed(btn);
    }

    /// Kiểm tra phím có đang được giữ đè hay không.
    pub inline fn isKeyDown(self: *const MicroUI, key: Key) bool {
        return (self.key_down & key.toInt()) != 0;
    }

    /// Kiểm tra phím có vừa được nhấn trong frame này hay không.
    pub inline fn isKeyPressed(self: *const MicroUI, key: Key) bool {
        return (self.key_pressed & key.toInt()) != 0;
    }

    /// Lấy toạ độ vị trí chuột hiện tại.
    pub inline fn getMousePos(self: *const MicroUI) math.Vec2 {
        return self.input_control.getMousePos();
    }

    /// Lấy độ dịch chuyển chuột trong frame hiện tại.
    pub inline fn getMouseDelta(self: *const MicroUI) math.Vec2 {
        return self.input_control.getMouseDelta();
    }

    // =========================================================================
    // 4.4 ID Management, Focus & Interaction State
    // =========================================================================

    /// Tạo mã định danh duy nhất (Id) từ buffer dữ liệu.
    pub inline fn getId(self: *MicroUI, data: ?*const anyopaque, len: usize) Id {
        return self.id_manager.getId(data, len);
    }

    /// Đẩy ID vào ngăn xếp định danh.
    pub inline fn pushId(self: *MicroUI, id: Id) void {
        self.id_manager.push(id);
    }

    /// Đưa ID ra khỏi ngăn xếp định danh.
    pub inline fn popId(self: *MicroUI) Id {
        return self.id_manager.pop();
    }

    /// Lấy ID gần nhất vừa được tính toán.
    pub inline fn getLastId(self: *const MicroUI) Id {
        return self.id_manager.getLastId();
    }

    /// Lấy ID widget đang giữ tiêu điểm nhập liệu (focus).
    pub inline fn getFocus(self: *const MicroUI) Id {
        return self.input_control.id_logic.focus;
    }

    /// Lấy ID widget đang được chuột lơ lửng bên trên (hover).
    pub inline fn getHover(self: *const MicroUI) Id {
        return self.input_control.id_logic.hover;
    }

    /// Đặt tiêu điểm nhập liệu (focus) cho widget có mã ID tương ứng.
    pub inline fn setFocus(self: *MicroUI, id: Id) void {
        self.input_control.setFocus(id);
    }

    /// Cập nhật trạng thái hover và focus của widget theo tương tác chuột (tính toán qua clipping và container).
    pub inline fn updateControl(self: *MicroUI, id: Id, rect_val: math.Rect, opt: i32) void {
        const mouseover = self.mouseOver(rect_val);
        self.input_control.updateControl(id, mouseover, opt);
    }

    // =========================================================================
    // 4.5 Clipping & Drawing Primitives
    // =========================================================================

    /// Đẩy một vùng cắt mới vào ngăn xếp clip (giao thoa với vùng clip cũ).
    pub fn pushClipRect(self: *MicroUI, r: math.Rect) void {
        const last = self.clip_stack.top();
        self.clip_stack.push(r.intersect(last));
    }

    /// Lấy vùng cắt trên đỉnh ngăn xếp ra ngoài.
    pub inline fn popClip(self: *MicroUI) math.Rect {
        return self.clip_stack.pop();
    }

    /// Kiểm tra trạng thái cắt clip của hình chữ nhật `r` so với vùng clip hiện tại.
    pub fn checkClip(self: *MicroUI, r: math.Rect) Clip {
        const cr = self.clip_stack.top();
        if (r.x > cr.x + cr.w or r.x + r.w < cr.x or r.y > cr.y + cr.h or r.y + r.h < cr.y) {
            return .all;
        }
        if (r.x >= cr.x and r.x + r.w <= cr.x + cr.w and r.y >= cr.y and r.y + r.h <= cr.y + cr.h) {
            return .none;
        }
        return .part;
    }

    /// Vẽ một hình chữ nhật với màu tương ứng (có kiểm tra clip).
    pub fn drawRect(self: *MicroUI, r: math.Rect, col: Color) !void {
        const draw_rect = r.intersect(self.clip_stack.top());
        if (draw_rect.w > 0 and draw_rect.h > 0) {
            _ = try self.pushRect(draw_rect, col);
        }
    }

    /// Vẽ khung nền và viền của control theo color_id.
    pub fn drawFrame(self: *MicroUI, r: math.Rect, color_enum: style_mod.ColorId) !void {
        const color = self.getStyle().getColor(color_enum);
        _ = try self.drawRect(r, color);
        if (color_enum == style_mod.ColorId.scroll_base or
            color_enum == style_mod.ColorId.scroll_thumb or
            color_enum == style_mod.ColorId.title_bg)
        {
            return;
        }
        const border_col = self.getStyle().getColor(style_mod.ColorId.border);
        if (border_col.a != 0) {
            const b = r.expand(1);
            _ = try self.drawRect(.init(b.x + 1, b.y, b.w - 2, 1), border_col);
            _ = try self.drawRect(.init(b.x + 1, b.y + b.h - 1, b.w - 2, 1), border_col);
            _ = try self.drawRect(.init(b.x, b.y, 1, b.h), border_col);
            _ = try self.drawRect(.init(b.x + b.w - 1, b.y, 1, b.h), border_col);
        }
    }

    /// Vẽ khung nền của widget điều khiển, tự động đổi màu khi hover hoặc focus.
    pub fn drawControlFrame(self: *MicroUI, id: Id, rect_val: math.Rect, color_id: ColorId, opt: i32) !void {
        if (Opt.has(opt, .no_frame)) {
            return;
        }
        var color_val = color_id.toInt();
        if (self.input_control.id_logic.focus == id) {
            color_val += 2;
        } else if (self.input_control.id_logic.hover == id) {
            color_val += 1;
        }
        _ = try self.drawFrame(rect_val, @enumFromInt(color_val));
    }

    /// Vẽ biểu tượng (Icon) có kiểm tra clip.
    pub fn drawIcon(self: *MicroUI, id: Icon, r: math.Rect, col: Color) !void {
        const clipped = r.intersect(self.clip_stack.top());
        if (clipped.w > 0 and clipped.h > 0) {
            _ = try self.pushIcon(id, clipped, col);
        }
    }

    /// Vẽ văn bản với font, vị trí và màu chỉ định (tự động cắt clip một phần hoặc toàn bộ).
    pub fn drawText(self: *MicroUI, font: Font, text: []const u8, pos: math.Vec2, col: Color) !void {
        if (text.len == 0) return;
        const text_width = self.text_width.?(font, &text[0], @intCast(text.len));
        const text_height = self.text_height.?(font);
        const rect_val = math.Rect.init(pos.x, pos.y, text_width, text_height);
        const clipped = self.checkClip(rect_val);
        if (clipped == .all) {
            return;
        }
        if (clipped == .part) {
            _ = try self.pushClip(self.clip_stack.top());
        }
        _ = try self.pushText(text, pos, col, font);
        if (clipped != .none) {
            _ = try self.pushClip(.init(0, 0, 0x1000000, 0x1000000));
        }
    }

    // =========================================================================
    // 4.6 Layout Engine
    // =========================================================================

    /// Thiết lập cấu hình hàng layout (danh sách chiều rộng và chiều cao hàng).
    pub inline fn setLayoutRow(self: *MicroUI, widths: []const i32, height: i32) void {
        self.layout_manager.setRow(widths, height);
    }

    /// Đặt độ rộng cho widget kế tiếp trong hàng.
    pub inline fn layoutWidth(self: *MicroUI, width: i32) void {
        self.getLayout().size.x = width;
    }

    /// Đặt chiều cao cho hàng hiện tại.
    pub inline fn layoutHeight(self: *MicroUI, height: i32) void {
        self.getLayout().size.y = height;
    }

    /// Tính toán toạ độ và kích thước cho widget kế tiếp theo cơ chế phân bổ layout.
    pub inline fn layoutNext(self: *MicroUI) math.Rect {
        self.last_rect = self.layout_manager.getNext(self.getStyle());
        return self.last_rect;
    }

    /// Đặt vị trí và kích thước thủ công cho widget kế tiếp.
    pub inline fn layoutSetNext(self: *MicroUI, r: math.Rect, relative: bool) void {
        self.layout_manager.setNext(r, relative);
    }

    /// Bắt đầu một cột con lồng nhau bên trong layout hàng hiện tại.
    pub inline fn layoutBeginColumn(self: *MicroUI) void {
        self.layout_manager.beginColumn(self.layoutNext());
    }

    /// Kết thúc cột con, cập nhật lại kích thước cho layout cha.
    pub inline fn layoutEndColumn(self: *MicroUI) void {
        self.layout_manager.endColumn();
    }

    /// Lấy con trỏ đến trạng thái layout hiện tại ở đỉnh stack.
    pub inline fn getLayout(self: *MicroUI) *Layout {
        return self.layout_manager.getCurrent();
    }

    /// Đẩy một layout mới vào stack với vùng thân (body) và vị trí cuộn (scroll).
    pub inline fn pushLayout(self: *MicroUI, body: math.Rect, scroll: math.Vec2) void {
        self.layout_manager.push(body, scroll);
    }

    // =========================================================================
    // 4.7 Container & Window Infrastructure
    // =========================================================================

    /// Lấy hoặc tạo mới một Container theo ID.
    pub inline fn getContainer(self: *MicroUI, id: Id, opt: i32) ?*container_mod.Container {
        return self.container_manager.getOrAlloc(id, opt, self.frame);
    }

    /// Lấy con trỏ Container theo tên tiêu đề.
    pub inline fn getContainerByName(self: *MicroUI, name: [:0]const u8) ?*container_mod.Container {
        const id = self.id_manager.getId(name.ptr, name.len);
        return self.getContainer(id, 0);
    }

    /// Lấy container hiện tại đang được xử lý ở đỉnh stack.
    pub inline fn getCurrentContainer(self: *MicroUI) *container_mod.Container {
        return self.container_manager.getCurrent();
    }

    /// Bắt đầu một root container (cửa sổ độc lập hoặc popup trên cùng).
    pub fn beginRootContainer(self: *MicroUI, cnt: *container_mod.Container) !void {
        self.container_manager.pushRoot(cnt);
        cnt.*.head = try self.command_list.pushJump(null);
        if (self.input_control.mouseOver(cnt.rect)) {
            self.container_manager.setNextHoverRoot(cnt);
        }
        self.clip_stack.push(.init(0, 0, 0x1000000, 0x1000000));
    }

    /// Kết thúc một root container.
    pub fn endRootContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        cnt.*.tail = self.command_list.pushJump(null) catch |err| blk: {
            std.log.err("endRootContainer pushJump failed: {s}", .{@errorName(err)});
            break :blk null;
        };
        _ = self.clip_stack.pop();
        self.popContainer();
    }

    /// Đẩy container vào ngăn xếp xử lý.
    pub inline fn pushContainer(self: *MicroUI, cnt: *container_mod.Container) void {
        self.container_manager.push(cnt);
    }

    /// Đóng và đưa container hiện tại ra khỏi ngăn xếp xử lý.
    pub fn popContainer(self: *MicroUI) void {
        const cnt = self.container_manager.getCurrent();
        const layout = self.getLayout();
        cnt.*.content_size.x = layout.*.max.x - layout.*.body.x;
        cnt.*.content_size.y = layout.*.max.y - layout.*.body.y;
        _ = self.container_manager.pop();
        _ = self.layout_manager.pop();
        _ = self.id_manager.pop();
    }

    /// Đẩy body của container vào layout và tính toán thanh cuộn.
    pub fn pushContainerBody(self: *MicroUI, cnt: *container_mod.Container, body: math.Rect, opt: i32) !void {
        var b = body;
        if (!Opt.has(opt, .no_scroll)) {
            try widget_mod.Scrollbar.scrollbars(self, cnt, &b);
        }
        self.pushLayout(b.expand(-self.getStyle().padding), cnt.scroll);
        cnt.body = b;
    }

    /// Đưa container lên lớp trên cùng (Z-Index cao nhất).
    pub inline fn bringToFront(self: *MicroUI, cnt: *container_mod.Container) void {
        self.container_manager.bringToFront(cnt);
    }

    /// Đặt container làm popup hiện tại.
    pub inline fn setPopup(self: *MicroUI, cnt: *container_mod.Container) void {
        self.container_manager.setPopup(cnt);
    }

    /// Đặt mục tiêu cuộn chuột cho container.
    pub inline fn setScrollTarget(self: *MicroUI, cnt: *container_mod.Container) void {
        self.container_manager.setScrollTarget(cnt);
    }

    /// Kiểm tra container có phải là hover_root hiện tại hay không.
    pub inline fn isHoverRoot(self: *const MicroUI, cnt: ?*container_mod.Container) bool {
        return self.container_manager.isHoverRoot(cnt);
    }
};
