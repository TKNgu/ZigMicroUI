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
pub fn createRowLayout(comptime N: usize) type {
    return struct {
        index: usize,
        widths: [N]f32,
        height: f32,

        pub fn init(widths: *const [N]f32, height: f32) @This() {
            var layout = @This(){
                .index = 0,
                .widths = undefined,
                .height = height,
            };
            std.mem.copyForwards(f32, &layout.widths, widths);
            return layout;
        }

        pub fn next(self: *@This()) math.vec.Vec2(f32) {
            if (self.index >= N) {
                self.index = 0;
            }
            const width = self.widths[self.index];
            self.index += 1;
            return math.vec.Vec2(f32).init(width, self.height);
        }

        pub inline fn getIsEnd(self: @This()) bool {
            return self.index >= N;
        }

        pub inline fn nextLine(self: *@This()) void {
            self.index = 0;
        }
    };
}

pub fn createLayout(comptime N: usize) type {
    return struct {
        body: math.rect.Rect2(f32),
        position: math.vec.Vec2(f32),
        row_layout: createRowLayout(N),

        pub fn init(body: math.rect.Rect2(f32), widths: *const [N]f32, height: f32) @This() {
            return .{
                .body = body,
                .position = body.pos,
                .row_layout = createRowLayout(N).init(widths, height),
            };
        }

        pub fn next(self: *@This()) math.rect.Rect2(f32) {
            var size = self.row_layout.next();
            if (size.x < 0) {
                size.x += self.body.getWidth() - self.position.x;
            }
            const rect = math.rect.Rect2(f32).initVec(self.position, size);
            if (self.row_layout.getIsEnd()) {
                self.position.x = self.body.getX();
                self.position.y += self.row_layout.height;
            } else {
                self.position.x += size.x;
            }
            return rect;
        }

        pub inline fn nextLine(self: *@This()) void {
            self.row_layout.nextLine();
            self.position.x = self.body.getX();
            self.position.y += self.row_layout.height;
        }
    };
}

// Window
pub fn drawWindow(
    render_engine: *render.RenderEngine,
    window_style: *const style.Style,
    window_rect: math.rect.Rect2(f32),
) !void {
    try drawFrame(
        render_engine,
        window_rect,
        window_style.*.window_color,
        window_style.*.window_border_color,
    );

    const titlebar_rect = math.rect.Rect2(f32).init(
        window_rect.getX(),
        window_rect.getY(),
        window_rect.getWidth(),
        window_style.*.window_titlebar_size,
    );
    try drawFrame(
        render_engine,
        titlebar_rect,
        window_style.*.window_titlebar_color,
        window_style.*.window_titlebar_border_color,
    );

    const tilebar_close_size = titlebar_rect.getHeight() - 4;
    const titlebar_close_rect = math.rect.Rect2(f32).init(
        titlebar_rect.getX() + titlebar_rect.getWidth() - tilebar_close_size - 2,
        titlebar_rect.getY() + 2,
        tilebar_close_size,
        tilebar_close_size,
    );
    try drawFrame(
        render_engine,
        titlebar_close_rect,
        window_style.*.button_color,
        window_style.*.window_titlebar_border_color,
    );

    const statusbar_rect = math.rect.Rect2(f32).init(
        window_rect.getX(),
        window_rect.getY() + window_rect.getHeight() - window_style.*.window_statusbar_size,
        window_rect.getWidth(),
        window_style.*.window_statusbar_size,
    );
    try drawFrame(
        render_engine,
        statusbar_rect,
        window_style.*.window_statusbar_color,
        window_style.*.window_statusbar_border_color,
    );

    const statusbar_control_size = statusbar_rect.getHeight() - 4;
    const statusbar_control_rect = math.rect.Rect2(f32).init(
        statusbar_rect.getX() + statusbar_rect.getWidth() - statusbar_control_size - 2,
        statusbar_rect.getY() + 2,
        statusbar_control_size,
        statusbar_control_size,
    );
    try drawFrame(
        render_engine,
        statusbar_control_rect,
        window_style.*.button_color,
        window_style.*.window_statusbar_border_color,
    );
}
