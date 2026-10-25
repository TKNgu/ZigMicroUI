const std = @import("std");
const microui_mod = @import("../microui/microui.zig");
const MicroUI = microui_mod.MicroUI;
const LogBuf = @import("../ui/log_window.zig").LogBuf;
const widget = @import("../microui/widget.zig");
const types = @import("../microui/types.zig");

pub fn testWindow(microui: *MicroUI, logbuf: *LogBuf, checks: *[3]i32, bg: *[3]f32) !void {
    if (!(try widget.Window.begin(microui, "Test Window", MicroUI.Rect.init(40, 40, 300, 450), .{}))) return;
    defer widget.Window.end(microui);

    var win = microui.getCurrentContainer();
    win.rect.w = @max(win.rect.w, 240);
    win.rect.h = @max(win.rect.h, 300);

    // window info
    if ((try widget.Header.header(microui, "Window Info", .{})) != 0) {
        win = microui.getCurrentContainer();
        var buf: [64]u8 = undefined;
        microui.setLayoutRow(&[_]i32{ 54, -1 }, 0);
        try widget.Label.label(microui, "Position:");
        var tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.rect.x, win.rect.y }, 0) catch "";
        try widget.Label.label(microui, tmp[0..]);
        try widget.Label.label(microui, "Size:");
        tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.rect.w, win.rect.h }, 0) catch "";
        try widget.Label.label(microui, tmp[0..]);
    }

    // labels + buttons
    if ((try widget.Header.header(microui, "Test Buttons", .{ .opt = microui_mod.Opt.expanded.toInt() })) != 0) {
        microui.setLayoutRow(&[_]i32{ 140, -110, -1 }, 0);
        try widget.Label.label(microui, "Test buttons 1:");
        if ((try widget.Button.button(microui, "Button 1", .{})) != 0) {
            logbuf.write("Pressed button 1");
        }
        if ((try widget.Button.button(microui, "Button 2", .{})) != 0) {
            logbuf.write("Pressed button 2");
        }
        try widget.Label.label(microui, "Test buttons 2:");
        if ((try widget.Button.button(microui, "Button 3", .{})) != 0) {
            logbuf.write("Pressed button 3");
        }
        if ((try widget.Button.button(microui, "Popup", .{})) != 0) {
            widget.Popup.open(microui, "Test Popup");
        }
        if (try widget.Popup.begin(microui, "Test Popup")) {
            defer widget.Popup.end(microui);

            if ((try widget.Button.button(microui, "Hello", .{})) != 0) {
                logbuf.write("Hello");
            }
            if ((try widget.Button.button(microui, "World", .{})) != 0) {
                logbuf.write("World");
            }
        }
    }

    // tree
    if ((try widget.Header.header(microui, "Tree and Text", .{ .opt = microui_mod.Opt.expanded.toInt() })) != 0) {
        microui.setLayoutRow(&[_]i32{ 160, -1 }, 0);
        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            if ((try widget.TreeNode.begin(microui, "Test 1", .{})) != 0) {
                defer widget.TreeNode.end(microui);

                if ((try widget.TreeNode.begin(microui, "Test 1a", .{})) != 0) {
                    defer widget.TreeNode.end(microui);

                    try widget.Label.label(microui, "Hello");
                    try widget.Label.label(microui, "world");
                }
                if ((try widget.TreeNode.begin(microui, "Test 1b", .{})) != 0) {
                    defer widget.TreeNode.end(microui);

                    if ((try widget.Button.button(microui, "Button 1", .{})) != 0) {
                        logbuf.write("Pressed button 1");
                    }
                    if ((try widget.Button.button(microui, "Button 2", .{})) != 0) {
                        logbuf.write("Pressed button 2");
                    }
                }
            }
            if ((try widget.TreeNode.begin(microui, "Test 2", .{})) != 0) {
                defer widget.TreeNode.end(microui);

                microui.setLayoutRow(&[_]i32{ 54, 54 }, 0);
                if ((try widget.Button.button(microui, "Button 3", .{})) != 0) {
                    logbuf.write("Pressed button 3");
                }
                if ((try widget.Button.button(microui, "Button 4", .{})) != 0) {
                    logbuf.write("Pressed button 4");
                }
                if ((try widget.Button.button(microui, "Button 5", .{})) != 0) {
                    logbuf.write("Pressed button 5");
                }
                if ((try widget.Button.button(microui, "Button 6", .{})) != 0) {
                    logbuf.write("Pressed button 6");
                }
            }
            if ((try widget.TreeNode.begin(microui, "Test 3", .{})) != 0) {
                defer widget.TreeNode.end(microui);

                _ = try widget.CheckBox.checkBox(microui, "Checkbox 1", &checks[0]);
                _ = try widget.CheckBox.checkBox(microui, "Checkbox 2", &checks[1]);
                _ = try widget.CheckBox.checkBox(microui, "Checkbox 3", &checks[2]);
            }
        }

        {
            microui.layoutBeginColumn();
            defer microui.layoutEndColumn();

            microui.setLayoutRow(&[_]i32{-1}, 0);
            try widget.Text.text(microui,
                \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                \\ Maecenas lacinia, sem eu lacinia molestie, 
                \\ mi risus faucibus ipsum, eu varius magna felis a nulla.
            );
        }
    }

    // background color sliders
    if ((try widget.Header.header(microui, "Background Color", .{ .opt = microui_mod.Opt.expanded.toInt() })) != 0) {
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
            try widget.Label.label(microui, "Red:");
            _ = try widget.Slider.uint8Slider(microui, &col.r, 0, 255);
            try widget.Label.label(microui, "Green:");
            _ = try widget.Slider.uint8Slider(microui, &col.g, 0, 255);
            try widget.Label.label(microui, "Blue:");
            _ = try widget.Slider.uint8Slider(microui, &col.b, 0, 255);
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
        try widget.Label.controlText(microui, view[0..], rect, .text, microui_mod.Opt.align_center.toInt());
    }
}
