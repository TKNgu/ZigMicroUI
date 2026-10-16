const std = @import("std");
const math = @import("math.zig");
const c_microui = @import("c_microui");
const style_mod = @import("style.zig");

pub const Type = enum(u8) {
    jump = 0,
    clip,
    rect,
    text,
    icon,
};

pub const BaseCommand = extern struct {
    type: Type,
    next: ?*Command = null,
};

pub const JumpCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.jump,
    },
    dst: ?*Command,
};

pub const ClipCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.clip,
    },
    rect: math.Rect,
};

pub const RectCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.rect,
    },
    rect: math.Rect,
    color: style_mod.Color,
};

pub const TextCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.text,
    },
    text: [*]u8,
    pos: math.Vec2,
    color: style_mod.Color,
    font: c_microui.mu_Font,
};

pub const IconCommand = extern struct {
    base: BaseCommand = .{
        .type = Type.icon,
    },
    id: c_int,
    rect: math.Rect,
    color: style_mod.Color,
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
    buffer: []u8,
    begin: ?*Command = null,
    end: ?*Command = null,

    pub fn init(allocator: std.mem.Allocator) !CommandList {
        const buffer = try allocator.alloc(u8, 256 * 1024);
        errdefer allocator.free(buffer);

        return .{
            .fba = std.heap.FixedBufferAllocator.init(buffer),
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *CommandList, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn clear(self: *CommandList) void {
        self.fba.reset();
        self.begin = null;
        self.end = self.begin;
    }

    pub fn getBegin(self: *CommandList) ?*Command {
        return self.begin;
    }

    pub fn getEnd(self: *CommandList) ?*Command {
        return self.end;
    }

    pub fn getNextCommand(self: *CommandList, cmd: *?*Command) bool {
        if (cmd.* != null) {
            if (cmd.* == self.end) {
                return false;
            }
            cmd.* = cmd.*.?.base.next;
        } else {
            cmd.* = self.begin;
            std.debug.print("begin {*}\n", .{cmd.*});
        }

        if (cmd.* == self.end) {
            return false;
        }

        while (cmd.*.?.base.type == Type.jump) : (cmd.* = cmd.*.?.jump.dst) {
            std.debug.print("jump {*}\n", .{cmd.*});
            if (cmd.*.?.jump.dst == null) {
                return false;
            }
        }
        return true;
    }

    pub fn pushCommand(self: *CommandList, comptime T: type) !*T {
        const cmd = try self.fba.allocator().create(T);
        switch (T) {
            JumpCommand => {
                cmd.*.base.type = Type.jump;
            },
            ClipCommand => {
                cmd.*.base.type = Type.clip;
            },
            RectCommand => {
                cmd.*.base.type = Type.rect;
            },
            TextCommand => {
                cmd.*.base.type = Type.text;
            },
            IconCommand => {
                cmd.*.base.type = Type.icon;
            },
            else => {},
        }

        if (self.end) |end| {
            end.base.next = @ptrCast(cmd);
            self.end = @ptrCast(cmd);
        } else {
            self.begin = @ptrCast(cmd);
            self.end = self.begin;
        }
        return cmd;
    }

    pub fn pushJump(self: *CommandList, dst: ?*Command) !*Command {
        const cmd = try self.pushCommand(JumpCommand);
        cmd.*.dst = dst;
        return @ptrCast(cmd);
    }

    pub fn pushRect(self: *CommandList, draw_rect: math.Rect, color: style_mod.Color) !*Command {
        const cmd = try self.pushCommand(RectCommand);
        cmd.*.rect = draw_rect;
        cmd.*.color = color;
        return @ptrCast(cmd);
    }

    pub fn pushIcon(self: *CommandList, id: c_int, draw_rect: math.Rect, color: style_mod.Color) !*Command {
        const cmd = try self.pushCommand(IconCommand);
        cmd.*.id = id;
        cmd.*.rect = draw_rect;
        cmd.*.color = color;
        return @ptrCast(cmd);
    }

    pub fn pushClip(self: *CommandList, rect: math.Rect) !*Command {
        const cmd = try self.pushCommand(ClipCommand);
        cmd.*.rect = rect;
        return @ptrCast(cmd);
    }

    pub fn pushText(
        self: *CommandList,
        text: []const u8,
        pos: math.Vec2,
        color: style_mod.Color,
        font: c_microui.mu_Font,
    ) !*Command {
        const cmd = try self.pushCommand(TextCommand);
        const slice = try self.fba.allocator().alloc(u8, text.len);
        cmd.*.text = slice.ptr;
        @memcpy(slice[0..text.len], text);
        cmd.*.pos = .{
            .x = pos.x,
            .y = pos.y,
        };
        cmd.*.color = color;
        cmd.*.font = font;
        return @ptrCast(cmd);
    }
};
