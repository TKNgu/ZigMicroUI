const std = @import("std");
const c_microui = @import("c_microui");

pub const MicroUI = struct {
    mu_context: *c_microui.mu_Context,

    pub fn init(mu_context: *c_microui.mu_Context) MicroUI {
        return .{
            .mu_context = mu_context,
        };
    }

    pub fn drawLabel(self: *MicroUI, label: [:0]const u8) void {
        c_microui.mu_draw_control_text(
            self.mu_context,
            label,
            c_microui.mu_layout_next(self.mu_context),
            c_microui.MU_COLOR_TEXT,
            0,
        );
    }

    pub fn drawText(self: *MicroUI, text: []const u8) void {
        c_microui.mu_text(self.mu_context, &text[0]);
    }

    pub fn drawTextBox(self: *MicroUI, text: []u8) usize {
        const tmp: [*c]u8 = @ptrCast(&text[0]);
        return @as(usize, @intCast(c_microui.mu_textbox(
            self.mu_context,
            tmp,
            @as(c_int, @intCast(text.len)),
        )));
    }

    pub fn drawButton(self: *MicroUI, label: [:0]const u8) i32 {
        return c_microui.mu_button(self.mu_context, label);
    }

    pub fn drawRect(self: *MicroUI, rect: c_microui.mu_Rect, color: c_microui.mu_Color) void {
        c_microui.mu_draw_rect(self.mu_context, rect, color);
    }

    pub fn beginWindow(self: *MicroUI, title: [:0]const u8, rect: c_microui.mu_Rect) !void {
        if (c_microui.mu_begin_window(self.mu_context, title, rect) == 0) {
            return error.BeginWindowFailed;
        }
    }

    pub fn endWindow(self: *MicroUI) void {
        c_microui.mu_end_window(self.mu_context);
    }

    pub fn layoutRow(self: *MicroUI, widths: []const i32, height: i32) void {
        const layout: [*c]const c_int = @ptrCast(&widths[0]);
        c_microui.mu_layout_row(self.mu_context, @intCast(widths.len), layout, height);
    }

    pub fn beginPanel(self: *MicroUI, name: [:0]const u8) void {
        c_microui.mu_begin_panel(self.mu_context, name);
    }

    pub fn endPanel(self: *MicroUI) void {
        c_microui.mu_end_panel(self.mu_context);
    }

    pub fn getCurrentContainer(self: *MicroUI) *c_microui.mu_Container {
        return c_microui.mu_get_current_container(self.mu_context);
    }
};
