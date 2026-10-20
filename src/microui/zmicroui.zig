const std = @import("std");
const command = @import("command.zig");
const container = @import("container.zig");
const stack = @import("stack.zig");

pub const ZMicroUI = struct {
    command_list: command.CommandList,

    pub fn init(allocator: std.mem.Allocator) !ZMicroUI {
        return .{
            .command_list = try command.CommandList.init(allocator),
        };
    }

    pub fn deinit(self: *ZMicroUI, allocator: std.mem.Allocator) void {
        self.command_list.deinit(allocator);
    }

    pub fn begin(self: *ZMicroUI) void {
        self.command_list.reset();
    }

    pub inline fn nextCommand(self: *ZMicroUI, cmd: *?*command.Command) bool {
        if (cmd.*) |tmp| {
            if (tmp != self.command_list.tail) {
                cmd.* = tmp.base.next;
            } else if (tmp.base.type != command.Type.jump) {
                return false;
            }
        } else {
            cmd.* = self.command_list.head;
        }

        while (cmd.*) |tmp| : (cmd.* = tmp.jump.dst) {
            if (tmp.base.type != command.Type.jump) {
                return cmd.* != null;
            }
        }
        return cmd.* != null;
    }
};
