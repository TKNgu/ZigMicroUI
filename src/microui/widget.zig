const std = @import("std");
const microui = @import("microui.zig");
const math = @import("math.zig");
const Opt = @import("types.zig").Opt;
const style = @import("style.zig");
const types = @import("types.zig");
const container_mod = @import("container.zig");

pub const Window = struct {
    pub const WindowOpt = struct {
        opt: i32 = 0,
    };

    pub fn begin(context: *microui.MicroUI, title: [:0]const u8, rect: math.Rect, opt: WindowOpt) !bool {
        const id = context.getId(title.ptr, title.len);
        const cnt = context.getContainer(id, opt.opt) orelse return false;
        if (!cnt.is_open) {
            return false;
        }
        context.pushId(id);
        if (cnt.rect.w == 0) {
            cnt.rect = rect;
        }
        try context.beginRootContainer(cnt);
        var body = cnt.rect;
        if (!Opt.has(opt.opt, .no_frame)) {
            try context.drawFrame(body, style.ColorId.window_bg);
        }
        if (!Opt.has(opt.opt, .no_title)) {
            var tr = math.Rect.init(
                body.x,
                body.y,
                body.w,
                context.getStyle().title_height,
            );
            try context.drawFrame(tr, style.ColorId.title_bg);

            {
                const title_id = context.getId("!title", 6);
                context.updateControl(title_id, tr, opt.opt);
                try Label.controlText(context, title, tr, style.ColorId.title_text, opt.opt);
                if (title_id == context.getFocus() and context.isMouseDown(.left)) {
                    const delta = context.getMouseDelta();
                    cnt.rect.x += delta.x;
                    cnt.rect.y += delta.y;
                }
                body.y += tr.h;
                body.h -= tr.h;
            }

            if (!Opt.has(opt.opt, .no_close)) {
                const close_id = context.getId("!close", 6);
                const close_rect = math.Rect.init(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h);
                tr.w -= close_rect.w;
                try context.drawIcon(
                    .close,
                    close_rect,
                    context.getStyle().getColor(.title_text),
                );
                context.updateControl(close_id, close_rect, opt.opt);
                if (context.isPressed(.left) and close_id == context.getFocus()) {
                    cnt.is_open = false;
                }
            }
        }
        try context.pushContainerBody(cnt, body, opt.opt);

        if (!Opt.has(opt.opt, .no_resize)) {
            const size = context.getStyle().title_height;
            const resize_id = context.getId("!resize", 7);
            const resize_rect = math.Rect.init(
                body.x + body.w - size,
                body.y + body.h - size,
                size,
                size,
            );
            context.updateControl(resize_id, resize_rect, opt.opt);
            if (resize_id == context.getFocus() and context.isMouseDown(.left)) {
                const delta = context.getMouseDelta();
                cnt.rect.w = @max(96, cnt.rect.w + delta.x);
                cnt.rect.h = @max(64, cnt.rect.h + delta.y);
            }
        }

        if (Opt.has(opt.opt, .auto_size)) {
            const r = context.getLayout().body;
            cnt.rect.w = cnt.content_size.x + (cnt.rect.w - r.w);
            cnt.rect.h = cnt.content_size.y + (cnt.rect.h - r.h);
        }

        if (Opt.has(opt.opt, .popup) and context.hasPressed() and
            !context.isHoverRoot(cnt))
        {
            cnt.is_open = false;
        }

        context.pushClipRect(cnt.body);
        return true;
    }

    pub fn end(context: *microui.MicroUI) void {
        _ = context.popClip();
        context.endRootContainer();
    }
};

pub const Popup = struct {
    /// Mở một cửa sổ popup tại vị trí chuột hiện tại.
    pub fn open(context: *microui.MicroUI, name: [:0]const u8) void {
        const cnt = context.getContainerByName(name) orelse return;
        context.setPopup(cnt);
        const pos = context.getMousePos();
        cnt.*.rect = .init(pos.x, pos.y, 1, 1);
        cnt.*.is_open = true;
        context.bringToFront(cnt);
    }

    /// Bắt đầu render nội dung của popup đã được mở.
    pub fn begin(context: *microui.MicroUI, name: [:0]const u8) !bool {
        const opt = Opt.combine(&.{ .popup, .auto_size, .no_resize, .no_scroll, .no_title, .closed });
        return try Window.begin(context, name, .init(0, 0, 0, 0), .{ .opt = opt });
    }

    /// Kết thúc render popup.
    pub const end = Window.end;
};

