const std = @import("std");
const c_microui = @import("c_microui");
const stack = @import("stack.zig");

// =============================================================================
// C RUNTIME INTEROPERABILITY & GENERAL HELPERS
// =============================================================================

extern "c" fn sprintf(str: [*c]u8, format: [*c]const u8, ...) c_int;
extern "c" fn strtod(nptr: [*c]const u8, endptr: [*c][*c]u8) f64;

pub const MicroUI = struct {
    mu_context: *c_microui.mu_Context,

    id_stack: stack.BuildStack(c_uint, 32) = .{},
    clip_stack: stack.BuildStack(c_microui.mu_Rect, 32) = .{},
    layout_stack: stack.BuildStack(c_microui.mu_Layout, 16) = .{},
    container_stack: stack.BuildStack([*c]c_microui.mu_Container, 32) = .{},
    root_list: stack.BuildStack([*c]c_microui.mu_Container, 32) = .{},

    last_zindex: i32 = 0,
    updated_focus: bool = false,
    frame: usize = 0,
    mouse_down: c_int = 0,
    mouse_pressed: c_int = 0,
    key_down: c_int = 0,
    key_pressed: c_int = 0,

    // =========================================================================
    // STYLE MẶC ĐỊNH & CÁC HÀM XỬ LÝ NỘI BỘ (RAW / LOW-LEVEL HELPERS)
    // =========================================================================

    const default_style: c_microui.mu_Style = .{
        .font = null,
        .size = .{ .x = 68, .y = 10 },
        .padding = 5,
        .spacing = 4,
        .indent = 24,
        .title_height = 24,
        .scrollbar_size = 12,
        .thumb_size = 8,
        .colors = [14]c_microui.mu_Color{
            .{ .r = 230, .g = 230, .b = 230, .a = 255 }, // MU_COLOR_TEXT
            .{ .r = 25, .g = 25, .b = 25, .a = 255 }, // MU_COLOR_BORDER
            .{ .r = 50, .g = 50, .b = 50, .a = 255 }, // MU_COLOR_WINDOWBG
            .{ .r = 25, .g = 25, .b = 25, .a = 255 }, // MU_COLOR_TITLEBG
            .{ .r = 240, .g = 240, .b = 240, .a = 255 }, // MU_COLOR_TITLETEXT
            .{ .r = 0, .g = 0, .b = 0, .a = 0 }, // MU_COLOR_PANELBG
            .{ .r = 75, .g = 75, .b = 75, .a = 255 }, // MU_COLOR_BUTTON
            .{ .r = 95, .g = 95, .b = 95, .a = 255 }, // MU_COLOR_BUTTONHOVER
            .{ .r = 115, .g = 115, .b = 115, .a = 255 }, // MU_COLOR_BUTTONFOCUS
            .{ .r = 30, .g = 30, .b = 30, .a = 255 }, // MU_COLOR_BASE
            .{ .r = 35, .g = 35, .b = 35, .a = 255 }, // MU_COLOR_BASEHOVER
            .{ .r = 40, .g = 40, .b = 40, .a = 255 }, // MU_COLOR_BASEFOCUS
            .{ .r = 43, .g = 43, .b = 43, .a = 255 }, // MU_COLOR_SCROLLBASE
            .{ .r = 30, .g = 30, .b = 30, .a = 255 }, // MU_COLOR_SCROLLTHUMB
        },
    };

    /// Cấp phát một lệnh vẽ cấp thấp mới vào bộ đệm danh sách lệnh của context.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính kích thước căn chỉnh bộ nhớ 8-byte (`(size + 7) & ~7`) nhằm tránh unaligned access.
    /// - Kiểm tra bộ đệm lệnh còn đủ chỗ chứa lệnh mới.
    /// - Gán mã lệnh `cmd_type` và kích thước `aligned_size` vào phần đầu của command.
    /// - Cập nhật con trỏ ghi `command_list.idx` và trả về con trỏ tới struct lệnh.
    fn rawPushCommand(ctx: *c_microui.mu_Context, cmd_type: c_int, size: c_int) [*c]c_microui.mu_Command {
        const cmd: [*c]c_microui.mu_Command = @ptrCast(@alignCast(&ctx.*.command_list.items[@intCast(ctx.*.command_list.idx)]));
        const aligned_size = (size + 7) & ~@as(c_int, 7);
        std.debug.assert(ctx.*.command_list.idx + aligned_size < ctx.*.command_list.items.len);
        cmd.*.base.type = cmd_type;
        cmd.*.base.size = aligned_size;
        ctx.*.command_list.idx += aligned_size;
        return cmd;
    }

    /// Mở rộng hoặc thu hẹp kích thước hình chữ nhật đều ra cả 4 phía.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tịnh tiến gốc tọa độ lùi `(x - n, y - n)`.
    /// - Tăng chiều rộng và chiều cao thêm `2 * n` đơn vị.
    fn rawExpandRect(rect: c_microui.mu_Rect, n: c_int) c_microui.mu_Rect {
        return c_microui.mu_rect(rect.x - n, rect.y - n, rect.w + n * 2, rect.h + n * 2);
    }

    /// Khởi tạo dữ liệu gốc cho struct `mu_Context` với các giá trị mặc định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Xóa trắng toàn bộ vùng nhớ struct bằng `@memset(0)`.
    /// - Khởi tạo style mặc định và trỏ `ctx.style` tới cấu hình style đó.
    fn rawInit(ctx: *c_microui.mu_Context) void {
        @memset(@as([*]u8, @ptrCast(ctx))[0..@sizeOf(c_microui.mu_Context)], 0);
        ctx.*._style = default_style;
        ctx.*.style = &ctx.*._style;
    }

    fn drawBox(self: *MicroUI, rect: c_microui.mu_Rect, color: c_microui.mu_Color) void {
        self.drawRect(c_microui.mu_rect(rect.x + 1, rect.y, rect.w - 2, 1), color);
        self.drawRect(c_microui.mu_rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color);
        self.drawRect(c_microui.mu_rect(rect.x, rect.y, 1, rect.h), color);
        self.drawRect(c_microui.mu_rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color);
    }

    fn drawFrame(self: *MicroUI, rect: c_microui.mu_Rect, color_id: c_int) void {
        const colors = self.mu_context.*.style.*.colors;
        self.drawRect(rect, colors[@intCast(color_id)]);
        if (color_id == c_microui.MU_COLOR_SCROLLBASE or color_id == c_microui.MU_COLOR_SCROLLTHUMB or
            color_id == c_microui.MU_COLOR_TITLEBG)
        {
            return;
        }
        if (colors[c_microui.MU_COLOR_BORDER].a != 0) {
            self.drawBox(rawExpandRect(rect, 1), colors[c_microui.MU_COLOR_BORDER]);
        }
    }

    // =========================================================================
    // 1. LIFECYCLE & CORE FRAME MANAGEMENT
    // =========================================================================

    /// Khởi tạo instance MicroUI và phân bổ bộ nhớ heap cho `mu_Context`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cấp phát bộ nhớ heap cho struct `mu_Context` thông qua allocator được truyền vào.
    /// - Gọi `rawInit()` để thiết lập các giá trị mặc định cho style, bảng màu và bộ đệm.
    /// - Gán các hàm callback đo kích thước font (`text_width`, `text_height`) vào context.
    /// - Sử dụng `errdefer` để đảm bảo giải phóng bộ nhớ nếu có lỗi xảy ra trong quá trình khởi tạo.
    pub fn init(
        allocator: std.mem.Allocator,
        text_width: fn (font: c_microui.mu_Font, text: [*c]const u8, len: c_int) callconv(.c) c_int,
        text_height: fn (font: c_microui.mu_Font) callconv(.c) c_int,
    ) !MicroUI {
        const ctx = try allocator.create(c_microui.mu_Context);
        errdefer allocator.destroy(ctx);

        rawInit(ctx);
        ctx.*.text_width = text_width;
        ctx.*.text_height = text_height;

        return .{
            .mu_context = ctx,
        };
    }

    /// Hủy instance MicroUI và giải phóng tài nguyên heap của context.
    ///
    /// Thuật toán & Thiết kế:
    /// - Giải phóng vùng nhớ struct `mu_Context` đã cấp phát ban đầu thông qua allocator.
    pub fn deinit(self: *MicroUI, allocator: std.mem.Allocator) void {
        allocator.destroy(self.mu_context);
    }

    /// Bắt đầu một frame giao diện mới, chuẩn bị danh sách lệnh và cập nhật input.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra hợp lệ 2 callback đo kích thước font (`text_width`, `text_height`).
    /// - Đặt lại chỉ số danh sách lệnh (`command_list.idx = 0`) và danh sách cửa sổ gốc (`root_list.idx = 0`).
    /// - Chuyển giao cửa sổ hover dự kiến (`next_hover_root`) sang `hover_root` hiện tại.
    /// - Tính toán vector vận tốc di chuột `mouse_delta = mouse_pos - last_mouse_pos`.
    /// - Tăng chỉ số frame hiện tại (`frame += 1`).
    pub fn begin(self: *MicroUI) void {
        std.debug.assert(self.mu_context.*.text_width != null and self.mu_context.*.text_height != null);
        self.mu_context.*.command_list.idx = 0;
        self.root_list.clear();
        self.mu_context.*.scroll_target = null;
        self.mu_context.*.hover_root = self.mu_context.*.next_hover_root;
        self.mu_context.*.next_hover_root = null;
        self.mu_context.*.mouse_delta.x = self.mu_context.*.mouse_pos.x - self.mu_context.*.last_mouse_pos.x;
        self.mu_context.*.mouse_delta.y = self.mu_context.*.mouse_pos.y - self.mu_context.*.last_mouse_pos.y;
        self.frame += 1;
    }

    /// Hàm so sánh trật tự chiều sâu Z-Index giữa hai root container phục vụ thuật toán sắp xếp.
    fn compareContainersByZIndex(_: void, a: [*c]c_microui.mu_Container, b: [*c]c_microui.mu_Container) bool {
        return a.*.zindex < b.*.zindex;
    }

    /// Kết thúc frame giao diện hiện tại và liên kết chuỗi lệnh render của các root container.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra tính toàn vẹn của tất cả các ngăn xếp nội bộ (container, clip rect, id, layout đều đã pop hết).
    /// - Cập nhật cuộn cho container mục tiêu (`scroll_target`) nếu có tương tác lăn chuột.
    /// - Cập nhật trạng thái focus và reset nếu trong frame không có widget nào gia hạn focus.
    /// - Đưa root container đang được click lên trên cùng (`bringToFront`) nếu z-index nhỏ hơn cửa sổ trên cùng.
    /// - Xóa trắng các cờ sự kiện phím, chuột và bộ đệm ký tự văn bản frame này.
    /// - Sắp xếp danh sách `root_list` theo thứ tự z-index tăng dần.
    /// - Liên kết các root container bằng các lệnh JUMP:
    ///   + Thiết lập lệnh JUMP đầu tiên sang head của root container đầu tiên.
    ///   + Thiết lập lệnh JUMP từ tail của root container trước sang head của container sau.
    ///   + Thiết lập lệnh JUMP từ tail của container cuối cùng trỏ đến cuối danh sách command list.
    pub fn end(self: *MicroUI) void {
        std.debug.assert(self.id_stack.idx == 0);
        std.debug.assert(self.clip_stack.idx == 0);
        std.debug.assert(self.layout_stack.idx == 0);
        std.debug.assert(self.container_stack.idx == 0);

        if (self.mu_context.*.scroll_target != null) {
            self.mu_context.*.scroll_target.*.scroll.x += self.mu_context.*.scroll_delta.x;
            self.mu_context.*.scroll_target.*.scroll.y += self.mu_context.*.scroll_delta.y;
        }

        if (!self.updated_focus) {
            self.mu_context.*.focus = 0;
        }
        self.updated_focus = false;

        if (self.mouse_pressed != 0 and
            self.mu_context.*.next_hover_root != null and
            self.mu_context.*.next_hover_root.*.zindex < self.last_zindex and
            self.mu_context.*.next_hover_root.*.zindex >= 0)
        {
            self.bringToFront(self.mu_context.*.next_hover_root.?);
        }

        self.key_pressed = 0;
        self.mu_context.*.input_text[0] = 0;
        self.mouse_pressed = 0;
        self.mu_context.*.scroll_delta = .{ .x = 0, .y = 0 };
        self.mu_context.*.last_mouse_pos = self.mu_context.*.mouse_pos;

        const root_items = self.root_list.getSlice();
        const n = root_items.len;
        std.mem.sort([*c]c_microui.mu_Container, root_items, {}, compareContainersByZIndex);

        for (root_items, 0..) |cnt, i| {
            if (i == 0) {
                const cmd: [*c]c_microui.mu_Command = @ptrCast(@alignCast(&self.mu_context.*.command_list.items));
                cmd.*.jump.dst = @ptrCast(@as([*]u8, @ptrCast(cnt.*.head)) + @sizeOf(c_microui.mu_JumpCommand));
            } else {
                const prev = root_items[i - 1];
                prev.*.tail.*.jump.dst = @ptrCast(@as([*]u8, @ptrCast(cnt.*.head)) + @sizeOf(c_microui.mu_JumpCommand));
            }
            if (i == n - 1) {
                cnt.*.tail.*.jump.dst = @ptrCast(&self.mu_context.*.command_list.items[@intCast(self.mu_context.*.command_list.idx)]);
            }
        }
    }

    // =========================================================================
    // 2. INPUT HANDLING
    // =========================================================================

    /// Cập nhật tọa độ con trỏ chuột tuyệt đối.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu trực tiếp vector tọa độ `(x, y)` vào `ctx.mouse_pos`.
    pub fn inputMousemove(self: *MicroUI, x: c_int, y: c_int) void {
        self.mu_context.*.mouse_pos = c_microui.mu_vec2(x, y);
    }

    /// Xử lý sự kiện nhấn nút chuột (Mouse Down).
    ///
    /// Thuật toán & Thiết kế:
    /// - Cập nhật vị trí chuột hiện tại thông qua `inputMousemove`.
    /// - Bật bit trạng thái đang giữ nút chuột (`mouse_down |= btn`).
    /// - Bật bit trạng thái vừa nhấn trong frame này (`mouse_pressed |= btn`).
    pub fn inputMousedown(self: *MicroUI, x: c_int, y: c_int, btn: c_int) void {
        self.inputMousemove(x, y);
        self.mouse_down |= btn;
        self.mouse_pressed |= btn;
    }

    /// Xử lý sự kiện thả nút chuột (Mouse Up).
    ///
    /// Thuật toán & Thiết kế:
    /// - Cập nhật vị trí chuột hiện tại.
    /// - Tắt bit trạng thái đang giữ nút chuột (`mouse_down &= ~btn`).
    pub fn inputMouseup(self: *MicroUI, x: c_int, y: c_int, btn: c_int) void {
        self.inputMousemove(x, y);
        self.mouse_down &= ~btn;
    }

    /// Xử lý sự kiện cuộn bánh xe chuột (Mouse Scroll Wheel).
    ///
    /// Thuật toán & Thiết kế:
    /// - Cộng dồn độ lệch cuộn `(x, y)` vào `scroll_delta` để xử lý cuộn nội dung ở frame hiện tại.
    pub fn inputScroll(self: *MicroUI, x: c_int, y: c_int) void {
        self.mu_context.*.scroll_delta.x += x;
        self.mu_context.*.scroll_delta.y += y;
    }

    /// Xử lý sự kiện nhấn phím từ bàn phím (Key Down).
    ///
    /// Thuật toán & Thiết kế:
    /// - Bật bit trạng thái phím vừa nhấn (`key_pressed |= key`) cho các thao tác tức thì (Enter, Backspace...).
    /// - Bật bit trạng thái phím đang giữ (`key_down |= key`) cho các phím bổ trợ (Shift, Ctrl, Alt...).
    pub fn inputKeydown(self: *MicroUI, key: c_int) void {
        self.key_pressed |= key;
        self.key_down |= key;
    }

    /// Xử lý sự kiện nhả phím từ bàn phím (Key Up).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tắt bit trạng thái đang giữ phím (`key_down &= ~key`).
    pub fn inputKeyup(self: *MicroUI, key: c_int) void {
        self.key_down &= ~key;
    }

    /// Tiếp nhận chuỗi ký tự UTF-8 từ sự kiện nhập văn bản của hệ thống cửa sổ (Text Input).
    ///
    /// Thuật toán & Thiết kế:
    /// - Đo chiều dài các ký tự hiện có trong bộ đệm `input_text`.
    /// - Nối các byte ký tự mới từ chuỗi null-terminated vào cuối bộ đệm nếu còn dung lượng trống.
    /// - Luôn đảm bảo ký tự kết thúc chuỗi null-terminator `0` ở cuối mảng.
    pub fn inputText(self: *MicroUI, text: [*c]const u8) void {
        const span = std.mem.span(text);
        const input_buf = &self.mu_context.*.input_text;
        const current_len = std.mem.sliceTo(input_buf, 0).len;
        const remaining = input_buf.len - 1 - current_len;
        const copy_len = @min(span.len, remaining);
        if (copy_len > 0) {
            @memcpy(input_buf[current_len..][0..copy_len], span[0..copy_len]);
            input_buf[current_len + copy_len] = 0;
        }
    }

    // =========================================================================
    // 3. COMMAND BUFFER & CLIPPING
    // =========================================================================

    /// Tính giao giữa hai hình chữ nhật (AABB Intersection).
    ///
    /// Thuật toán & Thiết kế:
    /// - Xác định góc trên-trái cực đại: `x1 = max(r1.x, r2.x)`, `y1 = max(r1.y, r2.y)`.
    /// - Xác định góc dưới-phải cực tiểu: `x2 = min(r1.x + r1.w, r2.x + r2.w)`, `y2 = min(r1.y + r1.h, r2.y + r2.h)`.
    /// - Nếu `x2 < x1` hoặc `y2 < y1`: hai hình không giao nhau, trả về rect rỗng `(w = 0, h = 0)`.
    /// - Ngược lại, trả về hình chữ nhật có tọa độ `(x1, y1)` và kích thước `(x2 - x1, y2 - y1)`.
    pub fn intersectRects(r1: c_microui.mu_Rect, r2: c_microui.mu_Rect) c_microui.mu_Rect {
        const x1 = @max(r1.x, r2.x);
        const y1 = @max(r1.y, r2.y);
        const x2 = @min(r1.x + r1.w, r2.x + r2.w);
        const y2 = @min(r1.y + r1.h, r2.y + r2.h);
        if (x2 < x1 or y2 < y1) {
            return .{ .x = x1, .y = y1, .w = 0, .h = 0 };
        } else {
            return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
        }
    }

    /// Kiểm tra trạng thái cắt của một hình chữ nhật đối với vùng clip rect hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lấy clip rect ở đỉnh ngăn xếp qua `getClipRect()`.
    /// - Trả về `MU_CLIP_ALL` (hoàn toàn ngoài biên) nếu `r` nằm hoàn toàn tách rời ngoài `clip_rect`.
    /// - Trả về `0` (hoàn toàn trong biên) nếu `r` nằm trọn vẹn bên trong `clip_rect`.
    /// - Trả về `MU_CLIP_PART` (cắt một phần) nếu `r` chỉ giao nhau một phần với `clip_rect`.
    pub fn checkClip(self: *MicroUI, r: c_microui.mu_Rect) c_int {
        const cr = self.getClipRect();
        if (r.x > cr.x + cr.w or r.x + r.w < cr.x or r.y > cr.y + cr.h or r.y + r.h < cr.y) {
            return c_microui.MU_CLIP_ALL;
        }
        if (r.x >= cr.x and r.x + r.w <= cr.x + cr.w and r.y >= cr.y and r.y + r.h <= cr.y + cr.h) {
            return 0;
        }
        return c_microui.MU_CLIP_PART;
    }

    /// Lấy hình chữ nhật giới hạn cắt (Clip Rect) hiện tại ở đỉnh ngăn xếp.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi hàm nội bộ `rawGetClipRect(mu_context)` để đọc phần tử đỉnh `clip_stack`.
    pub fn getClipRect(self: *MicroUI) c_microui.mu_Rect {
        return self.clip_stack.getValue();
    }

    /// Đẩy một vùng cắt mới vào ngăn xếp và tính giao với vùng cắt hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lấy vùng cắt trước đó `last = getClipRect()`.
    /// - Tính giao `intersectRects(rect, last)` để thu hẹp vùng nhìn lồng nhau.
    /// - Đẩy kết quả vào `clip_stack` và tăng `clip_stack.idx`.
    pub fn pushClipRect(self: *MicroUI, rect: c_microui.mu_Rect) void {
        const last = self.clip_stack.getValue();
        self.clip_stack.push(intersectRects(rect, last));
    }

    /// Rút vùng cắt gần nhất khỏi ngăn xếp.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra điều kiện biên `clip_stack.idx > 0`.
    /// - Giảm `clip_stack.idx` đi 1 đơn vị để khôi phục vùng cắt trước đó.
    pub fn popClipRect(self: *MicroUI) void {
        _ = self.clip_stack.pop();
    }

    /// Đưa lệnh thiết lập vùng cắt (Clip Command) vào bộ đệm lệnh vẽ.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cấp phát một command kiểu `MU_COMMAND_CLIP` với kích thước struct `mu_ClipCommand`.
    /// - Gán vùng giới hạn hiển thị `clip.rect = rect`.
    pub fn setClip(self: *MicroUI, rect: c_microui.mu_Rect) void {
        const cmd = self.pushCommand(c_microui.MU_COMMAND_CLIP, @sizeOf(c_microui.mu_ClipCommand));
        cmd.*.clip.rect = rect;
    }

    /// Xóa bỏ giới hạn cắt, khôi phục không gian hiển thị tối đa của màn hình.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `setClip` với vùng rect bao trùm tọa độ cực đại từ 0 đến 0x1000000.
    pub fn setClipUnclipped(self: *MicroUI) void {
        self.setClip(c_microui.mu_rect(0, 0, 0x1000000, 0x1000000));
    }

    /// Cấp phát và ghi một lệnh vẽ mới vào mảng lệnh tuyến tính (`command_list`).
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới hàm nội bộ `rawPushCommand`.
    /// - Đảm bảo kích thước được căn chỉnh 8-byte và ghi nhận vào command stream.
    pub fn pushCommand(self: *MicroUI, cmd_type: c_int, size: c_int) [*c]c_microui.mu_Command {
        return rawPushCommand(self.mu_context, cmd_type, size);
    }

    /// Đẩy lệnh JUMP để chuyển tiếp luồng duyệt command list đến một vị trí đích.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cấp phát một command kiểu `MU_COMMAND_JUMP` trong command buffer.
    /// - Gán con trỏ đích `jump.dst = dst`.
    pub fn pushJump(self: *MicroUI, dst: [*c]c_microui.mu_Command) [*c]c_microui.mu_Command {
        const cmd = self.pushCommand(c_microui.MU_COMMAND_JUMP, @sizeOf(c_microui.mu_JumpCommand));
        cmd.*.jump.dst = dst;
        return cmd;
    }

    /// Duyệt lệnh vẽ tiếp theo trong command buffer (Iterator).
    ///
    /// Thuật toán & Thiết kế:
    /// - Nếu `cmd.* == null`: bắt đầu từ đầu buffer (`command_list.items`).
    /// - Nếu `cmd.* != null`: tịnh tiến con trỏ theo kích thước `cmd.base.size`.
    /// - Duyệt qua và giải quyết các bước nhảy `MU_COMMAND_JUMP` bằng cách chuyển con trỏ tới `jump.dst`.
    /// - Dừng lại và trả về `1` khi gặp lệnh vẽ hợp lệ (Rect, Text, Icon, Clip).
    /// - Trả về `0` khi đã duyệt hết toàn bộ chuỗi lệnh tới cuối buffer.
    pub fn nextCommand(self: *MicroUI, cmd: *[*c]c_microui.mu_Command) c_int {
        const items_ptr: [*]u8 = &self.mu_context.*.command_list.items;
        const end_ptr = items_ptr + @as(usize, @intCast(self.mu_context.*.command_list.idx));
        if (cmd.* != null) {
            const raw: [*]u8 = @ptrCast(cmd.*);
            cmd.* = @ptrCast(@alignCast(raw + @as(usize, @intCast(cmd.*.*.base.size))));
        } else {
            cmd.* = @ptrCast(@alignCast(items_ptr));
        }
        while (@as([*]u8, @ptrCast(cmd.*)) != end_ptr) {
            if (cmd.*.*.base.type != c_microui.MU_COMMAND_JUMP) {
                return 1;
            }
            cmd.* = @ptrCast(@alignCast(cmd.*.*.jump.dst));
        }
        return 0;
    }

    // =========================================================================
    // 4. LOW-LEVEL DRAWING PRIMITIVES
    // =========================================================================

    /// Đẩy lệnh vẽ hình chữ nhật có màu vào command buffer sau khi đã cắt biên.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới hàm nội bộ `rawDrawRect(self.mu_context, rect, color)`.
    pub fn drawRect(self: *MicroUI, rect: c_microui.mu_Rect, color: c_microui.mu_Color) void {
        const draw_rect = intersectRects(rect, self.getClipRect());
        if (draw_rect.w > 0 and draw_rect.h > 0) {
            const cmd = self.pushCommand(c_microui.MU_COMMAND_RECT, @sizeOf(c_microui.mu_RectCommand));
            cmd.*.rect.rect = draw_rect;
            cmd.*.rect.color = color;
        }
    }

    /// Đẩy lệnh vẽ biểu tượng (Icon) vào command buffer.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính giao giữa `rect` của icon và `getClipRect()`.
    /// - Nếu nằm trong vùng hiển thị có kích thước dương:
    ///   + Cấp phát command `MU_COMMAND_ICON`.
    ///   + Lưu ID icon, vùng rect đã cắt và màu sắc hiển thị.
    pub fn drawIcon(self: *MicroUI, id: c_int, rect: c_microui.mu_Rect, color: c_microui.mu_Color) void {
        const r = intersectRects(rect, self.getClipRect());
        if (r.w > 0 and r.h > 0) {
            const cmd = self.pushCommand(c_microui.MU_COMMAND_ICON, @sizeOf(c_microui.mu_IconCommand));
            cmd.*.icon.id = id;
            cmd.*.icon.rect = r;
            cmd.*.icon.color = color;
        }
    }

    /// Đẩy lệnh vẽ một chuỗi ký tự đơn dòng tại vị trí xác định kèm xử lý clipping.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra rỗng: nếu `text.len == 0`, kết thúc ngay lập tức.
    /// - Đo chiều rộng chuỗi bằng callback `text_width` và chiều cao qua `text_height`.
    /// - Xác định bounding box của văn bản và kiểm tra clipping qua `checkClip()`.
    ///   + Nếu `MU_CLIP_ALL`: nằm ngoài màn hình, bỏ qua không vẽ.
    ///   + Nếu `MU_CLIP_PART`: đẩy lệnh `setClip()` tạm thời để GPU cắt đúng vùng nhìn.
    /// - Cấp phát command `MU_COMMAND_TEXT` với kích thước `sizeof(mu_TextCommand) + text.len`.
    /// - Sao chép byte văn bản vào `cmd.text.str` và gắn null-terminator `0` ở cuối.
    /// - Khôi phục vùng cắt `setClipUnclipped()` nếu trước đó bị cắt một phần.
    pub fn drawTextEx(self: *MicroUI, font: c_microui.mu_Font, text: []const u8, pos: c_microui.mu_Vec2, color: c_microui.mu_Color) void {
        if (text.len == 0) return;
        const text_width = self.mu_context.*.text_width.?(font, &text[0], @intCast(text.len));
        const text_height = self.mu_context.*.text_height.?(font);
        const rect = c_microui.mu_rect(pos.x, pos.y, text_width, text_height);
        const clipped = self.checkClip(rect);
        if (clipped == c_microui.MU_CLIP_ALL) {
            return;
        }
        if (clipped == c_microui.MU_CLIP_PART) {
            self.setClip(self.getClipRect());
        }
        const cmd = self.pushCommand(c_microui.MU_COMMAND_TEXT, @sizeOf(c_microui.mu_TextCommand) + @as(c_int, @intCast(text.len)));
        const tmp: [*]u8 = @ptrCast(&cmd.*.text.str);
        @memcpy(tmp[0..text.len], text);
        tmp[text.len] = 0;
        cmd.*.text.pos = pos;
        cmd.*.text.color = color;
        cmd.*.text.font = font;
        if (clipped != 0) {
            self.setClipUnclipped();
        }
    }

    /// Vẽ khung nền cho widget điều khiển (Button, Checkbox, Slider, Textbox...).
    ///
    /// Thuật toán & Thiết kế:
    /// - Bỏ qua nếu có cờ `MU_OPT_NOFRAME`.
    /// - Điều chỉnh biến thể màu sắc theo tương tác người dùng:
    ///   + Nếu widget đang có Focus: tăng mã màu +2 (màu active/focus).
    ///   + Nếu widget đang Hover: tăng mã màu +1 (màu hover).
    /// - Thực thi callback `draw_frame` của context để render khung chữ nhật.
    pub fn drawControlFrame(self: *MicroUI, id: c_uint, rect: c_microui.mu_Rect, color_id: c_int, opt: c_int) void {
        if ((opt & c_microui.MU_OPT_NOFRAME) != 0) {
            return;
        }
        var color = color_id;
        if (self.mu_context.*.focus == id) {
            color += 2;
        } else if (self.mu_context.*.hover == id) {
            color += 1;
        }
        self.drawFrame(rect, color);
    }

    /// Vẽ nhãn văn bản căn lề bên trong khung hình chữ nhật của widget.
    ///
    /// Thuật toán & Thiết kế:
    /// - Đo chiều rộng chuỗi `text` thông qua hàm đo kích thước font.
    /// - Đẩy `rect` của widget vào clip stack để chữ không bị tràn ra ngoài control.
    /// - Căn giữa theo trục Y (`y + (h - text_height) / 2`).
    /// - Căn lề trục X dựa trên tùy chọn `opt`:
    ///   + `MU_OPT_ALIGNCENTER`: đặt tại `x + (w - tw) / 2`.
    ///   + `MU_OPT_ALIGNRIGHT`: đặt tại `x + w - tw - padding`.
    ///   + Mặc định: căn trái tại `x + padding`.
    /// - Gọi `drawTextEx()` để đẩy lệnh render và pop clip rect.
    pub fn drawControlText(self: *MicroUI, text: [*c]const u8, rect: c_microui.mu_Rect, color_id: c_int, opt: c_int) void {
        const font = self.mu_context.*.style.*.font;
        const tw = self.mu_context.*.text_width.?(font, text, -1);
        self.pushClipRect(rect);
        defer self.popClipRect();

        var pos: c_microui.mu_Vec2 = undefined;
        pos.y = rect.y + @divTrunc(rect.h - self.mu_context.*.text_height.?(font), 2);
        if ((opt & c_microui.MU_OPT_ALIGNCENTER) != 0) {
            pos.x = rect.x + @divTrunc(rect.w - tw, 2);
        } else if ((opt & c_microui.MU_OPT_ALIGNRIGHT) != 0) {
            pos.x = rect.x + rect.w - tw - self.mu_context.*.style.*.padding;
        } else {
            pos.x = rect.x + self.mu_context.*.style.*.padding;
        }
        const color = self.mu_context.*.style.*.colors[0][@intCast(color_id)];
        const span = std.mem.span(text);
        self.drawTextEx(font, span, pos, color);
    }

    // =========================================================================
    // 5. STATE, ID & INTERACTION MANAGEMENT
    // =========================================================================

    /// Tạo mã hash định danh duy nhất (mu_Id) cho widget bằng thuật toán FNV-1a.
    ///
    /// Thuật toán & Thiết kế:
    /// - Khởi tạo giá trị băm từ đỉnh `id_stack` (nếu stack không rỗng) hoặc giá trị FNV offset basis `2166136261`.
    /// - Với mỗi byte trong dữ liệu đầu vào:
    ///   + `res = (res ^ byte) * 16777619` (sử dụng phép nhân tràn an toàn `*%`).
    /// - Lưu kết quả vào `ctx.last_id` và trả về mã hash ID.
    pub fn getId(self: *MicroUI, data: ?*const anyopaque, size: c_int) c_uint {
        const idx = self.id_stack.idx;
        var res: u32 = if (idx > 0) self.id_stack.getValue() else 2166136261;

        if (data) |p| {
            const bytes: [*]const u8 = @ptrCast(p);
            var i: usize = 0;
            const len: usize = @intCast(size);
            while (i < len) : (i += 1) {
                res = (res ^ bytes[i]) *% 16777619;
            }
        }
        self.mu_context.*.last_id = res;
        return res;
    }

    /// Tính ID từ dữ liệu và đẩy vào ID stack để tạo phân cấp định danh widget con.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `getId(data, size)`.
    /// - Lưu ID vừa tính vào đỉnh mảng `id_stack.items` và tăng chỉ số stack.
    pub fn pushId(self: *MicroUI, data: ?*const anyopaque, size: c_int) void {
        const id = self.getId(data, size);
        self.id_stack.push(id);
    }

    /// Đẩy trực tiếp một ID có sẵn vào ID stack mà không băm lại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu giá trị `id` thô vào đỉnh `id_stack` và tăng `id_stack.idx`.
    pub fn pushIdRaw(self: *MicroUI, id: c_uint) void {
        self.id_stack.push(id);
    }

    /// Rút ID trên cùng khỏi ID stack.
    ///
    /// Thuật toán & Thiết kế:
    /// - Giảm `id_stack.idx` đi 1 đơn vị sau khi assert stack không rỗng.
    pub fn popId(self: *MicroUI) void {
        _ = self.id_stack.pop();
    }

    /// Đặt trạng thái Focus (tiêu điểm bàn phím/chuột) cho widget có ID chỉ định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu `id` vào `ctx.focus`.
    /// - Đánh dấu cờ `updated_focus = 1` để giữ focus không bị reset ở cuối frame.
    pub fn setFocus(self: *MicroUI, id: c_uint) void {
        self.mu_context.*.focus = id;
        self.updated_focus = true;
    }

    /// Kiểm tra container hiện tại có thuộc cây cửa sổ đang nhận tương tác chuột hay không.
    ///
    /// Thuật toán & Thiết kế:
    /// - Duyệt ngược từ đỉnh `container_stack` xuống dưới:
    ///   + Nếu gặp container trùng với `hover_root`, trả về `true`.
    ///   + Dừng lại khi chạm tới gốc của một cửa sổ (`cnt.head != null`).
    /// - Trả về `false` nếu không thuộc phân cấp `hover_root`.
    pub fn inHoverRoot(self: *MicroUI) bool {
        var i = self.container_stack.idx;
        while (i > 0) {
            i -= 1;
            const cnt = self.container_stack.items[@intCast(i)];
            if (cnt == self.mu_context.*.hover_root) {
                return true;
            }
            if (cnt.*.head != null) {
                break;
            }
        }
        return false;
    }

    /// Kiểm tra điểm tọa độ 2D có nằm bên trong hình chữ nhật không (Point-in-Rect).
    ///
    /// Thuật toán & Thiết kế:
    /// - So sánh tọa độ `p.x >= r.x and p.x < r.x + r.w` và `p.y >= r.y and p.y < r.y + r.h`.
    pub fn rectOverlapsVec2(r: c_microui.mu_Rect, p: c_microui.mu_Vec2) bool {
        return p.x >= r.x and p.x < r.x + r.w and p.y >= r.y and p.y < r.y + r.h;
    }

    /// Kiểm tra con trỏ chuột có đang di chuột lên trên vùng widget hay không.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuột phải nằm bên trong vùng chữ nhật của widget (`rectOverlapsVec2(rect, mouse_pos)`).
    /// - Chuột phải nằm bên trong vùng cắt clip rect hiện tại.
    /// - Container chứa widget phải thuộc cây `hover_root` (không bị cửa sổ khác đè lên).
    pub fn mouseOver(self: *MicroUI, rect: c_microui.mu_Rect) bool {
        return rectOverlapsVec2(rect, self.mu_context.*.mouse_pos) and
            rectOverlapsVec2(self.getClipRect(), self.mu_context.*.mouse_pos) and
            self.inHoverRoot();
    }

    /// Cập nhật máy trạng thái tương tác chuột (Hover, Focus, Press) cho một widget.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính trạng thái `mouseover = mouseOver(rect)`.
    /// - Nếu widget đang có focus, gia hạn cờ `updated_focus = 1`.
    /// - Bỏ qua xử lý nếu có cờ `MU_OPT_NOINTERACT`.
    /// - Thiết lập `hover = id` khi chuột nằm trên widget và không có nút chuột nào đang giữ.
    /// - Xử lý chuyển đổi Focus:
    ///   + Nhấn chuột vào widget khi đang hover -> cấp Focus cho widget.
    ///   + Nhấn chuột ra ngoài widget -> hủy bỏ Focus (`setFocus(0)`).
    ///   + Nhả chuột khi không có tùy chọn `MU_OPT_HOLDFOCUS` -> hủy bỏ Focus.
    pub fn updateControl(self: *MicroUI, id: c_uint, rect: c_microui.mu_Rect, opt: c_int) void {
        const mouseover = self.mouseOver(rect);

        if (self.mu_context.*.focus == id) {
            self.updated_focus = true;
        }
        if ((opt & c_microui.MU_OPT_NOINTERACT) != 0) {
            return;
        }
        if (mouseover and self.mouse_down == 0) {
            self.mu_context.*.hover = id;
        }

        if (self.mu_context.*.focus == id) {
            if (self.mouse_pressed != 0 and !mouseover) {
                self.setFocus(0);
            }
            if (self.mouse_down == 0 and (~opt & c_microui.MU_OPT_HOLDFOCUS) != 0) {
                self.setFocus(0);
            }
        }

        if (self.mu_context.*.hover == id) {
            if (self.mouse_pressed != 0) {
                self.setFocus(id);
            } else if (!mouseover) {
                self.mu_context.*.hover = 0;
            }
        }
    }

    // =========================================================================
    // 6. LAYOUT SYSTEM
    // =========================================================================

    /// Lấy con trỏ tới thông tin bố cục (`mu_Layout`) hiện tại ở đỉnh ngăn xếp.
    ///
    /// Thuật toán & Thiết kế:
    /// - Trả về địa chỉ của phần tử tại chỉ số `layout_stack.idx - 1`.
    pub fn getLayout(self: *MicroUI) *c_microui.mu_Layout {
        return self.layout_stack.getPValue();
    }

    /// Khởi tạo và đẩy một layout mới vào stack với vùng hiển thị và thanh cuộn.
    ///
    /// Thuật toán & Thiết kế:
    /// - Trừ tọa độ body theo giá trị scroll: `x - scroll.x`, `y - scroll.y`.
    /// - Khởi tạo `layout.max` với giá trị âm cực tiểu để tích lũy kích thước nội dung con.
    /// - Đẩy vào `layout_stack` và khởi tạo hàng mặc định bằng `layoutRow(&[_]i32{0}, 0)`.
    pub fn pushLayout(self: *MicroUI, body: c_microui.mu_Rect, scroll: c_microui.mu_Vec2) void {
        var layout: c_microui.mu_Layout = undefined;
        @memset(@as([*]u8, @ptrCast(&layout))[0..@sizeOf(c_microui.mu_Layout)], 0);
        layout.body = c_microui.mu_rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h);
        layout.max = c_microui.mu_vec2(-0x1000000, -0x1000000);

        self.layout_stack.push(layout);
        self.layoutRow(&[_]i32{0}, 0);
    }

    /// Thiết lập cấu hình hàng bố cục nâng cao với số lượng cột, mảng chiều rộng và chiều cao.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sao chép các giá trị chiều rộng từ `widths` vào `layout.widths`.
    /// - Thiết lập vị trí con trỏ layout hiện tại tại `position = (indent, next_row)`.
    /// - Đặt lại chỉ số widget trong hàng `item_index = 0`.
    pub fn layoutRowEx(self: *MicroUI, items: c_int, widths: ?[]const i32, height: i32) void {
        const layout = self.getLayout();
        if (widths) |w| {
            std.debug.assert(w.len <= c_microui.MU_MAX_WIDTHS);
            for (w, 0..) |width_val, i| {
                layout.*.widths[i] = width_val;
            }
            layout.*.items = @intCast(w.len);
        } else {
            layout.*.items = items;
        }
        layout.*.position = c_microui.mu_vec2(layout.*.indent, layout.*.next_row);
        layout.*.size.y = height;
        layout.*.item_index = 0;
    }

    /// Cấu hình hàng bố cục đơn giản thông qua một mảng slice chiều rộng các cột.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `layoutRowEx` với số lượng phần tử tự động suy ra từ `widths.len`.
    pub fn layoutRow(self: *MicroUI, widths: []const i32, height: i32) void {
        self.layoutRowEx(@intCast(widths.len), widths, height);
    }

    /// Ghi đè chiều rộng cố định cho các widget kế tiếp trong hàng.
    ///
    /// Thuật toán & Thiết kế:
    /// - Thiết lập giá trị `layout.size.x = width`. Khi layout tự động xác định kích thước widget,
    ///   giá trị này sẽ được sử dụng nếu hàng không cấu hình mảng widths chi tiết.
    pub fn layoutWidth(self: *MicroUI, width: i32) void {
        self.getLayout().*.size.x = width;
    }

    /// Ghi đè chiều cao cho hàng hiện tại của layout.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cập nhật trực tiếp `layout.size.y = height`. Tất cả widget tiếp theo trong hàng sẽ thừa hưởng chiều cao này.
    pub fn layoutHeight(self: *MicroUI, height: i32) void {
        self.getLayout().*.size.y = height;
    }

    /// Đặt trước vị trí/kích thước hình chữ nhật cho widget kế tiếp (Manual Placement).
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu `r` vào `layout.next`.
    /// - Gán `next_type = 1` nếu tọa độ tương đối theo container, hoặc `2` nếu là tọa độ tuyệt đối trên màn hình.
    pub fn layoutSetNext(self: *MicroUI, r: c_microui.mu_Rect, relative: bool) void {
        const layout = self.getLayout();
        layout.*.next = r;
        layout.*.next_type = if (relative) 1 else 2;
    }

    /// Tính toán và lấy hình chữ nhật vị trí cho widget kế tiếp, sau đó tịnh tiến layout.
    ///
    /// Thuật toán & Thiết kế:
    /// - Nếu có `next_type != 0`: lấy rect đã đặt trước, reset cờ và trả về ngay nếu là tọa độ tuyệt đối.
    /// - Tự động xuống hàng mới nếu số widget đã vẽ trong hàng đạt ngưỡng `items`.
    /// - Tính toán chiều rộng `w` và chiều cao `h`:
    ///   + Giá trị < 0: tính kích thước tương đối dựa theo chiều rộng còn lại của container (`body.w - res.x + 1`).
    ///   + Giá trị == 0: lấy kích thước mặc định từ `style.size` cộng với khoảng đệm `padding * 2`.
    /// - Tịnh tiến `position.x` thêm `(w + spacing)`.
    /// - Cập nhật `next_row = max(next_row, y + h + spacing)`.
    /// - Tịnh tiến tọa độ tuyệt đối cộng thêm gốc container `(body.x, body.y)`.
    /// - Cập nhật biên tối đa `layout.max` phục vụ tính toán scroll bar.
    pub fn layoutNext(self: *MicroUI) c_microui.mu_Rect {
        const layout = self.getLayout();
        const style = self.mu_context.*.style;
        var res: c_microui.mu_Rect = undefined;

        if (layout.*.next_type != 0) {
            const next_type = layout.*.next_type;
            layout.*.next_type = 0;
            res = layout.*.next;
            if (next_type == 2) {
                self.mu_context.*.last_rect = res;
                return res;
            }
        } else {
            if (layout.*.item_index == layout.*.items) {
                self.layoutRowEx(layout.*.items, null, layout.*.size.y);
            }

            res.x = layout.*.position.x;
            res.y = layout.*.position.y;

            res.w = if (layout.*.items > 0) layout.*.widths[@intCast(layout.*.item_index)] else layout.*.size.x;
            res.h = layout.*.size.y;

            if (res.w == 0) {
                res.w = style.*.size.x + style.*.padding * 2;
            }
            if (res.h == 0) {
                res.h = style.*.size.y + style.*.padding * 2;
            }
            if (res.w < 0) {
                res.w += layout.*.body.w - res.x + 1;
            }
            if (res.h < 0) {
                res.h += layout.*.body.h - res.y + 1;
            }

            layout.*.item_index += 1;
        }

        layout.*.position.x += res.w + style.*.spacing;
        layout.*.next_row = @max(layout.*.next_row, res.y + res.h + style.*.spacing);

        res.x += layout.*.body.x;
        res.y += layout.*.body.y;

        layout.*.max.x = @max(layout.*.max.x, res.x + res.w);
        layout.*.max.y = @max(layout.*.max.y, res.y + res.h);

        self.mu_context.*.last_rect = res;
        return res;
    }

    /// Bắt đầu một cột dọc phụ lồng bên trong hàng hiện tại (Nested Column).
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `layoutNext()` để lấy ô dành cho cột.
    /// - Đẩy một sub-layout mới vào stack qua `pushLayout`.
    pub fn layoutBeginColumn(self: *MicroUI) void {
        self.pushLayout(self.layoutNext(), c_microui.mu_vec2(0, 0));
    }

    /// Kết thúc cột dọc phụ và hòa nhập kích thước trở lại layout cha.
    ///
    /// Thuật toán & Thiết kế:
    /// - Rút sub-layout con `b` khỏi `layout_stack`.
    /// - Cập nhật layout cha `a`: mở rộng `position.x`, `next_row`, `max` theo kích thước tối đa của cột `b`.
    pub fn layoutEndColumn(self: *MicroUI) void {
        const b = self.layout_stack.pop();
        const a = self.layout_stack.getPValue();
        a.*.position.x = @max(a.*.position.x, b.position.x + b.body.x - a.*.body.x);
        a.*.next_row = @max(a.*.next_row, b.next_row + b.body.y - a.*.body.y);
        a.*.max.x = @max(a.*.max.x, b.max.x);
        a.*.max.y = @max(a.*.max.y, b.max.y);
    }

    // =========================================================================
    // 7. POOL & CONTAINER MANAGEMENT
    // =========================================================================

    /// Tìm kiếm chỉ số của một phần tử trong pool theo ID định danh.
    ///
    /// Thuật toán & Thiết kế:
    /// - Duyệt tuyến tính qua mảng `items`. Nếu tìm thấy `item.id == id`, trả về chỉ số `i`.
    /// - Trả về `null` nếu không tìm thấy.
    pub fn poolGet(_: *MicroUI, items: []c_microui.mu_PoolItem, id: c_uint) ?usize {
        for (items, 0..) |item, i| {
            if (item.id == id) {
                return i;
            }
        }
        return null;
    }

    /// Cập nhật thời điểm sử dụng gần nhất của phần tử trong pool với frame hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gán `items[idx].last_update = ctx.frame` nhằm phục vụ giải thuật LRU (Least Recently Used).
    pub fn poolUpdate(self: *MicroUI, items: []c_microui.mu_PoolItem, idx: usize) void {
        items[idx].last_update = @intCast(self.frame);
    }

    /// Khởi tạo hoặc tái sử dụng phần tử cũ nhất (LRU) trong pool cho một ID mới.
    ///
    /// Thuật toán & Thiết kế:
    /// - Duyệt tìm phần tử có `last_update` nhỏ nhất (lâu nhất chưa được truy cập).
    /// - Gán `id` mới cho slot đó và cập nhật thời gian sử dụng qua `poolUpdate`.
    /// - Trả về chỉ số slot được cấp phát.
    pub fn poolInit(self: *MicroUI, items: []c_microui.mu_PoolItem, id: c_uint) usize {
        var n: ?usize = null;
        var oldest_frame: i32 = @intCast(self.frame);
        for (items, 0..) |item, i| {
            if (item.last_update < oldest_frame) {
                oldest_frame = item.last_update;
                n = i;
            }
        }
        const idx = n orelse 0;
        items[idx].id = id;
        self.poolUpdate(items, idx);
        return idx;
    }

    /// Lấy hoặc cấp phát một container giao diện người dùng theo ID và cờ tùy chọn.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tìm kiếm ID trong `container_pool` qua `poolGet`:
    ///   + Nếu tìm thấy: cập nhật thời điểm sử dụng nếu container đang mở hoặc không có cờ `MU_OPT_CLOSED`.
    ///   + Trả về con trỏ tới container tương ứng.
    /// - Nếu không tìm thấy và có cờ `MU_OPT_CLOSED`: trả về `null`.
    /// - Cấp phát slot mới từ pool qua `poolInit`, xóa trắng dữ liệu struct `mu_Container`.
    /// - Thiết lập trạng thái `open = 1` và đưa lên lớp trên cùng qua `bringToFront`.
    pub fn getContainer(self: *MicroUI, id: c_uint, opt: c_int) ?*c_microui.mu_Container {
        const pool = &self.mu_context.*.container_pool;
        if (self.poolGet(pool, id)) |idx| {
            if (self.mu_context.*.containers[idx].open != 0 or ~opt & c_microui.MU_OPT_CLOSED != 0) {
                self.poolUpdate(pool, idx);
            }
            return &self.mu_context.*.containers[idx];
        }
        if (opt & c_microui.MU_OPT_CLOSED != 0) {
            return null;
        }
        const idx = self.poolInit(pool, id);
        const cnt = &self.mu_context.*.containers[idx];
        @memset(@as([*]u8, @ptrCast(cnt))[0..@sizeOf(c_microui.mu_Container)], 0);
        cnt.*.open = 1;
        self.bringToFront(cnt);
        return cnt;
    }

    /// Lấy con trỏ container bằng chuỗi định danh (tính ID băm từ tên rồi tìm container).
    ///
    /// Thuật toán & Thiết kế:
    /// - Băm chuỗi tên thành ID qua `getId(name.ptr, name.len)`.
    /// - Gọi `getContainer(id, 0)` để lấy hoặc khởi tạo container.
    pub fn getContainerByName(self: *MicroUI, name: [:0]const u8) ?*c_microui.mu_Container {
        const id = self.getId(name.ptr, @intCast(name.len));
        return self.getContainer(id, 0);
    }

    /// Lấy container hiện tại đang được xây dựng ở đỉnh ngăn xếp `container_stack`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra điều kiện biên `container_stack.idx > 0`.
    /// - Trả về phần tử tại chỉ số `container_stack.idx - 1`.
    pub fn getCurrentContainer(self: *MicroUI) *c_microui.mu_Container {
        return self.container_stack.getValue();
    }

    /// Đẩy thân container (body), tính toán thanh cuộn tự động và thiết lập layout bên trong.
    ///
    /// Thuật toán & Thiết kế:
    /// - Nếu không có cờ `MU_OPT_NOSCROLL`, gọi `scrollbars()` để trừ diện tích hiển thị thanh cuộn.
    /// - Đẩy layout mới với vùng hiển thị đã trừ khoảng đệm `padding` và độ lệch cuộn `cnt.scroll`.
    /// - Cập nhật `cnt.body = tmp_body`.
    pub fn pushContainerBody(self: *MicroUI, cnt: *c_microui.mu_Container, body: c_microui.mu_Rect, opt: c_int) void {
        var tmp_body = body;
        if (~opt & c_microui.MU_OPT_NOSCROLL != 0) {
            self.scrollbars(cnt, &tmp_body);
        }
        self.pushLayout(rawExpandRect(tmp_body, -self.mu_context.*.style.*.padding), cnt.*.scroll);
        cnt.*.body = tmp_body;
    }

    /// Đóng một container thông thường (Panel, Sub-view).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính toán kích thước nội dung `content_size = layout.max - layout.body` phục vụ thanh cuộn.
    /// - Giảm chỉ số ngăn xếp `container_stack.idx` và `layout_stack.idx`.
    /// - Pop ID tương ứng khỏi ID stack.
    pub fn popContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        const layout = self.getLayout();
        cnt.*.content_size.x = layout.*.max.x - layout.*.body.x;
        cnt.*.content_size.y = layout.*.max.y - layout.*.body.y;
        _ = self.container_stack.pop();
        _ = self.layout_stack.pop();
        self.popId();
    }

    /// Đưa một container lên trên cùng của trật tự Z-Index hiển thị.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gán `zindex = last_zindex + 1` cho container.
    /// - Cập nhật chỉ số `last_zindex += 1`.
    pub fn bringToFront(self: *MicroUI, cnt: *c_microui.mu_Container) void {
        cnt.*.zindex = self.last_zindex + 1;
        self.last_zindex += 1;
    }

    // =========================================================================
    // 8. SCROLLING & SCROLLBAR SYSTEM
    // =========================================================================

    /// Hướng trục của thanh cuộn.
    pub const ScrollbarAxis = enum {
        vertical,
        horizontal,
    };

    /// Xử lý logic tương tác và vẽ thanh cuộn (Scrollbar) cho một trục chỉ định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Xác định độ cuộn tối đa `maxscroll` dựa trên kích thước nội dung `cs` và kích thước khung hiển thị `body`.
    /// - Nếu nội dung vượt quá kích thước khung (`maxscroll > 0` và `body > 0`):
    ///   + Xác định định danh `id` ("!scrollbary" cho trục dọc, "!scrollbarx" cho trục ngang).
    ///   + Tính kích thước rãnh trượt `base` ở cạnh phải (dọc) hoặc cạnh dưới (ngang).
    ///   + Cập nhật tương tác điều khiển qua `updateControl()`.
    ///   + Nếu widget có focus và đang giữ chuột trái: cập nhật giá trị cuộn theo `mouse_delta`.
    ///   + Giới hạn độ cuộn trong khoảng `[0, maxscroll]` bằng `std.math.clamp`.
    ///   + Vẽ rãnh trượt `MU_COLOR_SCROLLBASE`.
    ///   + Tính toán vị trí và độ dài thanh trượt `thumb` (tỷ lệ với khung hiển thị, tối thiểu `thumb_size`).
    ///   + Vẽ thanh trượt `MU_COLOR_SCROLLTHUMB`.
    ///   + Gán container làm `scroll_target` nếu con trỏ chuột nằm trong `body`.
    /// - Nếu không cần cuộn: đặt độ cuộn của container về 0.
    pub fn scrollbar(
        self: *MicroUI,
        cnt: *c_microui.mu_Container,
        body: *c_microui.mu_Rect,
        cs: c_microui.mu_Vec2,
        axis: ScrollbarAxis,
    ) void {
        const sz = self.mu_context.*.style.*.scrollbar_size;
        switch (axis) {
            .vertical => {
                const maxscroll = cs.y - body.h;
                if (maxscroll > 0 and body.h > 0) {
                    const id = self.getId("!scrollbary", 11);
                    var base = body.*;
                    base.x = body.x + body.w;
                    base.w = sz;

                    self.updateControl(id, base, 0);
                    if (self.mu_context.*.focus == id and self.mouse_down == c_microui.MU_MOUSE_LEFT) {
                        cnt.scroll.y += @divTrunc(self.mu_context.*.mouse_delta.y * cs.y, base.h);
                    }
                    cnt.scroll.y = std.math.clamp(cnt.scroll.y, 0, maxscroll);

                    self.drawFrame(base, c_microui.MU_COLOR_SCROLLBASE);

                    var thumb = base;
                    thumb.h = @max(self.mu_context.*.style.*.thumb_size, @divTrunc(base.h * body.h, cs.y));
                    thumb.y += @divTrunc(cnt.scroll.y * (base.h - thumb.h), maxscroll);

                    self.drawFrame(thumb, c_microui.MU_COLOR_SCROLLTHUMB);

                    if (self.mouseOver(body.*)) {
                        self.mu_context.*.scroll_target = cnt;
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
                    if (self.mu_context.*.focus == id and self.mouse_down == c_microui.MU_MOUSE_LEFT) {
                        cnt.scroll.x += @divTrunc(self.mu_context.*.mouse_delta.x * cs.x, base.w);
                    }
                    cnt.scroll.x = std.math.clamp(cnt.scroll.x, 0, maxscroll);

                    self.drawFrame(base, c_microui.MU_COLOR_SCROLLBASE);

                    var thumb = base;
                    thumb.w = @max(self.mu_context.*.style.*.thumb_size, @divTrunc(base.w * body.w, cs.x));
                    thumb.x += @divTrunc(cnt.scroll.x * (base.w - thumb.w), maxscroll);

                    self.drawFrame(thumb, c_microui.MU_COLOR_SCROLLTHUMB);

                    if (self.mouseOver(body.*)) {
                        self.mu_context.*.scroll_target = cnt;
                    }
                } else {
                    cnt.scroll.x = 0;
                }
            },
        }
    }

    /// Tính toán và vẽ các thanh cuộn dọc và ngang tự động cho container.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cộng thêm khoảng đệm `padding * 2` vào kích thước nội dung `content_size`.
    /// - Đẩy `body` vào clip stack để đảm bảo thanh cuộn được vẽ trong giới hạn hiển thị.
    /// - Nếu nội dung vượt quá chiều cao: thu hẹp chiều rộng `body.w -= scrollbar_size` để chừa chỗ cho thanh cuộn dọc.
    /// - Nếu nội dung vượt quá chiều rộng: thu hẹp chiều cao `body.h -= scrollbar_size` cho thanh cuộn ngang.
    /// - Gọi hàm `scrollbar()` cho trục dọc và trục ngang.
    /// - Khôi phục vùng cắt qua `popClipRect()`.
    pub fn scrollbars(self: *MicroUI, cnt: *c_microui.mu_Container, body: *c_microui.mu_Rect) void {
        const sz = self.mu_context.*.style.*.scrollbar_size;
        var content_size = cnt.*.content_size;
        content_size.x += self.mu_context.*.style.*.padding * 2;
        content_size.y += self.mu_context.*.style.*.padding * 2;
        self.pushClipRect(body.*);
        if (content_size.y > body.h) {
            body.w -= sz;
        }
        if (content_size.x > body.w) {
            body.h -= sz;
        }
        self.scrollbar(cnt, body, content_size, .vertical);
        self.scrollbar(cnt, body, content_size, .horizontal);
        self.popClipRect();
    }

    // =========================================================================
    // 9. WINDOWS, PANELS & POPUPS
    // =========================================================================

    /// Bắt đầu một root container cấp cao nhất (Window, Popup).
    ///
    /// Thuật toán & Thiết kế:
    /// - Đẩy container vào `container_stack` và `root_list`.
    /// - Tạo command JUMP rỗng ở đầu (`cnt.head = pushJump(null)`).
    /// - Kiểm tra xem chuột có nằm trên container không và so sánh z-index với `next_hover_root`
    ///   để chọn root container nhận hover ưu tiên.
    /// - Đẩy vùng cắt bao phủ không gian tọa độ cực đại vào `clip_stack`.
    pub fn beginRootContainer(self: *MicroUI, cnt: *c_microui.mu_Container) void {
        self.container_stack.push(cnt);
        self.root_list.push(cnt);
        cnt.*.head = self.pushJump(null);
        if (rectOverlapsVec2(cnt.rect, self.mu_context.*.mouse_pos) and
            (self.mu_context.*.next_hover_root == null or cnt.*.zindex > self.mu_context.*.next_hover_root.*.zindex))
        {
            self.mu_context.*.next_hover_root = cnt;
        }
        self.clip_stack.push(c_microui.mu_rect(0, 0, 0x1000000, 0x1000000));
    }

    /// Kết thúc một root container cấp cao nhất (Window, Popup).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tạo command JUMP ở đuôi (`cnt.tail`) trỏ tới vị trí lệnh kế tiếp.
    /// - Nối con trỏ head sang đầu chuỗi command tiếp theo.
    /// - Rút clip rect và pop container khỏi stack.
    pub fn endRootContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        cnt.*.tail = self.pushJump(null);
        cnt.*.head.*.jump.dst = @ptrCast(&self.mu_context.*.command_list.items[@intCast(self.mu_context.*.command_list.idx)]);
        self.popClipRect();
        self.popContainer();
    }

    /// Bắt đầu một cửa sổ giao diện người dùng mới với các tùy chọn mặc định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `beginWindowEx(title, rect, 0)`.
    /// - Trả về `true` nếu cửa sổ đang mở và hiển thị nội dung bên trong, `false` nếu bị đóng.
    pub fn beginWindow(self: *MicroUI, title: [:0]const u8, rect: c_microui.mu_Rect) bool {
        return self.beginWindowEx(title, rect, 0);
    }

    /// Bắt đầu một cửa sổ giao diện người dùng mới với các cờ tùy chọn mở rộng.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ chuỗi `title` và lấy container qua `getContainer()`.
    /// - Nếu container không tồn tại hoặc đã bị đóng (`open == 0`), trả về `false`.
    /// - Đẩy ID vào `id_stack` và khởi tạo vị trí mặc định nếu chưa có kích thước.
    /// - Bắt đầu root container qua `beginRootContainer()`.
    /// - Vẽ nền cửa sổ (`MU_COLOR_WINDOWBG`) nếu không có cờ `MU_OPT_NOFRAME`.
    /// - Xử lý thanh tiêu đề nếu không có cờ `MU_OPT_NOTITLE`:
    ///   + Vẽ thanh tiêu đề `MU_COLOR_TITLEBG` với chiều cao `title_height`.
    ///   + Kéo thả cửa sổ: cập nhật tọa độ `cnt.rect` theo `mouse_delta` khi giữ chuột trái trên tiêu đề.
    ///   + Nút đóng (Close icon): chuyển trạng thái `cnt.open = 0` nếu người dùng click vào nút đóng.
    /// - Thiết lập layout thân cửa sổ qua `pushContainerBody()`.
    /// - Xử lý góc kéo giãn kích thước (Resize icon/grip) nếu không có cờ `MU_OPT_NORESIZE`.
    /// - Tự động co giãn theo nội dung nếu có cờ `MU_OPT_AUTOSIZE`.
    /// - Tự động đóng popup nếu click chuột ra ngoài cửa sổ khi có cờ `MU_OPT_POPUP`.
    /// - Đẩy vùng cắt của thân container vào clip stack và trả về `true`.
    pub fn beginWindowEx(self: *MicroUI, title: [:0]const u8, rect: c_microui.mu_Rect, opt: c_int) bool {
        const id = self.getId(title.ptr, @intCast(title.len));
        const cnt = self.getContainer(id, opt);
        if (cnt == null or cnt.?.open == 0) {
            return false;
        }
        self.id_stack.push(id);
        if (cnt.?.rect.w == 0) {
            cnt.?.rect = rect;
        }
        self.beginRootContainer(cnt.?);
        var body = cnt.?.rect;
        const local_rect = body;
        if (~opt & c_microui.MU_OPT_NOFRAME != 0) {
            self.drawFrame(local_rect, c_microui.MU_COLOR_WINDOWBG);
        }
        if (~opt & c_microui.MU_OPT_NOTITLE != 0) {
            var tr: c_microui.mu_Rect = local_rect;
            tr.h = self.mu_context.*.style.*.title_height;
            self.drawFrame(tr, c_microui.MU_COLOR_TITLEBG);

            // Xử lý kéo thả cửa sổ bằng thanh tiêu đề
            {
                const title_id = self.getId("!title", 6);
                self.updateControl(title_id, tr, opt);
                self.drawControlText(title, tr, c_microui.MU_COLOR_TITLETEXT, opt);
                if (title_id == self.mu_context.*.focus and self.mouse_down == c_microui.MU_MOUSE_LEFT) {
                    cnt.?.rect.x += self.mu_context.*.mouse_delta.x;
                    cnt.?.rect.y += self.mu_context.*.mouse_delta.y;
                }
                body.y += tr.h;
                body.h -= tr.h;
            }

            // Xử lý nút đóng cửa sổ
            if (~opt & c_microui.MU_OPT_NOCLOSE != 0) {
                const close_id = self.getId("!close", 6);
                const close_rect = c_microui.mu_rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h);
                tr.w -= close_rect.w;
                self.drawIcon(c_microui.MU_ICON_CLOSE, close_rect, self.mu_context.*.style.*.colors[0][c_microui.MU_COLOR_TITLETEXT]);
                self.updateControl(close_id, close_rect, opt);
                if (self.mouse_pressed == c_microui.MU_MOUSE_LEFT and close_id == self.mu_context.*.focus) {
                    cnt.?.open = 0;
                }
            }
        }
        self.pushContainerBody(cnt.?, body, opt);

        // Xử lý thay đổi kích thước cửa sổ
        if (~opt & c_microui.MU_OPT_NORESIZE != 0) {
            const size = self.mu_context.*.style.*.title_height;
            const resize_id = self.getId("!resize", 7);
            const resize_rect = c_microui.mu_rect(local_rect.x + local_rect.w - size, local_rect.y + local_rect.h - size, size, size);
            self.updateControl(resize_id, resize_rect, opt);
            if (resize_id == self.mu_context.*.focus and self.mouse_down == c_microui.MU_MOUSE_LEFT) {
                cnt.?.rect.w = @max(96, cnt.?.rect.w + self.mu_context.*.mouse_delta.x);
                cnt.?.rect.h = @max(64, cnt.?.rect.h + self.mu_context.*.mouse_delta.y);
            }
        }

        // Tự động khớp kích thước theo nội dung bên trong
        if (opt & c_microui.MU_OPT_AUTOSIZE != 0) {
            const r = self.getLayout().*.body;
            cnt.?.rect.w = cnt.?.content_size.x + (cnt.?.rect.w - r.w);
            cnt.?.rect.h = cnt.?.content_size.y + (cnt.?.rect.h - r.h);
        }

        // Đóng popup khi nhấn ra bên ngoài
        if (opt & c_microui.MU_OPT_POPUP != 0 and
            self.mouse_pressed != 0 and
            self.mu_context.*.hover_root != cnt)
        {
            cnt.?.open = 0;
        }

        self.pushClipRect(cnt.?.body);
        return c_microui.MU_RES_ACTIVE != 0;
    }

    /// Kết thúc định nghĩa cửa sổ hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Rút vùng cắt của thân cửa sổ qua `popClipRect()`.
    /// - Kết thúc root container qua `endRootContainer()`.
    pub fn endWindow(self: *MicroUI) void {
        self.popClipRect();
        self.endRootContainer();
    }

    /// Bắt đầu một bảng con (Panel) lồng bên trong container hiện tại với tùy chọn mặc định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `beginPanelEx(name, 0)`.
    pub fn beginPanel(self: *MicroUI, name: [:0]const u8) void {
        self.beginPanelEx(name, 0);
    }

    /// Bắt đầu một bảng con (Panel) lồng bên trong container hiện tại với tùy chọn `opt`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Đẩy ID tên bảng vào ID stack.
    /// - Lấy container tương ứng từ pool.
    /// - Đặt vùng rect cho panel theo ô layout tiếp theo (`layoutNext()`).
    /// - Vẽ nền bảng `MU_COLOR_PANELBG` nếu không có cờ `MU_OPT_NOFRAME`.
    /// - Đẩy container vào `container_stack` và thiết lập layout qua `pushContainerBody()`.
    /// - Đẩy vùng cắt của panel vào clip stack.
    pub fn beginPanelEx(self: *MicroUI, name: [:0]const u8, opt: c_int) void {
        self.pushId(name.ptr, @intCast(name.len));
        const cnt = self.getContainer(self.mu_context.*.last_id, opt) orelse return;
        cnt.*.rect = self.layoutNext();
        if (~opt & c_microui.MU_OPT_NOFRAME != 0) {
            self.drawFrame(cnt.*.rect, c_microui.MU_COLOR_PANELBG);
        }
        self.container_stack.push(cnt);
        self.pushContainerBody(cnt, cnt.*.rect, opt);
        self.pushClipRect(cnt.*.body);
    }

    /// Kết thúc bảng con (Panel).
    ///
    /// Thuật toán & Thiết kế:
    /// - Rút vùng cắt của panel qua `popClipRect()`.
    /// - Đóng container và đồng bộ kích thước nội dung qua `popContainer()`.
    pub fn endPanel(self: *MicroUI) void {
        self.popClipRect();
        self.popContainer();
    }

    /// Mở một menu popup ngữ cảnh tại vị trí con trỏ chuột hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lấy container tương ứng với tên popup từ pool.
    /// - Đặt làm `hover_root` và `next_hover_root` để ưu tiên tiếp nhận tương tác chuột.
    /// - Đặt vị trí popup tại tọa độ chuột `mouse_pos`, kích thước khởi đầu (1, 1).
    /// - Đặt trạng thái `open = 1` và đưa popup lên lớp trên cùng thông qua `bringToFront()`.
    pub fn openPopup(self: *MicroUI, name: [:0]const u8) void {
        const cnt = self.getContainerByName(name) orelse return;
        self.mu_context.*.hover_root = cnt;
        self.mu_context.*.next_hover_root = cnt;
        cnt.*.rect = c_microui.mu_rect(self.mu_context.*.mouse_pos.x, self.mu_context.*.mouse_pos.y, 1, 1);
        cnt.*.open = 1;
        self.bringToFront(cnt);
    }

    /// Bắt đầu khối nội dung cho menu popup đã mở.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cấu hình tập hợp cờ: `POPUP | AUTOSIZE | NORESIZE | NOSCROLL | NOTITLE | CLOSED`.
    /// - Gọi `beginWindowEx` với các cờ trên.
    /// - Trả về `MU_RES_ACTIVE` nếu popup đang mở, hoặc `0` nếu đóng.
    pub fn beginPopup(self: *MicroUI, name: [:0]const u8) c_int {
        const opt = c_microui.MU_OPT_POPUP | c_microui.MU_OPT_AUTOSIZE | c_microui.MU_OPT_NORESIZE |
            c_microui.MU_OPT_NOSCROLL | c_microui.MU_OPT_NOTITLE | c_microui.MU_OPT_CLOSED;
        return if (self.beginWindowEx(name, c_microui.mu_rect(0, 0, 0, 0), opt)) c_microui.MU_RES_ACTIVE else 0;
    }

    /// Kết thúc nội dung menu popup.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `endWindow()` để hoàn tất việc kết thúc popup container.
    pub fn endPopup(self: *MicroUI) void {
        self.endWindow();
    }

    // =========================================================================
    // 10. COLLAPSIBLE HEADERS & TREE NODES
    // =========================================================================

    /// Widget tiêu đề đề mục có thể thu gọn (Collapsible Header) với tùy chọn mặc định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `headerEx(label, 0)`.
    pub fn header(self: *MicroUI, label: [:0]const u8) c_int {
        return self.headerEx(label, 0);
    }

    /// Widget tiêu đề đề mục có thể thu gọn (Collapsible Header) với tùy chọn mở rộng.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới hàm nội bộ `headerInternal(label, false, opt)`.
    pub fn headerEx(self: *MicroUI, label: [:0]const u8, opt: c_int) c_int {
        return self.headerInternal(label, false, opt);
    }

    /// Trợ thủ nội bộ dùng chung cho cả Collapsible Header và Tree Node.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ chuỗi nhãn `label`.
    /// - Tra cứu trạng thái mở/đóng trong `treenode_pool`.
    /// - Thiết lập hàng bố cục toàn chiều rộng (`layoutRow(&[_]i32{-1}, 0)`).
    /// - Xử lý click chuột: đảo ngược trạng thái `active = !active` khi click vào widget.
    /// - Cập nhật hoặc xóa phần tử khỏi `treenode_pool`.
    /// - Vẽ hiệu ứng hover/button frame tương ứng.
    /// - Vẽ biểu tượng tam giác `MU_ICON_EXPANDED` hoặc `MU_ICON_COLLAPSED`.
    /// - Vẽ nhãn văn bản của tiêu đề.
    /// - Trả về `MU_RES_ACTIVE` nếu đề mục đang ở trạng thái mở.
    fn headerInternal(self: *MicroUI, label: [:0]const u8, is_treenode: bool, opt: c_int) c_int {
        const id = self.getId(label.ptr, @intCast(label.len));
        const pool = &self.mu_context.*.treenode_pool;
        const opt_idx = self.poolGet(pool, id);
        self.layoutRow(&[_]i32{-1}, 0);

        var active = (opt_idx != null);
        const expanded = if ((opt & c_microui.MU_OPT_EXPANDED) != 0) !active else active;
        var r = self.layoutNext();
        self.updateControl(id, r, 0);

        if (self.mouse_pressed == c_microui.MU_MOUSE_LEFT and self.mu_context.*.focus == id) {
            active = !active;
        }

        if (opt_idx) |idx| {
            if (active) {
                self.poolUpdate(pool, idx);
            } else {
                @memset(@as([*]u8, @ptrCast(&pool[idx]))[0..@sizeOf(c_microui.mu_PoolItem)], 0);
            }
        } else if (active) {
            _ = self.poolInit(pool, id);
        }

        if (is_treenode) {
            if (self.mu_context.*.hover == id) {
                self.drawFrame(r, c_microui.MU_COLOR_BUTTONHOVER);
            }
        } else {
            self.drawControlFrame(id, r, c_microui.MU_COLOR_BUTTON, 0);
        }

        const icon_id: c_int = if (expanded) c_microui.MU_ICON_EXPANDED else c_microui.MU_ICON_COLLAPSED;
        const colors = self.mu_context.*.style.*.colors;
        self.drawIcon(icon_id, c_microui.mu_rect(r.x, r.y, r.h, r.h), colors[c_microui.MU_COLOR_TEXT]);
        r.x += r.h - self.mu_context.*.style.*.padding;
        r.w -= r.h - self.mu_context.*.style.*.padding;
        self.drawControlText(label.ptr, r, c_microui.MU_COLOR_TEXT, 0);

        return if (expanded) c_microui.MU_RES_ACTIVE else 0;
    }

    /// Bắt đầu một nút cây thư mục (Tree Node) với tùy chọn mặc định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `beginTreenodeEx(name, 0)`.
    pub fn beginTreenode(self: *MicroUI, name: [:0]const u8) c_int {
        return self.beginTreenodeEx(name, 0);
    }

    /// Bắt đầu một nút cây thư mục (Tree Node) có khả năng đóng/mở nội dung con.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `headerInternal(label, true, opt)`.
    /// - Nếu trạng thái là Active (đang mở):
    ///   + Tăng khoảng lùi đầu dòng `indent += style.indent`.
    ///   + Đẩy ID của treenode vào ID stack để cô lập các widget con bên trong.
    /// - Trả về `MU_RES_ACTIVE` nếu đang mở, ngược lại trả về `0`.
    pub fn beginTreenodeEx(self: *MicroUI, label: [:0]const u8, opt: c_int) c_int {
        const res = self.headerInternal(label, true, opt);
        if ((res & c_microui.MU_RES_ACTIVE) != 0) {
            self.getLayout().*.indent += self.mu_context.*.style.*.indent;
            self.pushIdRaw(self.mu_context.*.last_id);
        }
        return res;
    }

    /// Kết thúc khối nội dung của nút cây thư mục.
    ///
    /// Thuật toán & Thiết kế:
    /// - Giảm khoảng lùi đầu dòng `indent -= style.indent`.
    /// - Rút ID của treenode khỏi ID stack qua `popId()`.
    pub fn endTreenode(self: *MicroUI) void {
        self.getLayout().*.indent -= self.mu_context.*.style.*.indent;
        self.popId();
    }

    // =========================================================================
    // 11. WIDGETS & CONTROLS
    // =========================================================================

    /// Hiển thị một nhãn văn bản (Label) đơn dòng tĩnh.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lấy vị trí hình chữ nhật kế tiếp từ `layoutNext()`.
    /// - Vẽ văn bản bằng `drawControlText` với màu `MU_COLOR_TEXT`.
    pub fn drawLabel(self: *MicroUI, label: [:0]const u8) void {
        self.drawControlText(label.ptr, self.layoutNext(), c_microui.MU_COLOR_TEXT, 0);
    }

    /// Hiển thị văn bản nhiều dòng với thuật toán tự động ngắt dòng theo từ (Word Wrap) và ký tự `\n`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra rỗng: nếu `text.len == 0`, dừng ngay để tránh out-of-bounds.
    /// - Khởi tạo một cột dọc riêng qua `layoutBeginColumn()` và `layoutEndColumn()`.
    /// - Thiết lập hàng có chiều cao bằng `text_height(font)`.
    /// - Quét qua chuỗi văn bản bằng con trỏ `p`:
    ///   + Duyệt từng từ (ngăn cách bởi khoảng trắng hoặc ký tự xuống dòng `\n`).
    ///   + Đo chiều rộng cộng dồn của các từ trên dòng hiện tại.
    ///   + Nếu tổng chiều rộng vượt quá `rect.w` và đã có ít nhất một từ trước đó trên dòng:
    ///     ngắt dòng tại đây và chuyển từ vừa quét sang dòng tiếp theo.
    ///   + Nếu gặp ký tự `\n`: lập tức hoàn tất dòng hiện tại và xuống dòng mới.
    ///   + Gọi `drawTextEx()` để vẽ lát cắt văn bản của dòng hiện tại (`text[line_start..line_end]`).
    pub fn drawText(self: *MicroUI, text: []const u8) void {
        self.layoutBeginColumn();
        defer self.layoutEndColumn();
        if (text.len == 0) return;

        const font = self.mu_context.*.style.*.font;
        self.layoutRow(&[_]i32{-1}, self.mu_context.*.text_height.?(font));
        const color = self.mu_context.*.style.*.colors[0][c_microui.MU_COLOR_TEXT];

        var p: usize = 0;
        while (p < text.len) {
            const rect = self.layoutNext();
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
                    w += self.mu_context.*.text_width.?(font, @ptrCast(&text[word_start]), @intCast(word_len));
                }
                if (w > rect.w and line_end != line_start) {
                    p = word_start;
                    break;
                }
                if (p < text.len) {
                    const sep = text[p];
                    w += self.mu_context.*.text_width.?(font, @ptrCast(&text[p]), 1);
                    line_end = p;
                    p += 1;
                    if (sep == '\n') break;
                } else {
                    line_end = p;
                }
            }
            if (line_end > line_start) {
                self.drawTextEx(font, text[line_start..line_end], c_microui.mu_vec2(rect.x, rect.y), color);
            }
        }
    }

    /// Widget nút bấm (Button) cơ bản với nhãn văn bản căn giữa.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `buttonEx(label, 0, MU_OPT_ALIGNCENTER)`.
    /// - Trả về `MU_RES_SUBMIT` nếu nút được click.
    pub fn button(self: *MicroUI, label: [:0]const u8) c_int {
        return self.buttonEx(label, 0, c_microui.MU_OPT_ALIGNCENTER);
    }

    /// Widget nút bấm (Button) mở rộng hỗ trợ biểu tượng và tùy chọn căn lề.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ nhãn `label` hoặc từ giá trị `icon` nếu không có nhãn.
    /// - Lấy vị trí rect tiếp theo qua `layoutNext()`.
    /// - Cập nhật trạng thái tương tác `updateControl()`.
    /// - Trả về `MU_RES_SUBMIT` nếu nút chuột trái vừa được click và widget đang giữ focus.
    /// - Vẽ nền nút qua `drawControlFrame(id, r, MU_COLOR_BUTTON, opt)` và nhãn/icon tương ứng.
    pub fn buttonEx(self: *MicroUI, label: ?[:0]const u8, icon: c_int, opt: c_int) c_int {
        var res: c_int = 0;
        const id = if (label) |l|
            self.getId(l.ptr, @intCast(l.len))
        else
            self.getId(&icon, @sizeOf(c_int));
        const r = self.layoutNext();
        self.updateControl(id, r, opt);
        if (self.mouse_pressed == c_microui.MU_MOUSE_LEFT and self.mu_context.*.focus == id) {
            res |= c_microui.MU_RES_SUBMIT;
        }
        self.drawControlFrame(id, r, c_microui.MU_COLOR_BUTTON, opt);
        if (label) |l| {
            self.drawControlText(l.ptr, r, c_microui.MU_COLOR_TEXT, opt);
        }
        if (icon != 0) {
            self.drawIcon(icon, r, self.mu_context.*.style.*.colors[0][c_microui.MU_COLOR_TEXT]);
        }
        return res;
    }

    /// Widget hộp kiểm (Checkbox) với nhãn đi kèm.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ địa chỉ con trỏ `value`.
    /// - Chia ô layout thành 2 phần: ô vuông checkbox kích thước `h x h` và phần nhãn văn bản còn lại.
    /// - Nếu chuột click vào ô kiểm: đảo ngược giá trị `value.* = if (value.* != 0) 0 else 1` và trả về `MU_RES_CHANGE`.
    /// - Vẽ khung base cho ô vuông, vẽ biểu tượng `MU_ICON_CHECK` nếu `value != 0`.
    /// - Vẽ nhãn văn bản bên cạnh.
    pub fn checkBox(self: *MicroUI, label: [:0]const u8, value: [*c]c_int) c_int {
        var res: c_int = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf([*c]c_int));
        const r = self.layoutNext();
        const box = c_microui.mu_rect(r.x, r.y, r.h, r.h);
        self.updateControl(id, r, 0);
        if (self.mouse_pressed == c_microui.MU_MOUSE_LEFT and self.mu_context.*.focus == id) {
            res |= c_microui.MU_RES_CHANGE;
            value.* = if (value.* != 0) 0 else 1;
        }
        self.drawControlFrame(id, box, c_microui.MU_COLOR_BASE, 0);
        if (value.* != 0) {
            self.drawIcon(c_microui.MU_ICON_CHECK, box, self.mu_context.*.style.*.colors[0][c_microui.MU_COLOR_TEXT]);
        }
        const text_rect = c_microui.mu_rect(r.x + box.w, r.y, r.w - box.w, r.h);
        self.drawControlText(label.ptr, text_rect, c_microui.MU_COLOR_TEXT, 0);
        return res;
    }

    /// Wrapper tiện ích gọi `textBox` với slice bộ đệm chuỗi Zig `[]u8`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Trả về 0 nếu slice rỗng.
    /// - Chuyển tiếp tới `textBox(text.ptr, text.len)` và ép kiểu kết quả về `usize`.
    pub fn drawTextBox(self: *MicroUI, text: []u8) usize {
        if (text.len == 0) return 0;
        return @as(usize, @intCast(self.textBox(text.ptr, @intCast(text.len))));
    }

    /// Widget hộp nhập văn bản (Textbox) cơ bản.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `textBoxEx(text, len, 0)`.
    pub fn textBox(self: *MicroUI, text: [*c]u8, len: c_int) c_int {
        return self.textBoxEx(text, len, 0);
    }

    /// Widget hộp nhập văn bản (Textbox) mở rộng với ID cố định theo địa chỉ vùng nhớ buffer.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID bằng cách băm trực tiếp địa chỉ con trỏ của vùng đệm (`@intFromPtr(text)`).
    ///   Thuật toán này đảm bảo ID không bị thay đổi giữa các frame khi các ký tự bên trong buffer thay đổi,
    ///   giúp widget giữ nguyên tiêu điểm nhập liệu (focus) xuyên suốt phiên gõ phím.
    /// - Lấy vị trí từ layout và gọi `textBoxRaw()`.
    pub fn textBoxEx(self: *MicroUI, text: [*c]u8, len: c_int, opt: c_int) c_int {
        const addr = @intFromPtr(text);
        const id = self.getId(@ptrCast(&addr), @sizeOf(usize));
        const rect = self.layoutNext();
        return self.textBoxRaw(text, len, id, rect, opt);
    }

    /// Hàm xử lý cấp thấp cho hộp nhập văn bản (Textbox).
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `updateControl` với cờ `MU_OPT_HOLDFOCUS` để duy trì tiêu điểm khi click vào textbox.
    /// - Khi widget đang giữ tiêu điểm (`focus == id`):
    ///   + Nhận ký tự mới từ `ctx.input_text`, ghép vào cuối `buf` nếu còn dung lượng và đặt cờ `MU_RES_CHANGE`.
    ///   + Bắt phím Backspace: xóa ký tự đứng trước, lùi qua các continuation byte của UTF-8 (`(byte & 0xc0) == 0x80`).
    ///   + Bắt phím Enter / Return: hủy tiêu điểm (`setFocus(0)`) và đặt cờ `MU_RES_SUBMIT`.
    /// - Vẽ khung nền widget bằng `drawControlFrame(id, rect, MU_COLOR_BASE, opt)`.
    /// - Nếu widget đang có tiêu điểm:
    ///   + Tính toán vị trí hiển thị text và con trỏ cursor nhấp nháy dựa trên độ rộng `text_width` và padding.
    ///   + Giới hạn vùng vẽ qua `pushClipRect(rect)` và vẽ text + con trỏ dọc (1px).
    /// - Nếu không có tiêu điểm:
    ///   + Vẽ text tĩnh thông qua `drawControlText`.
    pub fn textBoxRaw(self: *MicroUI, buf: [*c]u8, bufsz: c_int, id: c_uint, rect: c_microui.mu_Rect, opt: c_int) c_int {
        var res: c_int = 0;
        self.updateControl(id, rect, opt | c_microui.MU_OPT_HOLDFOCUS);

        if (self.mu_context.*.focus == id) {
            // Xử lý text input
            var len: usize = std.mem.len(buf);
            const input_slice = std.mem.sliceTo(&self.mu_context.*.input_text, 0);
            if (bufsz > @as(c_int, @intCast(len)) + 1) {
                const avail: usize = @intCast(bufsz - @as(c_int, @intCast(len)) - 1);
                const n = @min(avail, input_slice.len);
                if (n > 0) {
                    @memcpy(buf[len .. len + n], input_slice[0..n]);
                    len += n;
                    buf[len] = 0;
                    res |= c_microui.MU_RES_CHANGE;
                }
            }

            // Xử lý backspace (hỗ trợ xóa đa byte UTF-8)
            if ((self.key_pressed & c_microui.MU_KEY_BACKSPACE) != 0 and len > 0) {
                len -= 1;
                while (len > 0 and (buf[len] & 0xc0) == 0x80) {
                    len -= 1;
                }
                buf[len] = 0;
                res |= c_microui.MU_RES_CHANGE;
            }

            // Xử lý phím Enter / Return
            if ((self.key_pressed & c_microui.MU_KEY_RETURN) != 0) {
                self.setFocus(0);
                res |= c_microui.MU_RES_SUBMIT;
            }
        }

        // Vẽ widget
        self.drawControlFrame(id, rect, c_microui.MU_COLOR_BASE, opt);
        if (self.mu_context.*.focus == id) {
            const colors = self.mu_context.*.style.*.colors;
            const color = colors[c_microui.MU_COLOR_TEXT];
            const font = self.mu_context.*.style.*.font;
            const text_span = std.mem.span(buf);
            const textw = if (self.mu_context.*.text_width) |tw_fn|
                tw_fn(font, buf, @intCast(text_span.len))
            else
                0;
            const texth = if (self.mu_context.*.text_height) |th_fn|
                th_fn(font)
            else
                0;
            const padding = self.mu_context.*.style.*.padding;
            const ofx = rect.w - padding - textw - 1;
            const textx = rect.x + @min(ofx, padding);
            const texty = rect.y + @divTrunc(rect.h - texth, 2);

            self.pushClipRect(rect);
            self.drawTextEx(font, text_span, .{ .x = textx, .y = texty }, color);
            self.drawRect(.{ .x = textx + textw, .y = texty, .w = 1, .h = texth }, color);
            self.popClipRect();
        } else {
            self.drawControlText(buf, rect, c_microui.MU_COLOR_TEXT, opt);
        }

        return res;
    }

    /// Trợ thủ nội bộ chuyển đổi slider hoặc number box thành hộp nhập liệu khi người dùng Shift+Click.
    ///
    /// Thuật toán & Thiết kế:
    /// - Nếu chuột click kèm phím Shift: kích hoạt chế độ chỉnh sửa số (`number_edit = id`), định dạng giá trị thành chuỗi.
    /// - Nếu widget đang ở chế độ chỉnh sửa: hiển thị textbox trực tiếp; khi nhấn Enter hoặc mất focus, chuyển đổi chuỗi ngược về float qua `strtod`.
    fn numberTextbox(self: *MicroUI, value: *f32, r: c_microui.mu_Rect, id: c_uint) bool {
        if (self.mouse_pressed == c_microui.MU_MOUSE_LEFT and
            (self.key_down & c_microui.MU_KEY_SHIFT) != 0 and
            self.mu_context.*.hover == id)
        {
            self.mu_context.*.number_edit = id;
            _ = sprintf(&self.mu_context.*.number_edit_buf, c_microui.MU_REAL_FMT, @as(f64, value.*));
        }
        if (self.mu_context.*.number_edit == id) {
            const res = self.textBoxRaw(
                @ptrCast(&self.mu_context.*.number_edit_buf),
                @sizeOf(@TypeOf(self.mu_context.*.number_edit_buf)),
                id,
                r,
                0,
            );
            if ((res & c_microui.MU_RES_SUBMIT) != 0 or self.mu_context.*.focus != id) {
                value.* = @floatCast(strtod(&self.mu_context.*.number_edit_buf, null));
                self.mu_context.*.number_edit = 0;
            } else {
                return true;
            }
        }
        return false;
    }

    /// Widget thanh trượt (Slider) cơ bản trong khoảng [low, high].
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `sliderEx(value, low, high, 0, MU_SLIDER_FMT, MU_OPT_ALIGNCENTER)`.
    pub fn slider(self: *MicroUI, value: *f32, low: f32, high: f32) c_int {
        return self.sliderEx(value, low, high, 0, c_microui.MU_SLIDER_FMT, c_microui.MU_OPT_ALIGNCENTER);
    }

    /// Widget thanh trượt (Slider) mở rộng với bước nhảy (step) và định dạng hiển thị số.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ con trỏ `value`.
    /// - Kiểm tra chế độ nhập liệu số `numberTextbox()`.
    /// - Cập nhật tương tác qua `updateControl()`.
    /// - Nếu đang kéo chuột trái trên slider:
    ///   + Nội suy giá trị mới theo tỷ lệ vị trí chuột trên thanh: `v = low + (mouse.x - base.x) * (high - low) / base.w`.
    ///   + Làm tròn giá trị theo bước nhảy `step` nếu có.
    /// - Giới hạn giá trị trong khoảng `[low, high]` bằng `std.math.clamp`.
    /// - Vẽ rãnh trượt `base`, tính vị trí nút trượt `thumb` và vẽ nút trượt.
    /// - Hiển thị giá trị số dạng text căn giữa trên slider.
    pub fn sliderEx(self: *MicroUI, value: *f32, low: f32, high: f32, step: f32, fmt: [*c]const u8, opt: c_int) c_int {
        var buf: [c_microui.MU_MAX_FMT + 1]u8 = undefined;
        var res: c_int = 0;
        const last = value.*;
        var v = last;
        const id = self.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = self.layoutNext();

        if (self.numberTextbox(&v, base, id)) {
            return res;
        }

        self.updateControl(id, base, opt);

        if (self.mu_context.*.focus == id and
            ((self.mouse_down | self.mouse_pressed) & c_microui.MU_MOUSE_LEFT) != 0)
        {
            if (base.w > 0) {
                v = low + @as(f32, @floatFromInt(self.mu_context.*.mouse_pos.x - base.x)) * (high - low) / @as(f32, @floatFromInt(base.w));
                if (step > 0) {
                    v = @round((v + step / 2.0) / step) * step;
                }
            }
        }

        v = std.math.clamp(v, low, high);
        value.* = v;
        if (last != v) {
            res |= c_microui.MU_RES_CHANGE;
        }

        self.drawControlFrame(id, base, c_microui.MU_COLOR_BASE, opt);

        const w = self.mu_context.*.style.*.thumb_size;
        const x: i32 = if (high > low)
            @intFromFloat((v - low) * @as(f32, @floatFromInt(base.w - w)) / (high - low))
        else
            0;
        const thumb = c_microui.mu_rect(base.x + x, base.y, w, base.h);
        self.drawControlFrame(id, thumb, c_microui.MU_COLOR_BUTTON, opt);

        _ = sprintf(&buf, fmt, @as(f64, v));
        self.drawControlText(&buf, base, c_microui.MU_COLOR_TEXT, opt);

        return res;
    }

    /// Widget ô số có thể kéo điều chỉnh (Number) cơ bản với bước nhảy `step`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Chuyển tiếp tới `numberEx(value, step, MU_SLIDER_FMT, MU_OPT_ALIGNCENTER)`.
    pub fn number(self: *MicroUI, value: *f32, step: f32) c_int {
        return self.numberEx(value, step, c_microui.MU_SLIDER_FMT, c_microui.MU_OPT_ALIGNCENTER);
    }

    /// Widget ô số có thể kéo điều chỉnh (Number) mở rộng.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ địa chỉ con trỏ `value`.
    /// - Kiểm tra chế độ nhập liệu số `numberTextbox()`.
    /// - Cập nhật tương tác qua `updateControl()`.
    /// - Khi giữ chuột trái và kéo ngang: cộng dồn độ dịch chuyển chuột `mouse_delta.x * step` vào `value`.
    /// - Bật cờ `MU_RES_CHANGE` nếu giá trị thay đổi.
    /// - Vẽ khung nền và nhãn số hiển thị.
    pub fn numberEx(self: *MicroUI, value: *f32, step: f32, fmt: [*c]const u8, opt: c_int) c_int {
        var buf: [c_microui.MU_MAX_FMT + 1]u8 = undefined;
        var res: c_int = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = self.layoutNext();
        const last = value.*;

        if (self.numberTextbox(value, base, id)) {
            return res;
        }

        self.updateControl(id, base, opt);

        if (self.mu_context.*.focus == id and (self.mouse_down & c_microui.MU_MOUSE_LEFT) != 0) {
            value.* += @as(f32, @floatFromInt(self.mu_context.*.mouse_delta.x)) * step;
        }

        if (value.* != last) {
            res |= c_microui.MU_RES_CHANGE;
        }

        self.drawControlFrame(id, base, c_microui.MU_COLOR_BASE, opt);

        _ = sprintf(&buf, fmt, @as(f64, value.*));
        self.drawControlText(&buf, base, c_microui.MU_COLOR_TEXT, opt);

        return res;
    }
};
