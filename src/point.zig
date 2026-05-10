pub const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Point {
        return Point{
            .x = x,
            .y = y,
        };
    }
};
