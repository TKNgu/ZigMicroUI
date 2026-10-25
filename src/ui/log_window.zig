const std = @import("std");
const microui_mod = @import("../microui/microui.zig");
const MicroUI = microui_mod.MicroUI;
const widget = @import("../microui/widget.zig");

pub const LogBuf = struct {
    buf: [64000:0]u8 = [_:0]u8{0} ** 64000,
    offset: usize = 0,
    updated: bool = false,

    pub fn init() LogBuf {
        return .{};
    }

    pub fn write(self: *LogBuf, text: []const u8) void {
        if (self.offset + text.len + 2 > self.buf.len) return;
        @memcpy(self.buf[self.offset .. self.offset + text.len], text);
        self.offset += text.len;
        self.buf[self.offset] = '\n';
        self.offset += 1;
        self.buf[self.offset] = 0;
        self.updated = true;
    }
};

var log_input_buf: [128:0]u8 = [_:0]u8{0} ** 128;

pub fn logWindow(microui: *MicroUI, logbuf: *LogBuf) !void {
    if (!(try widget.Window.begin(microui, "Log Window", MicroUI.Rect.init(350, 40, 300, 200), .{}))) return;
    defer widget.Window.end(microui);

    microui.setLayoutRow(&[_]i32{-1}, -25);
    {
        try widget.Panel.begin(microui, "Log Output", .{});
        defer widget.Panel.end(microui);

        const panel = microui.getCurrentContainer();
        if (logbuf.updated) {
            panel.scroll.y = panel.content_size.y;
            logbuf.updated = false;
        }

        microui.setLayoutRow(&[_]i32{-1}, -1);
        try widget.Text.text(microui, std.mem.sliceTo(&logbuf.buf, 0));
    }

    var submitted: i32 = 0;
    microui.setLayoutRow(&[_]i32{ -70, -1 }, 0);
    if (microui_mod.Res.has(try widget.TextBox.textBox(microui, &log_input_buf, 128, .{}), .submit)) {
        const addr = @intFromPtr(&log_input_buf);
        microui.setFocus(microui.getId(@ptrCast(&addr), @sizeOf(usize)));
        submitted = 1;
    }
    if ((try widget.Button.button(microui, "Submit", .{})) != 0) {
        submitted = 1;
    }
    if (submitted != 0) {
        const text_slice = std.mem.sliceTo(&log_input_buf, 0);
        if (text_slice.len > 0) {
            logbuf.write(text_slice);
        }
        log_input_buf[0] = 0;
    }
}
