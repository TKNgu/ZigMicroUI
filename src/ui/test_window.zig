const std = @import("std");
const c_microui = @import("c_microui");
const MicroUI = @import("../microui/microui.zig").MicroUI;
const LogBuf = @import("../ui/log_window.zig").LogBuf;
const uint8Slider = @import("../microui/slider.zig").uint8Slider;

pub fn testWindow(microui: *MicroUI, logbuf: *LogBuf, checks: *[3]i32, bg: *[3]f32) !void {
    if (!microui.beginWindow("Test Window", c_microui.mu_rect(40, 40, 300, 450))) return;
    defer microui.endWindow();

    var win = microui.getCurrentContainer();
    win.*.rect.w = @max(win.*.rect.w, 240);
    win.*.rect.h = @max(win.*.rect.h, 300);

    // window info
    if (microui.header("Window Info") != 0) {
        win = microui.getCurrentContainer();
        var buf: [64]u8 = undefined;
        microui.layoutRow(&[_]i32{ 54, -1 }, 0);
        microui.drawLabel("Position:");
        var tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.*.rect.x, win.*.rect.y }, 0) catch unreachable;
        microui.drawLabel(tmp[0..]);
        microui.drawLabel("Size:");
        tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.*.rect.w, win.*.rect.h }, 0) catch unreachable;
        microui.drawLabel(tmp[0..]);
    }

    // labels + buttons
    if (microui.headerEx("Test Buttons", c_microui.MU_OPT_EXPANDED) != 0) {
        microui.layoutRow(&[_]i32{ 140, -110, -1 }, 0);
        microui.drawLabel("Test buttons 1:");
        if (microui.button("Button 1") != 0) {
            logbuf.write("Pressed button 1");
        }
        if (microui.button("Button 2") != 0) {
            logbuf.write("Pressed button 2");
        }
        microui.drawLabel("Test buttons 2:");
        if (microui.button("Button 3") != 0) {
            logbuf.write("Pressed button 3");
        }
        if (microui.button("Popup") != 0) {
            microui.openPopup("Test Popup");
        }
        if (microui.beginPopup("Test Popup") != 0) {
            defer microui.endPopup();

            if (microui.button("Hello") != 0) {
                logbuf.write("Hello");
            }
            if (microui.button("World") != 0) {
                logbuf.write("World");
            }
        }
    }

    // tree
    if (microui.headerEx("Tree and Text", c_microui.MU_OPT_EXPANDED) != 0) {
        microui.layoutRow(&[_]i32{ 160, -1 }, 0);
        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            if (microui.beginTreenode("Test 1") != 0) {
                defer microui.endTreenode();

                if (microui.beginTreenode("Test 1a") != 0) {
                    defer microui.endTreenode();

                    microui.drawLabel("Hello");
                    microui.drawLabel("world");
                }
                if (microui.beginTreenode("Test 1b") != 0) {
                    defer microui.endTreenode();

                    if (microui.button("Button 1") != 0) {
                        logbuf.write("Pressed button 1");
                    }
                    if (microui.button("Button 2") != 0) {
                        logbuf.write("Pressed button 2");
                    }
                }
            }
            if (microui.beginTreenode("Test 2") != 0) {
                defer microui.endTreenode();

                microui.layoutRow(&[_]i32{ 54, 54 }, 0);
                if (microui.button("Button 3") != 0) {
                    logbuf.write("Pressed button 3");
                }
                if (microui.button("Button 4") != 0) {
                    logbuf.write("Pressed button 4");
                }
                if (microui.button("Button 5") != 0) {
                    logbuf.write("Pressed button 5");
                }
                if (microui.button("Button 6") != 0) {
                    logbuf.write("Pressed button 6");
                }
            }
            if (microui.beginTreenode("Test 3") != 0) {
                defer microui.endTreenode();

                _ = microui.checkBox("Checkbox 1", &checks[0]);
                _ = microui.checkBox("Checkbox 2", &checks[1]);
                _ = microui.checkBox("Checkbox 3", &checks[2]);
            }
        }

        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            microui.layoutRow(&[_]i32{-1}, 0);
            microui.drawText(
                \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                \\ Maecenas lacinia, sem eu lacinia molestie, 
                \\ mi risus faucibus ipsum, eu varius magna felis a nulla.
            );
        }
    }

    // background color sliders
    if (microui.headerEx("Background Color", c_microui.MU_OPT_EXPANDED) != 0) {
        microui.layoutRow(&[_]i32{ -78, -1 }, 74);
        // sliders
        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            var color: c_microui.mu_Color = .{
                .r = @intFromFloat(bg[0]),
                .g = @intFromFloat(bg[1]),
                .b = @intFromFloat(bg[2]),
                .a = 255,
            };
            defer bg.* = .{
                @floatFromInt(color.r),
                @floatFromInt(color.g),
                @floatFromInt(color.b),
            };

            microui.layoutRow(&[_]i32{ 60, -1 }, 0);
            microui.drawLabel("Red:");
            _ = uint8Slider(microui, &color.r, 0, 255);
            microui.drawLabel("Green:");
            _ = uint8Slider(microui, &color.g, 0, 255);
            microui.drawLabel("Blue:");
            _ = uint8Slider(microui, &color.b, 0, 255);
        }
        // color preview
        const rect = microui.layoutNext();
        const color: c_microui.mu_Color = .{
            .r = @intFromFloat(bg[0]),
            .g = @intFromFloat(bg[1]),
            .b = @intFromFloat(bg[2]),
            .a = 255,
        };
        microui.drawRect(rect, color);
        var buf: [32]u8 = undefined;
        const view = std.fmt.bufPrintSentinel(&buf, "#{x:02}{x:02}{x:02}", .{ color.r, color.g, color.b }, 0) catch unreachable;
        microui.drawControlText(view[0..], rect, c_microui.MU_COLOR_TEXT, c_microui.MU_OPT_ALIGNCENTER);
    }
}
