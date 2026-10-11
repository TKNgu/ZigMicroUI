const std = @import("std");
const c_microui = @import("c_microui");

pub const MicroUI = struct {
    mu_context: *c_microui.mu_Context,

    // =========================================================================
    // 1. LIFECYCLE & CORE
    // =========================================================================

    /// Khởi tạo instance MicroUI và phân bổ bộ nhớ cho `mu_Context`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cấp phát bộ nhớ heap cho struct `mu_Context` thông qua allocator được truyền vào.
    /// - Gọi `mu_init()` từ thư viện C để thiết lập các giá trị mặc định cho style, bảng màu và bộ đệm.
    /// - Gán các hàm callback đo kích thước font (`text_width`, `text_height`) vào context.
    /// - Sử dụng `errdefer` để đảm bảo giải phóng bộ nhớ nếu có lỗi xảy ra trong quá trình khởi tạo.
    pub fn init(
        allocator: std.mem.Allocator,
        text_width: fn (font: c_microui.mu_Font, text: [*c]const u8, len: c_int) callconv(.c) c_int,
        text_height: fn (font: c_microui.mu_Font) callconv(.c) c_int,
    ) !MicroUI {
        const ctx = try allocator.create(c_microui.mu_Context);
        errdefer allocator.destroy(ctx);

        c_microui.mu_init(ctx);
        ctx.*.text_width = text_width;
        ctx.*.text_height = text_height;

        return .{
            .mu_context = ctx,
        };
    }

    /// Hủy instance MicroUI và giải phóng tài nguyên.
    ///
    /// Thuật toán & Thiết kế:
    /// - Hủy bộ nhớ `mu_Context` đã cấp phát ban đầu thông qua allocator.
    pub fn deinit(self: *MicroUI, allocator: std.mem.Allocator) void {
        allocator.destroy(self.mu_context);
    }

    /// Bắt đầu một frame giao diện mới.
    ///
    /// Thuật toán & Thiết kế:
    /// - Reset chỉ số danh sách lệnh (`command_list.idx = 0`).
    /// - Reset các ngăn xếp (`root_list`, `container_stack`, `clip_stack`, `id_stack`, `layout_stack`).
    /// - Thiết lập vùng cắt mặc định phủ toàn bộ không gian tọa độ.
    /// - Tăng chỉ số frame hiện tại (`frame += 1`).
    pub fn begin(self: *MicroUI) void {
        c_microui.mu_begin(self.mu_context);
    }

    /// Kết thúc frame giao diện và liên kết các lệnh render của các root container.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra tính toàn vẹn của các ngăn xếp container, clip rect và id.
    /// - Duyệt ngược danh sách `root_list` (từ lớp nền lên lớp trên cùng):
    ///   + Thiết lập lệnh JUMP từ tail của container trước sang head của container sau.
    ///   + Đảm bảo luồng render duyệt qua đúng thứ tự z-index của các cửa sổ.
    /// - Cập nhật trạng thái chuột và phím (`mouse_pressed = 0`, `key_pressed = 0`, `input_text = ""`).
    pub fn end(self: *MicroUI) void {
        c_microui.mu_end(self.mu_context);
    }

    // =========================================================================
    // 2. INPUT HANDLING
    // =========================================================================

    /// Cập nhật tọa độ con trỏ chuột.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu trực tiếp tọa độ (x, y) vào `ctx.mouse_pos`.
    pub fn inputMousemove(self: *MicroUI, x: c_int, y: c_int) void {
        self.mu_context.*.mouse_pos = c_microui.mu_vec2(x, y);
    }

    /// Xử lý sự kiện nhấn nút chuột.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cập nhật vị trí chuột hiện tại qua `inputMousemove`.
    /// - Bật bit trạng thái giữ chuột (`mouse_down |= btn`).
    /// - Bật bit trạng thái vừa nhấn trong frame này (`mouse_pressed |= btn`).
    pub fn inputMousedown(self: *MicroUI, x: c_int, y: c_int, btn: c_int) void {
        self.inputMousemove(x, y);
        self.mu_context.*.mouse_down |= btn;
        self.mu_context.*.mouse_pressed |= btn;
    }

    /// Xử lý sự kiện nhả nút chuột.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cập nhật vị trí chuột hiện tại.
    /// - Tắt bit trạng thái giữ chuột (`mouse_down &= ~btn`).
    pub fn inputMouseup(self: *MicroUI, x: c_int, y: c_int, btn: c_int) void {
        self.inputMousemove(x, y);
        self.mu_context.*.mouse_down &= ~btn;
    }

    /// Xử lý sự kiện cuộn chuột.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cộng dồn độ lệch cuộn (x, y) vào `scroll_delta` để xử lý cuộn khung nhìn ở frame hiện tại.
    pub fn inputScroll(self: *MicroUI, x: c_int, y: c_int) void {
        self.mu_context.*.scroll_delta.x += x;
        self.mu_context.*.scroll_delta.y += y;
    }

    /// Xử lý sự kiện nhấn phím từ bàn phím.
    ///
    /// Thuật toán & Thiết kế:
    /// - Bật bit trạng thái phím vừa nhấn (`key_pressed |= key`) cho các thao tác tác vụ (Return, Backspace...).
    /// - Bật bit phím đang giữ (`key_down |= key`) cho các phím bổ trợ (Shift, Ctrl, Alt...).
    pub fn inputKeydown(self: *MicroUI, key: c_int) void {
        self.mu_context.*.key_pressed |= key;
        self.mu_context.*.key_down |= key;
    }

    /// Xử lý sự kiện nhả phím bàn phím.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tắt bit trạng thái giữ phím (`key_down &= ~key`).
    pub fn inputKeyup(self: *MicroUI, key: c_int) void {
        self.mu_context.*.key_down &= ~key;
    }

    /// Tiếp nhận chuỗi ký tự UTF-8 từ sự kiện text input của hệ thống cửa sổ (SDL).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính toán chiều dài ký tự hiện có trong `input_text` buffer.
    /// - Nối các byte ký tự mới vào cuối buffer nếu còn đủ dung lượng.
    /// - Luôn đảm bảo ký tự kết thúc chuỗi null-terminator `0` ở cuối.
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

    /// Tính giao giữa 2 hình chữ nhật (AABB intersection).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính `x1 = max(r1.x, r2.x)`, `y1 = max(r1.y, r2.y)`.
    /// - Tính `x2 = min(r1.x + r1.w, r2.x + r2.w)`, `y2 = min(r1.y + r1.h, r2.y + r2.h)`.
    /// - Nếu `x2 < x1` hoặc `y2 < y1`: 2 hình không giao nhau, trả về rect kích thước 0.
    /// - Ngược lại, trả về hình chữ nhật có góc `(x1, y1)` và kích thước `(x2 - x1, y2 - y1)`.
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
    /// - Lấy clip rect đỉnh stack qua `getClipRect()`.
    /// - Trả về `MU_CLIP_ALL` (hoàn toàn ngoài biên) nếu `r` không giao với `clip_rect`.
    /// - Trả về `0` (hoàn toàn trong biên) nếu `r` nằm trọn vẹn bên trong `clip_rect`.
    /// - Trả về `MU_CLIP_PART` (cắt một phần) nếu `r` chỉ giao nhau một phần.
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

    /// Lấy hình chữ nhật giới hạn cắt hiện tại ở đỉnh stack.
    ///
    /// Thuật toán & Thiết kế:
    /// - Assert stack clip không rỗng (`clip_stack.idx > 0`).
    /// - Trả về phần tử tại chỉ số `clip_stack.idx - 1`.
    pub fn getClipRect(self: *MicroUI) c_microui.mu_Rect {
        std.debug.assert(self.mu_context.*.clip_stack.idx > 0);
        return self.mu_context.*.clip_stack.items[@intCast(self.mu_context.*.clip_stack.idx - 1)];
    }

    /// Đẩy một vùng cắt mới vào stack và tính giao với vùng cắt hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lấy vùng cắt trước đó `last = getClipRect()`.
    /// - Tính `intersectRects(rect, last)`.
    /// - Đẩy kết quả vào `clip_stack` và tăng `clip_stack.idx`.
    pub fn pushClipRect(self: *MicroUI, rect: c_microui.mu_Rect) void {
        const last = self.getClipRect();
        std.debug.assert(self.mu_context.*.clip_stack.idx < self.mu_context.*.clip_stack.items.len);
        self.mu_context.*.clip_stack.items[@intCast(self.mu_context.*.clip_stack.idx)] = intersectRects(rect, last);
        self.mu_context.*.clip_stack.idx += 1;
    }

    /// Rút vùng cắt gần nhất khỏi stack.
    ///
    /// Thuật toán & Thiết kế:
    /// - Giảm `clip_stack.idx` đi 1 đơn vị sau khi assert stack hợp lệ.
    pub fn popClipRect(self: *MicroUI) void {
        std.debug.assert(self.mu_context.*.clip_stack.idx > 0);
        self.mu_context.*.clip_stack.idx -= 1;
    }

    /// Đưa lệnh thiết lập vùng cắt vào bộ đệm lệnh vẽ.
    ///
    /// Thuật toán & Thiết kế:
    /// - Đẩy command `MU_COMMAND_CLIP` với kích thước `mu_ClipCommand` vào buffer.
    /// - Gán trường `clip.rect = rect`.
    pub fn setClip(self: *MicroUI, rect: c_microui.mu_Rect) void {
        const cmd = self.pushCommand(c_microui.MU_COMMAND_CLIP, @sizeOf(c_microui.mu_ClipCommand));
        cmd.*.clip.rect = rect;
    }

    /// Xóa bỏ giới hạn cắt, khôi phục không gian hiển thị tối đa.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `setClip` với rect bao trùm tọa độ từ 0 đến 0x1000000.
    pub fn setClipUnclipped(self: *MicroUI) void {
        self.setClip(c_microui.mu_rect(0, 0, 0x1000000, 0x1000000));
    }

    /// Cấp phát và ghi một lệnh vẽ mới vào mảng lệnh tuyến tính (`command_list`).
    ///
    /// Thuật toán & Thiết kế:
    /// - Căn chỉnh kích thước lệnh theo bội số của 8 byte (`(size + 7) & ~7`) để đảm bảo alignment bộ nhớ.
    /// - Assert dung lượng `command_list` còn đủ chỗ chứa.
    /// - Thiết lập `base.type = cmd_type` và `base.size = aligned_size`.
    /// - Tăng chỉ số ghi `command_list.idx` và trả về con trỏ tới struct command.
    pub fn pushCommand(self: *MicroUI, cmd_type: c_int, size: c_int) [*c]c_microui.mu_Command {
        const cmd: [*c]c_microui.mu_Command = @ptrCast(@alignCast(&self.mu_context.*.command_list.items[@intCast(self.mu_context.*.command_list.idx)]));
        const aligned_size = (size + 7) & ~@as(c_int, 7);
        std.debug.assert(self.mu_context.*.command_list.idx + aligned_size < self.mu_context.*.command_list.items.len);
        cmd.*.base.type = cmd_type;
        cmd.*.base.size = aligned_size;
        self.mu_context.*.command_list.idx += aligned_size;
        return cmd;
    }

    /// Đẩy lệnh JUMP để chuyển tiếp luồng duyệt command list đến một vị trí đích.
    ///
    /// Thuật toán & Thiết kế:
    /// - Cấp phát một command `MU_COMMAND_JUMP` trong command buffer.
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
    /// - Nếu `cmd.* != null`: bước tới con trỏ kế tiếp dựa trên `cmd.base.size`.
    /// - Duyệt qua và giải quyết các bước nhảy `MU_COMMAND_JUMP` bằng cách chuyển con trỏ tới `jump.dst`.
    /// - Dừng lại và trả về 1 khi gặp lệnh vẽ hợp lệ (Rect, Text, Icon, Clip).
    /// - Trả về 0 khi đã duyệt hết toàn bộ chuỗi lệnh đến `end_ptr`.
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
    /// - Tính giao giữa `rect` và `getClipRect()`.
    /// - Nếu hình chữ nhật giao nhau có diện tích dương (`w > 0 and h > 0`):
    ///   + Tạo command `MU_COMMAND_RECT`.
    ///   + Gán tọa độ đã cắt và màu sắc tương ứng.
    pub fn drawRect(self: *MicroUI, rect: c_microui.mu_Rect, color: c_microui.mu_Color) void {
        const tmp_rect = intersectRects(rect, self.getClipRect());
        if (tmp_rect.w > 0 and tmp_rect.h > 0) {
            const cmd = self.pushCommand(c_microui.MU_COMMAND_RECT, @sizeOf(c_microui.mu_RectCommand));
            cmd.*.rect.rect = tmp_rect;
            cmd.*.rect.color = color;
        }
    }

    /// Đẩy lệnh vẽ biểu tượng (Icon) vào command buffer.
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính giao giữa `rect` của icon và `getClipRect()`.
    /// - Nếu nằm trong vùng hiển thị:
    ///   + Tạo command `MU_COMMAND_ICON`.
    ///   + Lưu ID icon, kích thước và màu sắc vào struct command.
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
    /// - Đo bề rộng chuỗi bằng callback `text_width`.
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
    /// - Thực thi hàm `draw_frame` của context để render khung chữ nhật bo góc hoặc phẳng.
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
        if (self.mu_context.*.draw_frame) |draw_frame_fn| {
            draw_frame_fn(self.mu_context, rect, color);
        }
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
        const idx = self.mu_context.*.id_stack.idx;
        var res: u32 = if (idx > 0) self.mu_context.*.id_stack.items[@intCast(idx - 1)] else 2166136261;
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
        std.debug.assert(self.mu_context.*.id_stack.idx < self.mu_context.*.id_stack.items.len);
        self.mu_context.*.id_stack.items[@intCast(self.mu_context.*.id_stack.idx)] = id;
        self.mu_context.*.id_stack.idx += 1;
    }

    /// Đẩy trực tiếp một ID có sẵn vào ID stack mà không băm lại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu giá trị `id` thô vào đỉnh `id_stack` và tăng `id_stack.idx`.
    pub fn pushIdRaw(self: *MicroUI, id: c_uint) void {
        std.debug.assert(self.mu_context.*.id_stack.idx < self.mu_context.*.id_stack.items.len);
        self.mu_context.*.id_stack.items[@intCast(self.mu_context.*.id_stack.idx)] = id;
        self.mu_context.*.id_stack.idx += 1;
    }

    /// Rút ID trên cùng khỏi ID stack.
    ///
    /// Thuật toán & Thiết kế:
    /// - Giảm `id_stack.idx` đi 1 đơn vị sau khi assert stack không rỗng.
    pub fn popId(self: *MicroUI) void {
        std.debug.assert(self.mu_context.*.id_stack.idx > 0);
        self.mu_context.*.id_stack.idx -= 1;
    }

    /// Đặt trạng thái Focus (tiêu điểm bàn phím/chuột) cho widget có ID chỉ định.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu `id` vào `ctx.focus`.
    /// - Đánh dấu cờ `updated_focus = 1` để giữ focus không bị reset ở cuối frame.
    pub fn setFocus(self: *MicroUI, id: c_uint) void {
        self.mu_context.*.focus = id;
        self.mu_context.*.updated_focus = 1;
    }

    /// Kiểm tra container hiện tại có thuộc cây cửa sổ đang nhận tương tác chuột hay không.
    ///
    /// Thuật toán & Thiết kế:
    /// - Duyệt ngược từ đỉnh `container_stack` xuống dưới:
    ///   + Nếu gặp container trùng với `hover_root`, trả về `true`.
    ///   + Dừng lại khi chạm tới gốc của một cửa sổ (`cnt.head != null`).
    /// - Trả về `false` nếu không thuộc phân cấp `hover_root`.
    pub fn inHoverRoot(self: *MicroUI) bool {
        var i = self.mu_context.*.container_stack.idx;
        while (i > 0) {
            i -= 1;
            const cnt = self.mu_context.*.container_stack.items[@intCast(i)];
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
            self.mu_context.*.updated_focus = 1;
        }
        if ((opt & c_microui.MU_OPT_NOINTERACT) != 0) {
            return;
        }
        if (mouseover and self.mu_context.*.mouse_down == 0) {
            self.mu_context.*.hover = id;
        }

        if (self.mu_context.*.focus == id) {
            if (self.mu_context.*.mouse_pressed != 0 and !mouseover) {
                self.setFocus(0);
            }
            if (self.mu_context.*.mouse_down == 0 and (~opt & c_microui.MU_OPT_HOLDFOCUS) != 0) {
                self.setFocus(0);
            }
        }

        if (self.mu_context.*.hover == id) {
            if (self.mu_context.*.mouse_pressed != 0) {
                self.setFocus(id);
            } else if (!mouseover) {
                self.mu_context.*.hover = 0;
            }
        }
    }

    // =========================================================================
    // 6. LAYOUT SYSTEM
    // =========================================================================

    /// Lấy con trỏ tới thông tin bố cục (`mu_Layout`) hiện tại ở đỉnh stack.
    ///
    /// Thuật toán & Thiết kế:
    /// - Trả về địa chỉ của phần tử tại chỉ số `layout_stack.idx - 1`.
    pub fn getLayout(self: *MicroUI) *c_microui.mu_Layout {
        return &self.mu_context.*.layout_stack.items[@intCast(self.mu_context.*.layout_stack.idx - 1)];
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
        std.debug.assert(self.mu_context.*.layout_stack.idx < self.mu_context.*.layout_stack.items.len);
        self.mu_context.*.layout_stack.items[@intCast(self.mu_context.*.layout_stack.idx)] = layout;
        self.mu_context.*.layout_stack.idx += 1;
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
    pub fn layoutWidth(self: *MicroUI, width: i32) void {
        self.getLayout().*.size.x = width;
    }

    /// Ghi đè chiều cao cho hàng hiện tại.
    pub fn layoutHeight(self: *MicroUI, height: i32) void {
        self.getLayout().*.size.y = height;
    }

    /// Đặt trước vị trí/kích thước hình chữ nhật cho widget kế tiếp (manual placement).
    ///
    /// Thuật toán & Thiết kế:
    /// - Lưu `r` vào `layout.next`.
    /// - Gán `next_type = 1` nếu tọa độ tương đối theo container, hoặc `2` nếu là tọa độ tuyệt đối.
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
    ///   + Giá trị <= 0: tính kích thước tương đối dựa theo chiều rộng còn lại của container (`body.w - res.x + 1`).
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

    /// Bắt đầu một cột dọc phụ lồng bên trong hàng hiện tại.
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
        const b = self.getLayout().*;
        std.debug.assert(self.mu_context.*.layout_stack.idx > 0);
        self.mu_context.*.layout_stack.idx -= 1;
        const a = self.getLayout();
        a.*.position.x = @max(a.*.position.x, b.position.x + b.body.x - a.*.body.x);
        a.*.next_row = @max(a.*.next_row, b.next_row + b.body.y - a.*.body.y);
        a.*.max.x = @max(a.*.max.x, b.max.x);
        a.*.max.y = @max(a.*.max.y, b.max.y);
    }

    // =========================================================================
    // 7. CONTAINER SYSTEM
    // =========================================================================

    /// Lấy container hiện tại đang được xây dựng ở đỉnh stack.
    ///
    /// Thuật toán & Thiết kế:
    /// - Assert `container_stack.idx > 0`.
    /// - Trả về phần tử tại chỉ số `container_stack.idx - 1`.
    pub fn getCurrentContainer(self: *MicroUI) *c_microui.mu_Container {
        std.debug.assert(self.mu_context.*.container_stack.idx > 0);
        return self.mu_context.*.container_stack.items[@intCast(self.mu_context.*.container_stack.idx - 1)];
    }

    /// Đóng một container thông thường (Panel, Sub-view).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tính toán `content_size = layout.max - layout.body` phục vụ thanh cuộn.
    /// - Giảm chỉ số `container_stack.idx` và `layout_stack.idx`.
    /// - Pop ID tương ứng khỏi ID stack.
    pub fn popContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        const layout = self.getLayout();
        cnt.*.content_size.x = layout.*.max.x - layout.*.body.x;
        cnt.*.content_size.y = layout.*.max.y - layout.*.body.y;
        self.mu_context.*.container_stack.idx -= 1;
        self.mu_context.*.layout_stack.idx -= 1;
        self.popId();
    }

    /// Kết thúc một container gốc cấp cao nhất (Window, Popup).
    ///
    /// Thuật toán & Thiết kế:
    /// - Tạo command JUMP ở đuôi (`cnt.tail`) trỏ tới vị trí lệnh kế tiếp.
    /// - Nối con trỏ head sang đầu chuỗi command tiếp theo.
    /// - Rút clip rect và pop container.
    pub fn endRootContainer(self: *MicroUI) void {
        const cnt = self.getCurrentContainer();
        cnt.*.tail = self.pushJump(null);
        cnt.*.head.*.jump.dst = @ptrCast(&self.mu_context.*.command_list.items[@intCast(self.mu_context.*.command_list.idx)]);
        self.popClipRect();
        self.popContainer();
    }

    /// Bắt đầu một cửa sổ giao diện người dùng mới với tùy chọn mặc định.
    pub fn beginWindow(self: *MicroUI, title: [:0]const u8, rect: c_microui.mu_Rect) bool {
        return self.beginWindowEx(title, rect, 0);
    }

    /// Bắt đầu một cửa sổ giao diện người dùng mới với các cờ tùy chọn mở rộng.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi hàm C `mu_begin_window_ex` để quản lý tiêu đề, thanh kéo thả, nút cuộn, nút thu nhỏ.
    /// - Trả về `true` nếu cửa sổ đang mở và hiển thị nội dung bên trong, `false` nếu bị đóng hoặc thu nhỏ.
    pub fn beginWindowEx(self: *MicroUI, title: [:0]const u8, rect: c_microui.mu_Rect, opt: c_int) bool {
        return c_microui.mu_begin_window_ex(self.mu_context, title.ptr, rect, opt) != 0;
    }

    /// Kết thúc định nghĩa cửa sổ hiện tại.
    pub fn endWindow(self: *MicroUI) void {
        self.popClipRect();
        self.endRootContainer();
    }

    /// Bắt đầu một bảng con (Panel) lồng bên trong container hiện tại.
    pub fn beginPanel(self: *MicroUI, name: [:0]const u8) void {
        c_microui.mu_begin_panel(self.mu_context, name);
    }

    /// Kết thúc bảng con (Panel).
    pub fn endPanel(self: *MicroUI) void {
        self.popClipRect();
        self.popContainer();
    }

    /// Mở một menu popup ngữ cảnh tại vị trí con trỏ chuột hiện tại.
    ///
    /// Thuật toán & Thiết kế:
    /// - Lấy container tương ứng với tên popup.
    /// - Đặt làm `hover_root` để ưu tiên tiếp nhận tương tác chuột.
    /// - Đặt vị trí popup tại tọa độ chuột `mouse_pos`, kích thước khởi đầu (1, 1).
    /// - Đưa popup lên lớp trên cùng thông qua `mu_bring_to_front`.
    pub fn openPopup(self: *MicroUI, name: [:0]const u8) void {
        const cnt = c_microui.mu_get_container(self.mu_context, name.ptr);
        self.mu_context.*.hover_root = cnt;
        self.mu_context.*.next_hover_root = cnt;
        cnt.*.rect = c_microui.mu_rect(self.mu_context.*.mouse_pos.x, self.mu_context.*.mouse_pos.y, 1, 1);
        cnt.*.open = 1;
        c_microui.mu_bring_to_front(self.mu_context, cnt);
    }

    /// Bắt đầu khối nội dung cho menu popup đã mở.
    pub fn beginPopup(self: *MicroUI, name: [:0]const u8) c_int {
        const opt = c_microui.MU_OPT_POPUP | c_microui.MU_OPT_AUTOSIZE | c_microui.MU_OPT_NORESIZE |
            c_microui.MU_OPT_NOSCROLL | c_microui.MU_OPT_NOTITLE | c_microui.MU_OPT_CLOSED;
        return c_microui.mu_begin_window_ex(self.mu_context, name.ptr, c_microui.mu_rect(0, 0, 0, 0), opt);
    }

    /// Kết thúc nội dung menu popup.
    pub fn endPopup(self: *MicroUI) void {
        self.endWindow();
    }

    /// Bắt đầu một nút cây thư mục (Tree Node) với tùy chọn mặc định.
    pub fn beginTreenode(self: *MicroUI, name: [:0]const u8) c_int {
        return self.beginTreenodeEx(name, 0);
    }

    /// Bắt đầu một nút cây thư mục (Tree Node) có khả năng đóng/mở nội dung con.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `headerInternal(label, true, opt)`.
    /// - Nếu trạng thái là Active (đang mở):
    ///   + Tăng khoảng lùi đầu dòng `indent += style.indent`.
    ///   + Đẩy ID của treenode vào stack để cô lập các widget con.
    /// - Trả về `MU_RES_ACTIVE` nếu đang mở.
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
    /// - Rút ID treenode khỏi stack.
    pub fn endTreenode(self: *MicroUI) void {
        self.getLayout().*.indent -= self.mu_context.*.style.*.indent;
        self.popId();
    }

    // =========================================================================
    // 8. WIDGETS & CONTROLS
    // =========================================================================

    /// Hiển thị một nhãn văn bản (Label) đơn dòng.
    pub fn drawLabel(self: *MicroUI, label: [:0]const u8) void {
        self.drawControlText(label.ptr, self.layoutNext(), c_microui.MU_COLOR_TEXT, 0);
    }

    /// Hiển thị văn bản nhiều dòng với thuật toán tự động ngắt dòng theo từ (Word Wrap) và ký tự `\n`.
    ///
    /// Thuật toán & Thiết kế:
    /// - Kiểm tra rỗng: nếu `text.len == 0`, dừng ngay để tránh panic out-of-bounds.
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
    /// - Vẽ nền nút qua `drawControlFrame()` và nhãn/icon tương ứng.
    pub fn buttonEx(self: *MicroUI, label: ?[:0]const u8, icon: c_int, opt: c_int) c_int {
        var res: c_int = 0;
        const id = if (label) |l|
            self.getId(l.ptr, @intCast(l.len))
        else
            self.getId(&icon, @sizeOf(c_int));
        const r = self.layoutNext();
        self.updateControl(id, r, opt);
        if (self.mu_context.*.mouse_pressed == c_microui.MU_MOUSE_LEFT and self.mu_context.*.focus == id) {
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

    /// Widget hộp kiểm (Checkbox).
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ địa chỉ con trỏ `value`.
    /// - Chia ô layout thành 2 phần: ô vuông checkbox kích thước `h x h` và phần nhãn văn bản còn lại.
    /// - Nếu chuột click vào ô kiểm: đảo ngược giá trị `value.* = !value.*` và trả về `MU_RES_CHANGE`.
    /// - Vẽ khung base cho ô vuông, vẽ biểu tượng `MU_ICON_CHECK` nếu `value != 0`.
    /// - Vẽ nhãn văn bản bên cạnh.
    pub fn checkBox(self: *MicroUI, label: [:0]const u8, value: [*c]c_int) c_int {
        var res: c_int = 0;
        const id = self.getId(@ptrCast(&value), @sizeOf([*c]c_int));
        const r = self.layoutNext();
        const box = c_microui.mu_rect(r.x, r.y, r.h, r.h);
        self.updateControl(id, r, 0);
        if (self.mu_context.*.mouse_pressed == c_microui.MU_MOUSE_LEFT and self.mu_context.*.focus == id) {
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

    /// Wrapper gọi hàm C `mu_textbox` với slice bộ đệm chuỗi.
    pub fn drawTextBox(self: *MicroUI, text: []u8) usize {
        if (text.len == 0) return 0;
        const tmp: [*c]u8 = @ptrCast(&text[0]);
        return @as(usize, @intCast(c_microui.mu_textbox(
            self.mu_context,
            tmp,
            @as(c_int, @intCast(text.len)),
        )));
    }

    /// Widget hộp nhập văn bản (Textbox) cơ bản.
    pub fn textBox(self: *MicroUI, text: [*c]u8, len: c_int) c_int {
        return self.textBoxEx(text, len, 0);
    }

    /// Widget hộp nhập văn bản (Textbox) mở rộng với ID cố định theo địa chỉ bộ đệm.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID bằng cách băm trực tiếp địa chỉ vùng nhớ bộ đệm (`@intFromPtr(text)`).
    ///   Thuật toán này đảm bảo ID không bị thay đổi giữa các frame khi các ký tự bên trong buffer thay đổi,
    ///   giúp widget giữ nguyên tiêu điểm nhập liệu (focus) xuyên suốt phiên gõ phím.
    /// - Lấy vị trí từ layout và gọi `textBoxRaw()`.
    pub fn textBoxEx(self: *MicroUI, text: [*c]u8, len: c_int, opt: c_int) c_int {
        const addr = @intFromPtr(text);
        const id = self.getId(@ptrCast(&addr), @sizeOf(usize));
        const rect = self.layoutNext();
        return self.textBoxRaw(text, len, id, rect, opt);
    }

    /// Hàm xử lý cấp thấp cho hộp nhập văn bản.
    ///
    /// Thuật toán & Thiết kế:
    /// - Gọi `mu_textbox_raw` từ thư viện C để xử lý con trỏ nhấp nháy, phím Backspace, Enter, chèn ký tự UTF-8.
    pub fn textBoxRaw(self: *MicroUI, buf: [*c]u8, bufsz: c_int, id: c_uint, rect: c_microui.mu_Rect, opt: c_int) c_int {
        return c_microui.mu_textbox_raw(self.mu_context, buf, bufsz, id, rect, opt);
    }

    extern "c" fn sprintf(str: [*c]u8, format: [*c]const u8, ...) c_int;
    extern "c" fn strtod(nptr: [*c]const u8, endptr: [*c][*c]u8) f64;

    /// Trợ thủ nội bộ chuyển đổi slider/number thành hộp nhập liệu khi người dùng Shift+Click.
    ///
    /// Thuật toán & Thiết kế:
    /// - Nếu chuột click kèm phím Shift: kích hoạt chế độ chỉnh sửa số (`number_edit = id`), định dạng giá trị thành chuỗi.
    /// - Nếu widget đang ở chế độ chỉnh sửa: hiển thị textbox trực tiếp; khi nhấn Enter hoặc mất focus, chuyển đổi chuỗi ngược về float qua `strtod`.
    fn numberTextbox(self: *MicroUI, value: *f32, r: c_microui.mu_Rect, id: c_uint) bool {
        if (self.mu_context.*.mouse_pressed == c_microui.MU_MOUSE_LEFT and
            (self.mu_context.*.key_down & c_microui.MU_KEY_SHIFT) != 0 and
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
            ((self.mu_context.*.mouse_down | self.mu_context.*.mouse_pressed) & c_microui.MU_MOUSE_LEFT) != 0)
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

    /// Widget ô số có thể kéo điều chỉnh (Number) cơ bản.
    pub fn number(self: *MicroUI, value: *f32, step: f32) c_int {
        return self.numberEx(value, step, c_microui.MU_SLIDER_FMT, c_microui.MU_OPT_ALIGNCENTER);
    }

    /// Widget ô số có thể kéo điều chỉnh (Number) mở rộng.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ địa chỉ con trỏ `value`.
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

        if (self.mu_context.*.focus == id and (self.mu_context.*.mouse_down & c_microui.MU_MOUSE_LEFT) != 0) {
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

    /// Widget tiêu đề đề mục có thể thu gọn (Header) cơ bản.
    pub fn header(self: *MicroUI, label: [:0]const u8) c_int {
        return self.headerEx(label, 0);
    }

    /// Widget tiêu đề đề mục có thể thu gọn (Header) mở rộng.
    pub fn headerEx(self: *MicroUI, label: [:0]const u8, opt: c_int) c_int {
        return self.headerInternal(label, false, opt);
    }

    /// Trợ thủ nội bộ phục vụ chung cho Header và TreeNode.
    ///
    /// Thuật toán & Thiết kế:
    /// - Sinh ID từ chuỗi nhãn `label`.
    /// - Tra cứu trạng thái mở/đóng trong `treenode_pool`.
    /// - Xử lý click chuột để đảo ngược trạng thái Active.
    /// - Cập nhật hoặc xóa phần tử trong `treenode_pool`.
    /// - Vẽ biểu tượng tam giác `MU_ICON_EXPANDED` hoặc `MU_ICON_COLLAPSED`.
    /// - Vẽ nhãn văn bản bên cạnh biểu tượng và trả về trạng thái mở/đóng.
    fn headerInternal(self: *MicroUI, label: [:0]const u8, is_treenode: bool, opt: c_int) c_int {
        const id = self.getId(label.ptr, @intCast(label.len));
        const idx = c_microui.mu_pool_get(self.mu_context, &self.mu_context.*.treenode_pool, c_microui.MU_TREENODEPOOL_SIZE, id);
        self.layoutRow(&[_]i32{-1}, 0);

        var active = (idx >= 0);
        const expanded = if ((opt & c_microui.MU_OPT_EXPANDED) != 0) !active else active;
        var r = self.layoutNext();
        self.updateControl(id, r, 0);

        if (self.mu_context.*.mouse_pressed == c_microui.MU_MOUSE_LEFT and self.mu_context.*.focus == id) {
            active = !active;
        }

        if (idx >= 0) {
            if (active) {
                c_microui.mu_pool_update(self.mu_context, &self.mu_context.*.treenode_pool, idx);
            } else {
                @memset(@as([*]u8, @ptrCast(&self.mu_context.*.treenode_pool[@intCast(idx)]))[0..@sizeOf(c_microui.mu_PoolItem)], 0);
            }
        } else if (active) {
            _ = c_microui.mu_pool_init(self.mu_context, &self.mu_context.*.treenode_pool, c_microui.MU_TREENODEPOOL_SIZE, id);
        }

        if (is_treenode) {
            if (self.mu_context.*.hover == id) {
                if (self.mu_context.*.draw_frame) |draw_frame_fn| {
                    draw_frame_fn(self.mu_context, r, c_microui.MU_COLOR_BUTTONHOVER);
                }
            }
        } else {
            self.drawControlFrame(id, r, c_microui.MU_COLOR_BUTTON, 0);
        }

        const icon_id: c_int = if (expanded) c_microui.MU_ICON_EXPANDED else c_microui.MU_ICON_COLLAPSED;
        self.drawIcon(icon_id, c_microui.mu_rect(r.x, r.y, r.h, r.h), self.mu_context.*.style.*.colors[0][c_microui.MU_COLOR_TEXT]);
        r.x += r.h - self.mu_context.*.style.*.padding;
        r.w -= r.h - self.mu_context.*.style.*.padding;
        self.drawControlText(label.ptr, r, c_microui.MU_COLOR_TEXT, 0);

        return if (expanded) c_microui.MU_RES_ACTIVE else 0;
    }
};