pub const Panel = struct {
    pub const PanelOpt = struct {
        opt: i32 = 0,
    };

    /// Bắt đầu một bảng con (Panel) kèm tùy chọn `PanelOpt`.
    pub fn begin(context: *microui.MicroUI, name: [:0]const u8, opt: PanelOpt) !void {
        const id = context.getId(name.ptr, name.len);
        const cnt = context.getContainer(id, opt.opt) orelse return error.OutOfContainers;
        context.pushId(id);
        const tmp = context.layoutNext();
        cnt.*.rect = tmp;
        if (!Opt.has(opt.opt, .no_frame)) {
            try context.drawFrame(tmp, style.ColorId.panel_bg);
        }
        context.pushContainer(cnt);
        errdefer context.popContainer();
        try context.pushContainerBody(cnt, tmp, opt.opt);
        context.pushClipRect(cnt.*.body);
    }

    /// Kết thúc bảng con.
    pub inline fn end(context: *microui.MicroUI) void {
        _ = context.popClip();
        context.popContainer();
    }
};

pub const TreeNode = struct {
    pub const TreeNodeOpt = struct {
        opt: i32 = 0,
    };

    pub fn begin(context: *microui.MicroUI, label: [:0]const u8, opt: TreeNodeOpt) !i32 {
        const res = try Header.headerInternal(context, label, true, opt.opt);
        if (types.Res.has(res, .active)) {
            context.getLayout().indent += context.getStyle().indent;
            context.pushId(context.getLastId());
        }
        return res;
    }

    pub fn end(context: *microui.MicroUI) void {
        context.getLayout().indent -= context.getStyle().indent;
        _ = context.popId();
    }
};

pub const Header = struct {
    pub const HeaderOpt = struct {
        opt: i32 = 0,
    };

    pub fn header(context: *microui.MicroUI, label: [:0]const u8, opt: HeaderOpt) !i32 {
        return Header.headerInternal(context, label, false, opt.opt);
    }

    pub fn headerInternal(context: *microui.MicroUI, label: [:0]const u8, is_treenode: bool, opt: i32) !i32 {
        const id = context.getId(label.ptr, label.len);

        context.setLayoutRow(&[_]i32{-1}, 0);

        const item = context.treenode_pool.get(id);
        var active = (item != null);
        const expanded = if (Opt.has(opt, .expanded)) !active else active;
        var r = context.layoutNext();
        context.updateControl(id, r, 0);

        if (context.isPressed(.left) and context.getFocus() == id) {
            active = !active;
        }

        if (item) |idx| {
            if (active) {
                idx.refresh(context.frame);
            } else {
                idx.reset();
            }
        } else if (active) {
            _ = context.treenode_pool.allocAndInit(.{}, id, context.frame);
        }

        if (is_treenode) {
            if (context.getHover() == id) {
                try context.drawFrame(r, style.ColorId.button_hover);
            }
        } else {
            try context.drawControlFrame(id, r, .button, 0);
        }

        const icon_id: types.Icon = if (expanded) .expanded else .collapsed;
        try context.drawIcon(icon_id, .init(r.x, r.y, r.h, r.h), context.getStyle().getColor(.text));
        r.x += r.h - context.getStyle().padding;
        r.w -= r.h - context.getStyle().padding;
        try Label.controlText(context, label.ptr, r, .text, 0);

        return if (expanded) types.Res.active.toInt() else 0;
    }
};

pub const Button = struct {
    pub const ButtonOpt = struct {
        icon: types.Icon = .none,
        opt: Opt = Opt.align_center,
    };

    pub fn button(context: *microui.MicroUI, label: ?[:0]const u8, opt: ButtonOpt) !i32 {
        var res: i32 = 0;
        const id = if (label) |l|
            context.getId(l.ptr, l.len)
        else
            context.getId(&opt.icon, @sizeOf(types.Icon));

        const r = context.layoutNext();
        context.updateControl(id, r, opt.opt.toInt());
        if (context.isPressed(.left) and context.getFocus() == id) {
            res |= types.Res.submit.toInt();
        }
        try context.drawControlFrame(id, r, .button, opt.opt.toInt());
        if (label) |l| {
            try Label.controlText(context, l.ptr, r, .text, opt.opt.toInt());
        }
        if (opt.icon != .none) {
            try context.drawIcon(opt.icon, r, context.getStyle().getColor(.text));
        }
        return res;
    }
};

