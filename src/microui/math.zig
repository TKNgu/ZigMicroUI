pub const Vec2 = extern struct {
    pub const zero: Vec2 = .{ .x = 0, .y = 0 };

    x: i32,
    y: i32,

    pub inline fn init(x: i32, y: i32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub inline fn add(self: *Vec2, v: Vec2) void {
        self.x += v.x;
        self.y += v.y;
    }

    pub inline fn sub(self: *Vec2, v: Vec2) void {
        self.x -= v.x;
        self.y -= v.y;
    }

    pub inline fn addVec2(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub inline fn subVec2(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }
};

pub const Rect = extern struct {
    pub const zero: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 };

    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub inline fn init(x: i32, y: i32, w: i32, h: i32) Rect {
        return .{ .x = x, .y = y, .w = w, .h = h };
    }

    pub inline fn expand(self: Rect, n: i32) Rect {
        return .{
            .x = self.x - n,
            .y = self.y - n,
            .w = self.w + n * 2,
            .h = self.h + n * 2,
        };
    }

    pub inline fn intersect(r1: Rect, r2: Rect) Rect {
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

    pub inline fn contains(self: Rect, p: Vec2) bool {
        return p.x >= self.x and p.x < self.x + self.w and p.y >= self.y and p.y < self.y + self.h;
    }

    pub inline fn move(self: *Rect, v: Vec2) void {
        self.x += v.x;
        self.y += v.y;
    }
};
