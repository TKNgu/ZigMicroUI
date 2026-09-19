const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_translate_c = b.addTranslateC(.{
        .root_source_file = b.path("demo/main.h"),
        .target = target,
        .optimize = optimize,
    });
    c_translate_c.addIncludePath(b.path("demo/"));
    c_translate_c.addSystemIncludePath(.{
        .cwd_relative = "/usr/include",
    });

    const c_microui = c_translate_c.createModule();
    c_microui.addCSourceFiles(.{
        .root = b.path("demo/"),
        .files = &.{ "microui.c", "renderer.c" },
    });
    c_microui.linkSystemLibrary("SDL2", .{});
    c_microui.linkSystemLibrary("GL", .{});
    c_microui.linkSystemLibrary("c", .{});

    const exe = b.addExecutable(.{
        .name = "sample",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c_microui", .module = c_microui },
            },
        }),
    });

    // const csdl = b.addTranslateC(.{
    //     .root_source_file = b.path("src/c/csdl.h"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // if (std.Io.Dir.cwd().access(b.*.graph.*.io, "lib/install", .{})) {
    //     exe.root_module.addLibraryPath(
    //         b.path("lib/install/lib64"),
    //     );
    //     csdl.addIncludePath(b.path("lib/install/include"));
    // } else |_| {}
    //
    // exe.root_module.addImport("csdl", csdl.createModule());
    // exe.root_module.linkSystemLibrary("SDL3", .{});
    // exe.root_module.linkSystemLibrary("SDL3_ttf", .{});
    // exe.root_module.linkSystemLibrary("SDL3_image", .{});
    // exe.root_module.linkSystemLibrary("freetype", .{});
    // exe.root_module.linkSystemLibrary("harfbuzz", .{});
    // exe.root_module.linkSystemLibrary("brotlicommon", .{});
    // exe.root_module.linkSystemLibrary("c", .{});

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}
