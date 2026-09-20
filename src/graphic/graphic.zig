const std = @import("std");
pub const sdl = @import("sdl.zig").sdl;
pub const render = @import("render.zig");
pub const color = @import("color.zig");
pub const math = @import("math.zig");
pub const Renderer = @import("sdl.zig").Renderer;

pub fn initSDL() !void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.print(
            "SDL_Init failed: {s}\n",
            .{sdl.SDL_GetError()},
        );
        return error.SDLInitFailed;
    }
    errdefer sdl.SDL_Quit();

    if (!sdl.TTF_Init()) {
        std.debug.print("TTF_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.TTFInitFailed;
    }
    errdefer sdl.TTF_Quit();
}

pub fn deinitSDL() void {
    sdl.SDL_Quit();
    sdl.TTF_Quit();
}
