const c_microui = @import("c_microui");

pub const Vec2 = extern struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn init(x: i32, y: i32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn toMu(self: Vec2) c_microui.mu_Vec2 {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn fromMu(v: c_microui.mu_Vec2) Vec2 {
        return .{ .x = v.x, .y = v.y };
    }
};

pub fn vec2(x: i32, y: i32) Vec2 {
    return .{ .x = x, .y = y };
}

pub const Rect = extern struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,

    pub fn init(x: i32, y: i32, w: i32, h: i32) Rect {
        return .{ .x = x, .y = y, .w = w, .h = h };
    }

    pub fn toMu(self: Rect) c_microui.mu_Rect {
        return .{ .x = self.x, .y = self.y, .w = self.w, .h = self.h };
    }

    pub fn fromMu(r: c_microui.mu_Rect) Rect {
        return .{ .x = r.x, .y = r.y, .w = r.w, .h = r.h };
    }

    pub fn expand(self: Rect, n: i32) Rect {
        return .{
            .x = self.x - n,
            .y = self.y - n,
            .w = self.w + n * 2,
            .h = self.h + n * 2,
        };
    }

    pub fn intersect(r1: Rect, r2: Rect) Rect {
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

    pub fn overlapsVec2(self: Rect, p: Vec2) bool {
        return p.x >= self.x and p.x < self.x + self.w and p.y >= self.y and p.y < self.y + self.h;
    }
};

pub fn rect(x: i32, y: i32, w: i32, h: i32) Rect {
    return .{ .x = x, .y = y, .w = w, .h = h };
}
