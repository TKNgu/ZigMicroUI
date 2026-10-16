//! MicroUI Command Buffer & Rendering Commands
//!
//! Kiến trúc Render Command List:
//! - Sử dụng FixedBufferAllocator (FBA) để cấp phát các command liên tiếp trong buffer tạm.
//! - Mỗi lệnh có trường `base: BaseCommand` chứa enum `type` và con trỏ `next: ?*Command`.
//! - Các container được liên kết thông qua lệnh `JumpCommand`, cho phép render phân lớp (Z-Index)
//!   mà không cần xáo trộn vùng nhớ buffer.
//! - Lệnh TextCommand lưu trữ con trỏ chuỗi kèm độ dài `len`, tối ưu việc đọc slice text trong backend render.

const std = @import("std");
const math = @import("math.zig");
const style_mod = @import("style.zig");

// =============================================================================
// 1. COMMAND TYPES & BASE DEFINITION
// =============================================================================

/// Phân loại lệnh vẽ trong Command Buffer.
pub const Type = enum(u8) {
    jump = 0,
    clip,
    rect,
    text,
    icon,
};

/// Cấu trúc đầu bảng (header) có mặt trong mọi command cụ thể.
pub const BaseCommand = extern struct {
    type: Type,
    next: ?*Command = null,
};

// =============================================================================
// 2. CONCRETE COMMAND STRUCTS
// =============================================================================

/// Lệnh nhảy: Chuyển hướng luồng duyệt command sang một địa chỉ khác (dùng phân lớp container Z-Index).
pub const JumpCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.jump,
    },
    dst: ?*Command = null,
};

/// Lệnh cắt khung vẽ (scissor clip): Giới hạn vùng vẽ tiếp theo trong hình chữ nhật `rect`.
pub const ClipCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.clip,
    },
    rect: math.Rect = .{},
};

/// Lệnh vẽ hình chữ nhật đặc với màu tương ứng.
pub const RectCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.rect,
    },
    rect: math.Rect = .{},
    color: style_mod.Color = .{},
};

/// Lệnh vẽ văn bản: Lưu trữ con trỏ chuỗi, độ dài, vị trí, màu và font.
pub const TextCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.text,
    },
    text: [*]const u8 = undefined,
    len: usize = 0,
    pos: math.Vec2 = .{},
    color: style_mod.Color = .{},
    font: style_mod.Font = null,

    /// Trả về slice chuỗi văn bản an toàn mà không cần quét null sentinel.
    pub fn getSlice(self: *const TextCommand) []const u8 {
        return self.text[0..self.len];
    }
};

/// Lệnh vẽ biểu tượng (Icon) từ atlas ảnh theo ID, vị trí và màu.
pub const IconCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.icon,
    },
    id: i32 = 0,
    rect: math.Rect = .{},
    color: style_mod.Color = .{},
};

// =============================================================================
// 3. POLYMORPHIC COMMAND UNION
// =============================================================================

/// Union đa hình dùng để ép kiểu con trỏ an toàn khi duyệt danh sách lệnh.
pub const Command = extern union {
    type: Type,
    base: BaseCommand,
    jump: JumpCommand,
    clip: ClipCommand,
    rect: RectCommand,
    text: TextCommand,
    icon: IconCommand,
};

// =============================================================================
// 4. COMMAND LIST (FBA + INTRUSIVE LINKED LIST)
// =============================================================================

