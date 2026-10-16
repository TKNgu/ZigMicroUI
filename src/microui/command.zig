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

pub const BaseCommand = struct {
    type: Type,
    next: ?*Command,
};

pub const JumpCommand = struct {
    base: BaseCommand,
    dst: ?*Command,
};

pub const ClipCommand = struct {
    base: BaseCommand,
    rect: math.Rect,
};

pub const RectCommand = struct {
    base: BaseCommand,
    rect: math.Rect,
    color: style_mod.Color,
};

pub const TextCommand = struct {
    base: BaseCommand,
    text: [*]const u8,
    pos: math.Vec2,
    color: style_mod.Color,
    font: c_microui.mu_Font,
};

pub const IconCommand = struct {
    base: BaseCommand,
    id: c_int,
    rect: math.Rect,
    color: style_mod.Color,
};

pub const Command = union(Type) {
    // type: Type,
    // base: BaseCommand,
    jump: JumpCommand,
    clip: ClipCommand,
    rect: RectCommand,
    text: TextCommand,
    icon: IconCommand,
};

pub const CommandList = struct {
    // fba: std.heap.FixedBufferAllocator,
    // buffer: []u8,
    // begin: ?*Command = null,
    // end: ?*Command = null,
    // count: usize = 0,

    allocator: std.mem.Allocator,
    commands: std.ArrayList(*Command),

    pub fn init(allocator: std.mem.Allocator) !CommandList {
        // const buffer = try allocator.alloc(u8, 256 * 1024);
        // errdefer allocator.free(buffer);

        return .{
            // .fba = std.heap.FixedBufferAllocator.init(buffer),
            // .buffer = buffer,

            .allocator = allocator,
            .commands = .empty,
        };
    }

    pub fn deinit(self: *CommandList, _: std.mem.Allocator) void {
        // allocator.free(self.buffer);

        for (self.commands.items) |cmd| {
            self.allocator.destroy(cmd);
        }
        self.commands.deinit(self.allocator);
    }

    pub fn clear(self: *CommandList) void {
        // self.fba.reset();
        // self.begin = null;
        // self.end = null;
        // self.count = 0;
        // std.debug.print("Clear *********************** \n", .{});

        for (self.commands.items) |cmd| {
            self.allocator.destroy(cmd);
        }
        self.commands.clearRetainingCapacity();
    }

    pub fn getBegin(self: *CommandList) ?*Command {
        return self.commands.items[0];
        // return self.begin;
    }

    pub fn getEnd(self: *CommandList) ?*Command {
        return self.commands.items[self.commands.items.len - 1];
        // return self.end;
    }

    pub fn getNextCommand(self: *CommandList, cmd: *?*Command) bool {
        if (cmd.*) |c| {
            var index: usize = 0;
            while (index < self.commands.items.len) : (index += 1) {
                if (self.commands.items[index] == c) {
                    break;
                }
            }
            cmd.* = self.commands.items[index + 1];
        } else {
            cmd.* = self.commands.first();
        }

        var index: usize = 0;
        while (index < self.commands.items.len) : (index += 1) {
            if (self.commands.items[index] == cmd.*) {
                break;
            }
        }
        index += 1;
        while (index < self.commands.items.len and
            self.commands.items[index].?.base.type == Type.jump) : (index += 1)
        {}
        if (index < self.commands.items.len) {
            cmd.* = self.commands.items[index];
            return true;
        } else {
            return false;
        }

        // if (cmd.*) |c| {
        //     c.* = c.*.*.base.next;
        // } else {
        //     cmd.* = self.begin;
        // }
        // while (cmd.* != self.end) {
        //     if (cmd.*.?.base.type != Type.jump) {
        //         return true;
        //     }
        //     cmd.* = cmd.*.?.jump.dst;
        // }
        // return false;
    }

    pub fn pushCommand(self: *CommandList, comptime T: type) !*T {
        const cmd = try self.allocator.create(T);
        errdefer self.allocator.destroy(cmd);

        self.commands.addOne(self.allocator).* = cmd;
        errdefer self.commands.removeOne(self.allocator);

        // const cmd = try self.fba.allocator().alignedAlloc(T, std.mem.Alignment.@"8", 1);
        // errdefer self.fba.allocator().free(cmd);
        //
        // self.count += 1;
        //
        // if (self.end) |end| {
        //     end.*.base.next = @ptrCast(cmd);
        //     std.debug.print("Next {*} {d}\n", .{ end.*.base.next, self.count });
        //     self.end = @ptrCast(cmd);
        // } else {
        //     self.begin = @ptrCast(cmd);
        //     self.end = self.begin;
        //     std.debug.print("Begin {*}\n", .{self.begin});
        // }
        // return @ptrCast(cmd.ptr);
    }

    pub fn pushCommandText(self: *CommandList, text_size: usize) !*Command {
        const cmd = try self.pushCommand(TextCommand);
        errdefer self.fba.allocator().destroy(cmd);

        const text = try self.fba.allocator().alloc(u8, text_size);
        errdefer self.fba.allocator().free(text);

        cmd.*.text = text.ptr;
        return @ptrCast(cmd);
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
        const tmp: [*]u8 = @ptrCast(&cmd.*.text);
        @memcpy(tmp[0..text.len], text);
        tmp[text.len] = 0;
        cmd.*.pos = .{
            .x = pos.x,
            .y = pos.y,
        };
        cmd.*.color = color;
        cmd.*.font = font;
        return @ptrCast(cmd);
    }
};
