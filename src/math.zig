pub const vec = struct {
    pub fn Vec2(comptime T: type) type {
        return struct {
            x: T,
            y: T,

            pub fn init(x: T, y: T) Vec2(@TypeOf(x)) {
                return Vec2(@TypeOf(x)){
                    .x = x,
                    .y = y,
                };
            }
        };
    }
};

pub const rect = struct {
    pub fn Rect2(comptime T: type) type {
        return struct {
            pos: vec.Vec2(T),
            size: vec.Vec2(T),

            pub fn init(pos: vec.Vec2(T), size: vec.Vec2(T)) Rect2(@TypeOf(pos.x)) {
                return Rect2(@TypeOf(pos.x)){
                    .pos = pos,
                    .size = size,
                };
            }
        };
    }
};
