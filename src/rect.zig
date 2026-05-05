const microui = @import("sdl.zig").microui;
const Context = @import("context.zig").Context;

pub const Rect = struct {
    rect: microui.mu_Rect,

    pub fn init(x: i32, y: i32, w: i32, h: i32) Rect {
        return .{ .rect = .{ .x = x, .y = y, .w = w, .h = h } };
    }

    pub fn getRect(self: *const Rect) microui.mu_Rect {
        return self.rect;
    }

    pub fn intersects(self: *const Rect, tmp: *const Rect) Rect {
        const r1 = self.rect;
        const r2 = tmp.rect;
        const x1 = @max(r1.x, r2.x);
        const y1 = @max(r1.y, r2.y);
        var x2 = @min(r1.x + r1.w, r2.x + r2.w);
        var y2 = @min(r1.y + r1.h, r2.y + r2.h);
        if (x2 < x1) {
            x2 = x1;
        }
        if (y2 < y1) {
            y2 = y1;
        }
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }
};
