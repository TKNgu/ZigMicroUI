pub const microui = @cImport({
    @cInclude("microui.h");
});
pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
pub const atlas = @cImport({
    @cInclude("atlas.h");
});