pub fn formatReal(buf: []u8, fmt: [*c]const u8, val: f32) [:0]const u8 {
    if (buf.len == 0) return "";
    const span = if (fmt != null) std.mem.span(fmt) else "";
    var precision: ?usize = null;
    if (std.mem.indexOfScalar(u8, span, '.')) |dot_idx| {
        var p: usize = 0;
        var i = dot_idx + 1;
        while (i < span.len and std.ascii.isDigit(span[i])) : (i += 1) {
            p = p * 10 + (span[i] - '0');
        }
        if (i > dot_idx + 1) {
            precision = p;
        }
    }
    if (precision) |prec| {
        return switch (prec) {
            0 => std.fmt.bufPrintSentinel(buf, "{d:.0}", .{val}, 0) catch "",
            1 => std.fmt.bufPrintSentinel(buf, "{d:.1}", .{val}, 0) catch "",
            2 => std.fmt.bufPrintSentinel(buf, "{d:.2}", .{val}, 0) catch "",
            3 => std.fmt.bufPrintSentinel(buf, "{d:.3}", .{val}, 0) catch "",
            4 => std.fmt.bufPrintSentinel(buf, "{d:.4}", .{val}, 0) catch "",
            5 => std.fmt.bufPrintSentinel(buf, "{d:.5}", .{val}, 0) catch "",
            else => std.fmt.bufPrintSentinel(buf, "{d:.2}", .{val}, 0) catch "",
        };
    } else {
        return std.fmt.bufPrintSentinel(buf, "{d}", .{val}, 0) catch "";
    }
}

pub const Number = struct {
    pub const NumberOpt = struct {
        step: f32 = 0,
        fmt: [*c]const u8 = microui.SLIDER_FMT,
        opt: i32 = Opt.align_center.toInt(),
    };

    pub fn number(context: *microui.MicroUI, value: *f32, opt: NumberOpt) !i32 {
        var buf: [types.MAX_FMT + 1]u8 = undefined;
        var res: i32 = 0;
        const id = context.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = context.layoutNext();
        const last = value.*;

        if (try TextBox.numberTextbox(context, value, base, id)) {
            return res;
        }

        context.updateControl(id, base, opt.opt);

        if (context.getFocus() == id and context.isMouseDown(.left)) {
            const delta = context.getMouseDelta();
            value.* += @as(f32, @floatFromInt(delta.x)) * opt.step;
        }

        if (value.* != last) {
            res |= types.Res.change.toInt();
        }

        try context.drawControlFrame(id, base, .base, opt.opt);

        const formatted = formatReal(&buf, opt.fmt, value.*);
        try Label.controlText(context, formatted.ptr, base, .text, opt.opt);

        return res;
    }
};

