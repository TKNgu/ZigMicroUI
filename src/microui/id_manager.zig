const std = @import("std");
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

pub const IdManager2 = struct {
    pub const DEFAULT_STACK_SIZE: usize = 32;
    pub const HASH_INITIAL: Id = 2166136261;

    id_stack: stack.Stack(Id, DEFAULT_STACK_SIZE) = .{},
    last_id: Id = 0,

    pub fn init() IdManager2 {
        var self: IdManager2 = .{};
        self.id_stack.push(HASH_INITIAL);
        return self;
    }

    // Comptime utility: 1 variable (autodetects SourceLocation or String/Slice)
    pub inline fn genComptime(comptime src: anytype) u32 {
        const T = @TypeOf(src);
        if (T == std.builtin.SourceLocation) {
            return genComptimeId(src);
        } else if (comptime isString(T)) {
            const bytes: []const u8 = if (@typeInfo(T) == .array) &src else src;
            return genComptimeIdFromSlice(bytes);
        } else {
            @compileError("Unsupported type for genComptime: " ++ @typeName(T));
        }
    }

    // Comptime utility: 1 variable + index
    pub inline fn genComptimeIndexed(comptime src: anytype, comptime index: usize) u32 {
        const T = @TypeOf(src);
        if (T == std.builtin.SourceLocation) {
            return genComptimeIdIndexed(src, index);
        } else if (comptime isString(T)) {
            const bytes: []const u8 = if (@typeInfo(T) == .array) &src else src;
            return genComptimeIdFromSliceIndexed(bytes, index);
        } else {
            @compileError("Unsupported type for genComptimeIndexed: " ++ @typeName(T));
        }
    }

    // Comptime utility with parent: 1 variable + parent
    pub inline fn genStackComptime(comptime src: anytype, comptime parent: u32) u32 {
        const T = @TypeOf(src);
        if (T == std.builtin.SourceLocation) {
            return genStackComptimeId(src, parent);
        } else if (comptime isString(T)) {
            const bytes: []const u8 = if (@typeInfo(T) == .array) &src else src;
            return genStackComptimeIdFromSlice(bytes, parent);
        } else {
            @compileError("Unsupported type for genStackComptime: " ++ @typeName(T));
        }
    }

    // Comptime utility with parent: 1 variable + parent + index
    pub inline fn genStackComptimeIndexed(comptime src: anytype, comptime parent: u32, comptime index: usize) u32 {
        const T = @TypeOf(src);
        if (T == std.builtin.SourceLocation) {
            return genStackComptimeIdIndexed(src, parent, index);
        } else if (comptime isString(T)) {
            const bytes: []const u8 = if (@typeInfo(T) == .array) &src else src;
            return genStackComptimeIdFromSliceIndexed(bytes, parent, index);
        } else {
            @compileError("Unsupported type for genStackComptimeIndexed: " ++ @typeName(T));
        }
    }

    fn isString(comptime T: type) bool {
        return switch (@typeInfo(T)) {
            .pointer => |ptr| switch (ptr.size) {
                .slice => ptr.child == u8,
                .one => switch (@typeInfo(ptr.child)) {
                    .array => |arr| arr.child == u8,
                    else => false,
                },
                else => false,
            },
            .array => |arr| arr.child == u8,
            else => false,
        };
    }

    // Comptime ID by @src() location
    pub fn genComptimeId(comptime src: std.builtin.SourceLocation) u32 {
        const raw = std.fmt.comptimePrint(
            "{d}:{d}:{s}:{s}:{s}",
            .{ src.line, src.column, src.fn_name, src.file, src.module },
        );
        return std.hash.Fnv1a_32.hash(raw);
    }

    pub fn genComptimeIdIndexed(comptime src: std.builtin.SourceLocation, comptime index: usize) u32 {
        const raw = std.fmt.comptimePrint(
            "{d}:{d}:{s}:{s}:{s}#{d}",
            .{ src.line, src.column, src.fn_name, src.file, src.module, index },
        );
        return std.hash.Fnv1a_32.hash(raw);
    }

    pub fn genStackComptimeId(comptime src: std.builtin.SourceLocation, comptime parent: u32) u32 {
        const raw = std.fmt.comptimePrint(
            "{x}:{d}:{d}:{s}:{s}:{s}",
            .{ parent, src.line, src.column, src.fn_name, src.file, src.module },
        );
        return std.hash.Fnv1a_32.hash(raw);
    }

    pub fn genStackComptimeIdIndexed(comptime src: std.builtin.SourceLocation, comptime parent: u32, comptime index: usize) u32 {
        const raw = std.fmt.comptimePrint(
            "{x}:{d}:{d}:{s}:{s}:{s}#{d}",
            .{ parent, src.line, src.column, src.fn_name, src.file, src.module, index },
        );
        return std.hash.Fnv1a_32.hash(raw);
    }

    // Comptime ID by memory slice
    pub fn genComptimeIdFromSlice(comptime bytes: []const u8) u32 {
        return std.hash.Fnv1a_32.hash(bytes);
    }

    pub fn genComptimeIdFromSliceIndexed(comptime bytes: []const u8, comptime index: usize) u32 {
        const base_id = genComptimeIdFromSlice(bytes);
        return @truncate(std.hash.Wyhash.hash(base_id, std.mem.asBytes(&index)));
    }

    pub fn genStackComptimeIdFromSlice(comptime bytes: []const u8, comptime parent: u32) u32 {
        return @truncate(std.hash.Wyhash.hash(parent, bytes));
    }

    pub fn genStackComptimeIdFromSliceIndexed(comptime bytes: []const u8, comptime parent: u32, comptime index: usize) u32 {
        const base_id = genStackComptimeIdFromSlice(bytes, parent);
        return @truncate(std.hash.Wyhash.hash(base_id, std.mem.asBytes(&index)));
    }

    // Polymorphic Runtime utility: 1 variable (autodetects SourceLocation, String, Integer, or Pointer)
    pub inline fn genId(self: *IdManager2, src: anytype) u32 {
        const T = @TypeOf(src);
        if (T == std.builtin.SourceLocation) {
            const local_id = genComptimeId(src);
            return self.genRuntimeId(local_id);
        } else if (comptime isString(T)) {
            const bytes: []const u8 = if (@typeInfo(T) == .array) &src else src;
            return self.genRuntimeIdFromSlice(bytes);
        } else if (@typeInfo(T) == .int) {
            return self.genRuntimeId(@truncate(src));
        } else if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .one and @typeInfo(T).pointer.child != anyopaque) {
            return self.genRuntimeIdFromRaw(@ptrCast(src), @sizeOf(@typeInfo(T).pointer.child));
        } else {
            @compileError("Unsupported type for genId: " ++ @typeName(T));
        }
    }

    // Polymorphic Runtime utility: 1 variable + index
    pub inline fn genIdIndexed(self: *IdManager2, src: anytype, index: usize) u32 {
        const T = @TypeOf(src);
        if (T == std.builtin.SourceLocation) {
            const local_id = genComptimeId(src);
            return self.genRuntimeIdIndexed(local_id, index);
        } else if (comptime isString(T)) {
            const bytes: []const u8 = if (@typeInfo(T) == .array) &src else src;
            return self.genRuntimeIdFromSliceIndexed(bytes, index);
        } else if (@typeInfo(T) == .int) {
            return self.genRuntimeIdIndexed(@truncate(src), index);
        } else if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .one and @typeInfo(T).pointer.child != anyopaque) {
            return self.genRuntimeIdFromRawIndexed(@ptrCast(src), @sizeOf(@typeInfo(T).pointer.child), index);
        } else {
            @compileError("Unsupported type for genIdIndexed: " ++ @typeName(T));
        }
    }

    // Runtime ID
    pub fn genRuntimeId(self: *IdManager2, local_id: u32) u32 {
        const parent_id = self.id_stack.top();
        const res: u32 = @truncate(std.hash.Wyhash.hash(parent_id, std.mem.asBytes(&local_id)));
        self.last_id = res;
        return res;
    }

    pub fn genRuntimeIdIndexed(self: *IdManager2, local_id: u32, index: usize) u32 {
        const base_id = self.genRuntimeId(local_id);
        const res: u32 = @truncate(std.hash.Wyhash.hash(base_id, std.mem.asBytes(&index)));
        self.last_id = res;
        return res;
    }

    // Runtime Id from memory slice
    pub fn genRuntimeIdFromSlice(self: *IdManager2, bytes: []const u8) u32 {
        const parent_id = self.id_stack.top();
        const res: u32 = @truncate(std.hash.Wyhash.hash(parent_id, bytes));
        self.last_id = res;
        return res;
    }

    pub fn genRuntimeIdFromSliceIndexed(self: *IdManager2, bytes: []const u8, index: usize) u32 {
        const base_id = self.genRuntimeIdFromSlice(bytes);
        const res: u32 = @truncate(std.hash.Wyhash.hash(base_id, std.mem.asBytes(&index)));
        self.last_id = res;
        return res;
    }

    // Runtime Id from raw pointer
    pub fn genRuntimeIdFromRaw(self: *IdManager2, data: *const anyopaque, size: usize) u32 {
        const bytes: [*]const u8 = @ptrCast(data);
        return self.genRuntimeIdFromSlice(bytes[0..size]);
    }

    pub fn genRuntimeIdFromRawIndexed(self: *IdManager2, data: *const anyopaque, size: usize, index: usize) u32 {
        const base_id = self.genRuntimeIdFromRaw(data, size);
        const res: u32 = @truncate(std.hash.Wyhash.hash(base_id, std.mem.asBytes(&index)));
        self.last_id = res;
        return res;
    }

    // Support for stack operations
    pub inline fn top(self: *const IdManager2) u32 {
        return self.id_stack.top();
    }

    pub inline fn getLastId(self: *const IdManager2) Id {
        return self.last_id;
    }

    pub inline fn push(self: *IdManager2, id: u32) void {
        self.id_stack.push(id);
    }

    pub inline fn pop(self: *IdManager2) u32 {
        return self.id_stack.pop();
    }
};

