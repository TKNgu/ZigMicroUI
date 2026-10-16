const c_microui = @import("c_microui");
const MicroUI = @import("microui.zig").MicroUI;

pub fn uint8Slider(microui: *MicroUI, value: *u8, low: i32, high: i32) i32 {
    const addr = @intFromPtr(value);
    const id = microui.getId(@ptrCast(&addr), @sizeOf(usize));
    microui.id_stack.push(id);
    var tmp: f32 = @floatFromInt(value.*);
    const res = microui.sliderEx(
        &tmp,
        @floatFromInt(low),
        @floatFromInt(high),
        0,
        "%.0f",
        c_microui.MU_OPT_ALIGNCENTER,
    );
    value.* = @intFromFloat(tmp);
    _ = microui.id_stack.pop();
    return res;
}