pub const Slider = struct {
    pub const SliderOpt = struct {
        step: f32 = 0,
        fmt: [*c]const u8 = microui.SLIDER_FMT,
        opt: i32 = Opt.align_center.toInt(),
    };

    pub fn slider(context: *microui.MicroUI, value: *f32, low: f32, high: f32, opt: SliderOpt) !i32 {
        var buf: [types.MAX_FMT + 1]u8 = undefined;
        var res: i32 = 0;
        const last = value.*;
        var v = last;
        const id = context.getId(@ptrCast(&value), @sizeOf(*f32));
        const base = context.layoutNext();

        if (try TextBox.numberTextbox(context, &v, base, id)) {
            return res;
        }

        context.updateControl(id, base, opt.opt);

        if (context.getFocus() == id and context.isDownOrPressed(.left)) {
            if (base.w > 0) {
                const pos = context.getMousePos();
                v = low + @as(f32, @floatFromInt(pos.x - base.x)) * (high - low) / @as(f32, @floatFromInt(base.w));
                if (opt.step > 0) {
                    v = @round((v + opt.step / 2.0) / opt.step) * opt.step;
                }
            }
        }

        v = std.math.clamp(v, low, high);
        value.* = v;
        if (last != v) {
            res |= types.Res.change.toInt();
        }

        try context.drawControlFrame(id, base, .base, opt.opt);

        var thumb = base;
        const w = context.getStyle().thumb_size;
        thumb.w = w;
        const range = high - low;
        if (range > 0 and base.w > w) {
            thumb.x += @intFromFloat(@as(f32, @floatFromInt(base.w - w)) * (v - low) / range);
        }
        try context.drawControlFrame(id, thumb, .button, opt.opt);

        const formatted = formatReal(&buf, opt.fmt, value.*);
        try Label.controlText(context, formatted.ptr, base, .text, opt.opt);

        return res;
    }

    pub fn uint8Slider(context: *microui.MicroUI, value: *u8, low: i32, high: i32) !i32 {
        const addr = @intFromPtr(value);
        const id = context.getId(@ptrCast(&addr), @sizeOf(usize));
        context.pushId(id);
        var tmp: f32 = @floatFromInt(value.*);
        const res = try slider(
            context,
            &tmp,
            @floatFromInt(low),
            @floatFromInt(high),
            .{ .fmt = "%.0f" },
        );
        value.* = @intFromFloat(tmp);
        _ = context.popId();
        return res;
    }
};

pub const TextBox = struct {
    pub const TextBoxOpt = struct {
        opt: i32 = 0,
    };

    pub fn textBox(context: *microui.MicroUI, text: [*c]u8, len: i32, opt: TextBoxOpt) !i32 {
        const addr = @intFromPtr(text);
        const id = context.getId(@ptrCast(&addr), @sizeOf(usize));
        const rect_val = context.layoutNext();
        return TextBox.textBoxRaw(context, text, len, id, rect_val, opt.opt);
    }

    pub fn textBoxRaw(context: *microui.MicroUI, buf: [*c]u8, bufsz: i32, id: microui.Id, rect_val: math.Rect, opt: i32) !i32 {
        var res: i32 = 0;
        context.updateControl(id, rect_val, opt | Opt.hold_focus.toInt());

        if (context.getFocus() == id) {
            // Xử lý text input
            var len: usize = std.mem.len(buf);
            const input_slice = std.mem.sliceTo(&context.input_text, 0);
            if (bufsz > @as(i32, @intCast(len)) + 1) {
                const avail: usize = @intCast(bufsz - @as(i32, @intCast(len)) - 1);
                const n = @min(avail, input_slice.len);
                if (n > 0) {
                    @memcpy(buf[len .. len + n], input_slice[0..n]);
                    len += n;
                    buf[len] = 0;
                    res |= types.Res.change.toInt();
                }
            }

            // Xử lý backspace (hỗ trợ xóa đa byte UTF-8)
            if (context.isKeyPressed(.backspace) and len > 0) {
                len -= 1;
                while (len > 0 and (buf[len] & 0xc0) == 0x80) {
                    len -= 1;
                }
                buf[len] = 0;
                res |= types.Res.change.toInt();
            }

            // Xử lý phím Enter / Return
            if (context.isKeyPressed(.@"return")) {
                context.setFocus(0);
                res |= types.Res.submit.toInt();
            }
        }

        // Vẽ widget
        try context.drawControlFrame(id, rect_val, .base, opt);
        if (context.getFocus() == id) {
            const color_val = context.getStyle().getColor(.text);
            const font = context.getStyle().font;
            const text_span = std.mem.span(buf);
            const textw = if (context.text_width) |tw_fn|
                tw_fn(font, buf, @intCast(text_span.len))
            else
                0;
            const texth = if (context.text_height) |th_fn|
                th_fn(font)
            else
                0;
            const padding = context.getStyle().padding;
            const ofx = rect_val.w - padding - textw - 1;
            const textx = rect_val.x + @min(ofx, padding);
            const texty = rect_val.y + @divTrunc(rect_val.h - texth, 2);

            context.pushClipRect(rect_val);
            defer _ = context.popClip();
            try context.drawText(font, text_span, .{ .x = textx, .y = texty }, color_val);
            try context.drawRect(.init(textx + textw, texty, 1, texth), color_val);
        } else {
            try Label.controlText(context, buf, rect_val, .text, opt);
        }

        return res;
    }

    pub fn numberTextbox(context: *microui.MicroUI, value: *f32, r: math.Rect, id: microui.Id) !bool {
        if (context.isPressed(.left) and
            context.isKeyDown(.shift) and
            context.getHover() == id)
        {
            context.number_edit = id;
            _ = std.fmt.bufPrintSentinel(&context.number_edit_buf, "{d:.3}", .{value.*}, 0) catch {
                context.number_edit_buf[0] = 0;
            };
        }
        if (context.number_edit == id) {
            const res = try TextBox.textBoxRaw(
                context,
                @ptrCast(&context.number_edit_buf),
                @sizeOf(@TypeOf(context.number_edit_buf)),
                id,
                r,
                0,
            );
            if (types.Res.has(res, .submit) or context.getFocus() != id) {
                const str = std.mem.span(@as([*:0]const u8, @ptrCast(&context.number_edit_buf)));
                if (std.fmt.parseFloat(f32, std.mem.trim(u8, str, " \t\r\n"))) |parsed| {
                    value.* = parsed;
                } else |_| {}
                context.number_edit = 0;
            } else {
                return true;
            }
        }
        return false;
    }
};