/// Trình quản lý bộ đệm lệnh vẽ cho mỗi frame.
pub const CommandList = struct {
    fba: std.heap.FixedBufferAllocator,
    buffer: []u8,
    begin: ?*Command = null,
    end: ?*Command = null,

    /// Khởi tạo CommandList với vùng nhớ đệm cố định 256KB cho mỗi frame.
    pub fn init(allocator: std.mem.Allocator) !CommandList {
        const buffer = try allocator.alloc(u8, 256 * 1024);
        errdefer allocator.free(buffer);

        return .{
            .fba = std.heap.FixedBufferAllocator.init(buffer),
            .buffer = buffer,
        };
    }

    /// Giải phóng vùng nhớ đệm của CommandList.
    pub fn deinit(self: *CommandList, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    /// Đặt lại bộ cấp phát FBA và xóa danh sách lệnh về rỗng cho frame mới.
    pub fn clear(self: *CommandList) void {
        self.fba.reset();
        self.begin = null;
        self.end = null;
    }

    /// Lấy con trỏ lệnh đầu tiên.
    pub fn getBegin(self: *CommandList) ?*Command {
        return self.begin;
    }

    /// Lấy con trỏ lệnh cuối cùng.
    pub fn getEnd(self: *CommandList) ?*Command {
        return self.end;
    }

    /// Iterator duyệt tuần tự từng lệnh vẽ, tự động xử lý và vượt qua các bước nhảy JumpCommand.
    pub fn getNextCommand(self: *CommandList, cmd: *?*Command) bool {
        if (cmd.* == null) {
            cmd.* = self.begin;
        } else {
            if (cmd.* == self.end) {
                return false;
            }
            cmd.* = cmd.*.?.base.next;
        }

        while (cmd.*) |curr| {
            if (curr.base.type != Type.jump) break;
            if (curr.jump.dst == null) return false;
            cmd.* = curr.jump.dst;
        }
        return cmd.* != null;
    }

    /// Cấp phát một command kiểu `T` trong FBA và liên kết vào cuối danh sách lệnh.
    pub fn pushCommand(self: *CommandList, comptime T: type) !*T {
        const cmd = try self.fba.allocator().create(T);
        cmd.* = .{};

        if (self.end) |end| {
            end.base.next = @ptrCast(cmd);
            self.end = @ptrCast(cmd);
        } else {
            self.begin = @ptrCast(cmd);
            self.end = self.begin;
        }
        return cmd;
    }

    /// Thêm lệnh nhảy JumpCommand.
    pub fn pushJump(self: *CommandList, dst: ?*Command) !*Command {
        const cmd = try self.pushCommand(JumpCommand);
        cmd.*.dst = dst;
        return @ptrCast(cmd);
    }

    /// Thêm lệnh vẽ hình chữ nhật RectCommand.
    pub fn pushRect(self: *CommandList, draw_rect: math.Rect, color: style_mod.Color) !*Command {
        const cmd = try self.pushCommand(RectCommand);
        cmd.*.rect = draw_rect;
        cmd.*.color = color;
        return @ptrCast(cmd);
    }

    /// Thêm lệnh vẽ biểu tượng IconCommand.
    pub fn pushIcon(self: *CommandList, id: i32, draw_rect: math.Rect, color: style_mod.Color) !*Command {
        const cmd = try self.pushCommand(IconCommand);
        cmd.*.id = id;
        cmd.*.rect = draw_rect;
        cmd.*.color = color;
        return @ptrCast(cmd);
    }

    /// Thêm lệnh cắt khung hình ClipCommand.
    pub fn pushClip(self: *CommandList, rect: math.Rect) !*Command {
        const cmd = try self.pushCommand(ClipCommand);
        cmd.*.rect = rect;
        return @ptrCast(cmd);
    }

    /// Thêm lệnh vẽ văn bản TextCommand kèm sao chép nội dung chuỗi vào buffer FBA.
    pub fn pushText(
        self: *CommandList,
        text: []const u8,
        pos: math.Vec2,
        color: style_mod.Color,
        font: style_mod.Font,
    ) !*Command {
        const cmd = try self.pushCommand(TextCommand);
        const slice = try self.fba.allocator().alloc(u8, text.len + 1);
        @memcpy(slice[0..text.len], text);
        slice[text.len] = 0;
        cmd.*.text = slice.ptr;
        cmd.*.len = text.len;
        cmd.*.pos = pos;
        cmd.*.color = color;
        cmd.*.font = font;
        return @ptrCast(cmd);
    }
};
