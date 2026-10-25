const std = @import("std");
const math = @import("math.zig");
const style_mod = @import("style.zig");
const types_mod = @import("types.zig");
pub const Icon = types_mod.Icon;

pub const Type = enum(u8) { jump, clip, rect, text, icon };

pub const BaseCommand = extern struct {
    type: Type,
    next: ?*Command = null,
};

pub const JumpCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.jump,
    },
    dst: ?*Command = null,
};

pub const ClipCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.clip,
    },
    rect: math.Rect = .zero,
};

pub const RectCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.rect,
    },
    rect: math.Rect = .zero,
    color: style_mod.Color = .{},
};

pub const TextCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.text,
    },
    text: [*]const u8 = undefined,
    len: usize = 0,
    pos: math.Vec2 = .zero,
    color: style_mod.Color = .{},
    font: style_mod.Font = null,

    pub inline fn slice(self: *const TextCommand) []const u8 {
        return self.text[0..self.len];
    }
    pub const getSlice = slice;
};

pub const IconCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.icon,
    },
    icon: Icon = .none,
    rect: math.Rect = .zero,
    color: style_mod.Color = .{},
};

pub const Command = extern union {
    type: Type,
    base: BaseCommand,
    jump: JumpCommand,
    clip: ClipCommand,
    rect: RectCommand,
    text: TextCommand,
    icon: IconCommand,
};

pub const CommandList = struct {
    fba: std.heap.FixedBufferAllocator,
    head: ?*Command = null,
    tail: ?*Command = null,

    pub fn init(allocator: std.mem.Allocator) !CommandList {
        const buffer = try allocator.alloc(u8, 256 * 1024);
        errdefer allocator.free(buffer);

        return .{
            .fba = std.heap.FixedBufferAllocator.init(buffer),
        };
    }

    pub fn deinit(self: *CommandList, allocator: std.mem.Allocator) void {
        allocator.free(self.fba.buffer);
    }

    pub fn clear(self: *CommandList) void {
        self.fba.reset();
        self.head = null;
        self.tail = self.head;
    }

    inline fn pushCommand(self: *CommandList, comptime T: type) !*T {
        const cmd = try self.fba.allocator().create(T);
        errdefer self.fba.allocator().destroy(cmd);

        cmd.* = .{};
        if (self.tail) |tail| {
            tail.base.next = @ptrCast(cmd);
            self.tail = @ptrCast(cmd);
        } else {
            self.head = @ptrCast(cmd);
            self.tail = self.head;
        }
        return cmd;
    }

    pub inline fn pushJump(self: *CommandList, dst: ?*Command) !*Command {
        const cmd = try self.pushCommand(JumpCommand);
        errdefer self.fba.allocator().destroy(cmd);

        cmd.*.dst = dst;
        return @ptrCast(cmd);
    }

    pub inline fn pushRect(self: *CommandList, draw_rect: math.Rect, color: style_mod.Color) !*Command {
        const cmd = try self.pushCommand(RectCommand);
        errdefer self.fba.allocator().destroy(cmd);

        cmd.*.rect = draw_rect;
        cmd.*.color = color;
        return @ptrCast(cmd);
    }

    pub inline fn pushIcon(self: *CommandList, icon: Icon, draw_rect: math.Rect, color: style_mod.Color) !*Command {
        const cmd = try self.pushCommand(IconCommand);
        errdefer self.fba.allocator().destroy(cmd);

        cmd.*.icon = icon;
        cmd.*.rect = draw_rect;
        cmd.*.color = color;
        return @ptrCast(cmd);
    }

    pub inline fn pushClip(self: *CommandList, rect: math.Rect) !*Command {
        const cmd = try self.pushCommand(ClipCommand);
        errdefer self.fba.allocator().destroy(cmd);

        cmd.*.rect = rect;
        return @ptrCast(cmd);
    }

    pub fn pushText(self: *CommandList, text: []const u8, pos: math.Vec2, color: style_mod.Color, font: style_mod.Font) !*Command {
        const cmd = try self.pushCommand(TextCommand);
        errdefer self.fba.allocator().destroy(cmd);

        const slice = try self.fba.allocator().alloc(u8, text.len + 1);
        errdefer self.fba.allocator().free(slice);

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