pub const CheckBox = struct {
    pub fn checkBox(context: *microui.MicroUI, label: [:0]const u8, value: *i32) !i32 {
        var res: i32 = 0;
        const id = context.getId(@ptrCast(&value), @sizeOf(*i32));
        const r = context.layoutNext();
        const box = math.Rect.init(r.x, r.y, r.h, r.h);
        context.updateControl(id, r, 0);
        if (context.isPressed(.left) and context.getFocus() == id) {
            res |= types.Res.change.toInt();
            value.* = if (value.* != 0) 0 else 1;
        }
        try context.drawControlFrame(id, box, .base, 0);
        if (value.* != 0) {
            try context.drawIcon(.check, box, context.getStyle().getColor(.text));
        }
        const text_rect = math.Rect.init(r.x + box.w, r.y, r.w - box.w, r.h);
        try Label.controlText(context, label.ptr, text_rect, .text, 0);
        return res;
    }
};

pub const Label = struct {
    pub fn label(context: *microui.MicroUI, text: [:0]const u8) !void {
        return Label.controlText(context, text, context.layoutNext(), .text, 0);
    }

    pub fn controlText(
        context: *microui.MicroUI,
        text: [*c]const u8,
        rect: math.Rect,
        color: style.ColorId,
        opt: i32,
    ) !void {
        if (text == null) return;
        const style_ptr = context.getStyle();
        const font = style_ptr.font;
        const tw = context.text_width.?(font, text, -1);
        context.pushClipRect(rect);
        defer _ = context.popClip();

        var pos: math.Vec2 = undefined;
        pos.y = rect.y + @divTrunc(rect.h - context.text_height.?(font), 2);
        if (Opt.has(opt, .align_center)) {
            pos.x = rect.x + @divTrunc(rect.w - tw, 2);
        } else if (Opt.has(opt, .align_right)) {
            pos.x = rect.x + rect.w - tw - style_ptr.padding;
        } else {
            pos.x = rect.x + style_ptr.padding;
        }
        const col = style_ptr.getColor(color);
        const span = std.mem.span(text);
        _ = try context.drawText(font, span, pos, col);
    }
};

pub const Text = struct {
    pub fn text(context: *microui.MicroUI, content: []const u8) !void {
        context.layoutBeginColumn();
        defer context.layoutEndColumn();

        if (content.len == 0) {
            return;
        }

        const font = context.getStyle().font;
        context.setLayoutRow(&[_]i32{-1}, context.text_height.?(font));
        const color_val = context.getStyle().getColor(.text);

        var p: usize = 0;
        while (p < content.len) {
            const rect_val = context.layoutNext();
            var w: i32 = 0;
            const line_start = p;
            var line_end = p;
            while (p < content.len) {
                const word_start = p;
                while (p < content.len and content[p] != ' ' and content[p] != '\n') {
                    p += 1;
                }
                const word_len = p - word_start;
                if (word_len > 0) {
                    w += context.text_width.?(font, @ptrCast(&content[word_start]), @intCast(word_len));
                }
                if (w > rect_val.w and line_end != line_start) {
                    p = word_start;
                    break;
                }
                if (p < content.len) {
                    const sep = content[p];
                    w += context.text_width.?(font, @ptrCast(&content[p]), 1);
                    line_end = p;
                    p += 1;
                    if (sep == '\n') break;
                } else {
                    line_end = p;
                }
            }
            if (line_end > line_start) {
                try context.drawText(font, content[line_start..line_end], .init(rect_val.x, rect_val.y), color_val);
            }
        }
    }
};

