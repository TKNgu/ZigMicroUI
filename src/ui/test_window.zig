const std = @import("std");
const microui_mod = @import("../microui/microui.zig");
const MicroUI = microui_mod.MicroUI;
const LogBuf = @import("../ui/log_window.zig").LogBuf;
const uint8Slider = @import("../microui/slider.zig").uint8Slider;

pub fn testWindow(microui: *MicroUI, logbuf: *LogBuf, checks: *[3]i32, bg: *[3]f32) !void {
    if (!(try microui.beginWindow("Test Window", MicroUI.Rect.init(40, 40, 300, 450)))) return;
    defer microui.endWindow();

    var win = microui.getCurrentContainer();
    win.rect.w = @max(win.rect.w, 240);
    win.rect.h = @max(win.rect.h, 300);

    // window info
    if ((try microui.header("Window Info")) != 0) {
        win = microui.getCurrentContainer();
        var buf: [64]u8 = undefined;
        microui.setLayoutRow(&[_]i32{ 54, -1 }, 0);
        try microui.drawLabel("Position:");
        var tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.rect.x, win.rect.y }, 0) catch "";
        try microui.drawLabel(tmp[0..]);
        try microui.drawLabel("Size:");
        tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.rect.w, win.rect.h }, 0) catch "";
        try microui.drawLabel(tmp[0..]);
    }

    // labels + buttons
    if ((try microui.headerEx("Test Buttons", microui_mod.Opt.EXPANDED)) != 0) {
        microui.setLayoutRow(&[_]i32{ 140, -110, -1 }, 0);
        try microui.drawLabel("Test buttons 1:");
        if ((try microui.button("Button 1")) != 0) {
            logbuf.write("Pressed button 1");
        }
        if ((try microui.button("Button 2")) != 0) {
            logbuf.write("Pressed button 2");
        }
        try microui.drawLabel("Test buttons 2:");
        if ((try microui.button("Button 3")) != 0) {
            logbuf.write("Pressed button 3");
        }
        if ((try microui.button("Popup")) != 0) {
            microui.openPopup("Test Popup");
        }
        if ((try microui.beginPopup("Test Popup")) != 0) {
            defer microui.endPopup();

            if ((try microui.button("Hello")) != 0) {
                logbuf.write("Hello");
            }
            if ((try microui.button("World")) != 0) {
                logbuf.write("World");
            }
        }
    }

    // tree
    if ((try microui.headerEx("Tree and Text", microui_mod.Opt.EXPANDED)) != 0) {
        microui.setLayoutRow(&[_]i32{ 160, -1 }, 0);
        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            if ((try microui.beginTreenode("Test 1")) != 0) {
                defer microui.endTreenode();

                if ((try microui.beginTreenode("Test 1a")) != 0) {
                    defer microui.endTreenode();

                    try microui.drawLabel("Hello");
                    try microui.drawLabel("world");
                }
                if ((try microui.beginTreenode("Test 1b")) != 0) {
                    defer microui.endTreenode();

                    if ((try microui.button("Button 1")) != 0) {
                        logbuf.write("Pressed button 1");
                    }
                    if ((try microui.button("Button 2")) != 0) {
                        logbuf.write("Pressed button 2");
                    }
                }
            }
            if ((try microui.beginTreenode("Test 2")) != 0) {
                defer microui.endTreenode();

                microui.setLayoutRow(&[_]i32{ 54, 54 }, 0);
                if ((try microui.button("Button 3")) != 0) {
                    logbuf.write("Pressed button 3");
                }
                if ((try microui.button("Button 4")) != 0) {
                    logbuf.write("Pressed button 4");
                }
                if ((try microui.button("Button 5")) != 0) {
                    logbuf.write("Pressed button 5");
                }
                if ((try microui.button("Button 6")) != 0) {
                    logbuf.write("Pressed button 6");
                }
            }
            if ((try microui.beginTreenode("Test 3")) != 0) {
                defer microui.endTreenode();

                _ = try microui.checkBox("Checkbox 1", &checks[0]);
                _ = try microui.checkBox("Checkbox 2", &checks[1]);
                _ = try microui.checkBox("Checkbox 3", &checks[2]);
            }
        }

        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            microui.setLayoutRow(&[_]i32{-1}, 0);
            try microui.drawText(
                \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                \\ Maecenas lacinia, sem eu lacinia molestie, 
                \\ mi risus faucibus ipsum, eu varius magna felis a nulla.
            );
        }
    }

    // background color sliders
    if ((try microui.headerEx("Background Color", microui_mod.Opt.EXPANDED)) != 0) {
        microui.setLayoutRow(&[_]i32{ -78, -1 }, 74);
        // sliders
        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            var col = MicroUI.Color.init(
                @intFromFloat(bg[0]),
                @intFromFloat(bg[1]),
                @intFromFloat(bg[2]),
                255,
            );
            defer bg.* = .{
                @floatFromInt(col.r),
                @floatFromInt(col.g),
                @floatFromInt(col.b),
            };

            microui.setLayoutRow(&[_]i32{ 60, -1 }, 0);
            try microui.drawLabel("Red:");
            _ = try uint8Slider(microui, &col.r, 0, 255);
            try microui.drawLabel("Green:");
            _ = try uint8Slider(microui, &col.g, 0, 255);
            try microui.drawLabel("Blue:");
            _ = try uint8Slider(microui, &col.b, 0, 255);
        }
        // color preview
        const rect = microui.layoutNext();
        const preview_color = MicroUI.Color.init(
            @intFromFloat(bg[0]),
            @intFromFloat(bg[1]),
            @intFromFloat(bg[2]),
            255,
        );
        try microui.drawRect(rect, preview_color);
        var buf: [32]u8 = undefined;
        const view = std.fmt.bufPrintSentinel(&buf, "#{x:02}{x:02}{x:02}", .{ preview_color.r, preview_color.g, preview_color.b }, 0) catch "";
        try microui.drawControlText(view[0..], rect, MicroUI.COLOR_TEXT, microui_mod.Opt.ALIGNCENTER);
    }
}