test "IdManager2 functionality" {
    var mgr = IdManager2.init();
    try std.testing.expectEqual(IdManager2.HASH_INITIAL, mgr.top());

    // 1. Comptime utilities: genComptime & genComptimeIndexed
    const comp_src1 = IdManager2.genComptime(@src());
    const comp_src2 = IdManager2.genComptime(@src());
    try std.testing.expect(comp_src1 != comp_src2);

    const comp_src_idx0 = IdManager2.genComptimeIndexed(@src(), 0);
    const comp_src_idx1 = IdManager2.genComptimeIndexed(@src(), 1);
    try std.testing.expect(comp_src_idx0 != comp_src_idx1);

    const comp_str1 = IdManager2.genComptime("btn_save");
    const comp_str2 = IdManager2.genComptime("btn_load");
    try std.testing.expect(comp_str1 != comp_str2);

    const comp_str_idx0 = IdManager2.genComptimeIndexed("item", 0);
    const comp_str_idx1 = IdManager2.genComptimeIndexed("item", 1);
    try std.testing.expect(comp_str_idx0 != comp_str_idx1);

    // 2. Comptime Stack utilities: genStackComptime & genStackComptimeIndexed
    const stack_c1 = IdManager2.genStackComptime(@src(), 12345);
    const stack_c2 = IdManager2.genStackComptime("panel", 12345);
    try std.testing.expect(stack_c1 != stack_c2);

    const stack_c_idx0 = IdManager2.genStackComptimeIndexed(@src(), 12345, 0);
    const stack_c_idx1 = IdManager2.genStackComptimeIndexed("row", 12345, 1);
    try std.testing.expect(stack_c_idx0 != stack_c_idx1);

    // 3. Runtime polymorphic genId (1 variable)
    const id_from_src = mgr.genId(@src());
    try std.testing.expectEqual(id_from_src, mgr.getLastId());

    const id_from_str = mgr.genId("header_title");
    try std.testing.expectEqual(id_from_str, mgr.getLastId());

    const id_from_int = mgr.genId(@as(u32, 9999));
    try std.testing.expectEqual(id_from_int, mgr.getLastId());

    var val: f32 = 123.45;
    const id_from_ptr = mgr.genId(&val);
    try std.testing.expectEqual(id_from_ptr, mgr.getLastId());

    // 4. Runtime polymorphic genIdIndexed (1 variable + index)
    const id_src_idx0 = mgr.genIdIndexed(@src(), 0);
    const id_src_idx1 = mgr.genIdIndexed(@src(), 1);
    try std.testing.expect(id_src_idx0 != id_src_idx1);

    const id_str_idx0 = mgr.genIdIndexed("list_row", 0);
    const id_str_idx1 = mgr.genIdIndexed("list_row", 1);
    try std.testing.expect(id_str_idx0 != id_str_idx1);

    const id_ptr_idx0 = mgr.genIdIndexed(&val, 0);
    const id_ptr_idx1 = mgr.genIdIndexed(&val, 1);
    try std.testing.expect(id_ptr_idx0 != id_ptr_idx1);

    // 5. Stack push / pop & hierarchy propagation
    mgr.push(id_from_src);
    try std.testing.expectEqual(id_from_src, mgr.top());

    const child_id = mgr.genId("child_element");
    try std.testing.expect(child_id != id_from_src);

    const popped = mgr.pop();
    try std.testing.expectEqual(id_from_src, popped);
    try std.testing.expectEqual(IdManager2.HASH_INITIAL, mgr.top());
}