pub const ScrollbarAxis = enum {
    vertical,
    horizontal,
};

pub const Scrollbar = struct {
    pub const Axis = ScrollbarAxis;

    /// Xử lý logic tính toán và vẽ thanh cuộn theo một trục (dọc hoặc ngang).
    pub fn scrollbar(context: *microui.MicroUI, cnt: *container_mod.Container, body: *math.Rect, cs: math.Vec2, axis: ScrollbarAxis) !void {
        const style_ptr = context.getStyle();
        const sz = style_ptr.scrollbar_size;
        switch (axis) {
            .vertical => {
                const maxscroll = cs.y - body.h;
                if (maxscroll > 0 and body.h > 0) {
                    const id = context.getId("!scrollbary", 11);
                    var base = body.*;
                    base.x = body.x + body.w;
                    base.w = sz;

                    context.updateControl(id, base, 0);
                    if (context.getFocus() == id and context.isMouseDown(.left)) {
                        const delta = context.getMouseDelta();
                        cnt.scroll.y += @divTrunc(delta.y * cs.y, base.h);
                    }
                    cnt.scroll.y = std.math.clamp(cnt.scroll.y, 0, maxscroll);

                    _ = try context.drawFrame(base, style.ColorId.scroll_base);

                    var thumb = base;
                    thumb.h = @max(style_ptr.thumb_size, @divTrunc(base.h * body.h, cs.y));
                    thumb.y += @divTrunc(cnt.scroll.y * (base.h - thumb.h), maxscroll);

                    try context.drawFrame(thumb, style.ColorId.scroll_thumb);

                    if (context.mouseOver(body.*)) {
                        context.setScrollTarget(cnt);
                    }
                } else {
                    cnt.scroll.y = 0;
                }
            },
            .horizontal => {
                const maxscroll = cs.x - body.w;
                if (maxscroll > 0 and body.w > 0) {
                    const id = context.getId("!scrollbarx", 11);
                    var base = body.*;
                    base.y = body.y + body.h;
                    base.h = sz;

                    context.updateControl(id, base, 0);
                    if (context.getFocus() == id and context.isMouseDown(.left)) {
                        const delta = context.getMouseDelta();
                        cnt.scroll.x += @divTrunc(delta.x * cs.x, base.w);
                    }
                    cnt.scroll.x = std.math.clamp(cnt.scroll.x, 0, maxscroll);

                    _ = try context.drawFrame(base, style.ColorId.scroll_base);

                    var thumb = base;
                    thumb.w = @max(style_ptr.thumb_size, @divTrunc(base.w * body.w, cs.x));
                    thumb.x += @divTrunc(cnt.scroll.x * (base.w - thumb.w), maxscroll);

                    _ = try context.drawFrame(thumb, style.ColorId.scroll_thumb);

                    if (context.mouseOver(body.*)) {
                        context.setScrollTarget(cnt);
                    }
                } else {
                    cnt.scroll.x = 0;
                }
            },
        }
    }

    /// Tính toán và vẽ toàn bộ thanh cuộn (dọc + ngang) cho container.
    pub fn scrollbars(context: *microui.MicroUI, cnt: *container_mod.Container, body: *math.Rect) !void {
        const style_ptr = context.getStyle();
        const sz = style_ptr.scrollbar_size;
        var content_size = cnt.*.content_size;
        content_size.x += style_ptr.padding * 2;
        content_size.y += style_ptr.padding * 2;
        context.pushClipRect(body.*);
        defer _ = context.popClip();
        if (content_size.y > body.h) {
            body.w -= sz;
        }
        if (content_size.x > body.w) {
            body.h -= sz;
        }
        try Scrollbar.scrollbar(context, cnt, body, content_size, .vertical);
        try Scrollbar.scrollbar(context, cnt, body, content_size, .horizontal);
    }
};
