const stack = @import("stack.zig");
const Id = @import("types.zig").Id;

pub const IdManager = struct {
    pub const HASH_INITIAL: Id = 2166136261;
    pub const HASH_PRIME: Id = 16777619;
    pub const DEFAULT_STACK_SIZE: usize = 32;

    id_stack: stack.Stack(Id, DEFAULT_STACK_SIZE) = .{},
    last_id: Id = 0,

    pub inline fn isEmpty(self: *const IdManager) bool {
        return self.id_stack.isEmpty();
    }

    pub inline fn getCurrent(self: *const IdManager) Id {
        return self.id_stack.top();
    }

    pub inline fn getLastId(self: *const IdManager) Id {
        return self.last_id;
    }

    pub inline fn push(self: *IdManager, id: Id) void {
        self.id_stack.push(id);
    }

    pub inline fn pop(self: *IdManager) Id {
        return self.id_stack.pop();
    }

    pub fn getId(self: *IdManager, data: ?*const anyopaque, size: usize) Id {
        var res: Id = if (self.id_stack.isEmpty()) HASH_INITIAL else self.id_stack.top();

        if (data) |p| {
            const bytes: [*]const u8 = @ptrCast(p);
            for (bytes[0..size]) |b| {
                res = (res ^ b) *% HASH_PRIME;
            }
        }
        self.last_id = res;
        return res;
    }
};
