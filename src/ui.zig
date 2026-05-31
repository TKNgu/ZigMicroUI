const std = @import("std");
const math = @import("math.zig");
const render = @import("render.zig");
const color = @import("color.zig");
const style = @import("style.zig");

// Draw
pub fn drawFrame(
    renderer: *render.RenderEngine,
    rect: math.rect.Rect2(f32),
    rect_color: color.Color,
    border_color: color.Color,
) !void {
    try renderer.fillRect(rect, rect_color);
    try renderer.rect(rect, border_color);
}

// Layout
pub fn createArrayLayout(comptime N: usize) type {
    return struct {
        const Self = @This();

        index: usize = 0,
        items: [N]f32 = undefined,

        pub fn init(items: *const [N]f32) Self {
            var layout: Self = .{};
            std.mem.copyForwards(f32, &layout.items, items);
            return layout;
        }

        pub fn next(self: *Self) f32 {
            if (self.index >= N) {
                self.index = 0;
            }
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub inline fn getIsEnd(self: *const Self) bool {
            return self.index >= N;
        }

        pub inline fn nextLine(self: *Self) void {
            self.index = 0;
        }
    };
}

pub const Layout = struct {
    const VTable = struct {
        next: *const fn (*anyopaque) math.rect.Rect2(f32),

        fn create(comptime T: type) VTable {
            return VTable{
                .next = struct {
                    fn next(ptr: *anyopaque) math.rect.Rect2(f32) {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.next();
                    }
                }.next,
            };
        }
    };

    ptr: *anyopaque,
    vtable: *const VTable,

    pub inline fn next(self: *const Layout) math.rect.Rect2(f32) {
        return self.vtable.*.next(self.ptr);
    }
};

pub fn createRowLayout(comptime N: usize) type {
    return struct {
        const Self = @This();
        const VTable = Layout.VTable.create(Self);

        body: math.rect.Rect2(f32),
        layout: createArrayLayout(N),

        pub fn init(body: math.rect.Rect2(f32), heights: *const [N]f32) Self {
            return .{
                .body = body,
                .layout = createArrayLayout(N).init(heights),
            };
        }

        pub inline fn getBase(self: *Self) Layout {
            return Layout{ .ptr = self, .vtable = &Self.VTable };
        }

        pub fn next(self: *Self) math.rect.Rect2(f32) {
            var height = self.layout.next();
            if (height < 0) {
                height += self.body.getHeight();
            } else if (height == 0) {
                height = self.body.getHeight();
            }
            const rect = math.rect.Rect2(f32).initVec(
                self.body.pos,
                math.vec.Vec2(f32).init(self.body.getWidth(), height),
            );
            self.body.pos.selfAdd(math.vec.Vec2(f32).init(0, height));
            self.body.size.selfSub(math.vec.Vec2(f32).init(0, height));
            return rect;
        }
    };
}

pub fn createColumnLayout(comptime N: usize) type {
    return struct {
        const Self = @This();
        const VTable = Layout.VTable.create(Self);

        body: math.rect.Rect2(f32),
        layout: createArrayLayout(N),

        pub fn init(body: math.rect.Rect2(f32), widths: *const [N]f32) Self {
            return .{
                .body = body,
                .layout = createArrayLayout(N).init(widths),
            };
        }

        pub inline fn getBase(self: *Self) Layout {
            return Layout{ .ptr = self, .vtable = &Self.VTable };
        }

        pub fn next(self: *Self) math.rect.Rect2(f32) {
            var width = self.layout.next();
            if (width < 0) {
                width += self.body.getWidth();
            } else if (width == 0) {
                width = self.body.getWidth();
            }
            const rect = math.rect.Rect2(f32).initVec(
                self.body.pos,
                math.vec.Vec2(f32).init(width, self.body.getHeight()),
            );
            self.body.pos.selfAdd(math.vec.Vec2(f32).init(width, 0));
            self.body.size.selfSub(math.vec.Vec2(f32).init(width, 0));
            return rect;
        }
    };
}
