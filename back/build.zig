const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "sample",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const csdl = b.addTranslateC(.{
        .root_source_file = b.path("src/c/csdl.h"),
        .target = target,
        .optimize = optimize,
    });

    if (std.Io.Dir.cwd().access(b.*.graph.*.io, "lib/install", .{})) {
        exe.root_module.addLibraryPath(
            b.path("lib/install/lib64"),
        );
        csdl.addIncludePath(b.path("lib/install/include"));
    } else |_| {}

    exe.root_module.addImport("csdl", csdl.createModule());
    exe.root_module.linkSystemLibrary("SDL3", .{});
    exe.root_module.linkSystemLibrary("SDL3_ttf", .{});
    exe.root_module.linkSystemLibrary("SDL3_image", .{});
    exe.root_module.linkSystemLibrary("freetype", .{});
    exe.root_module.linkSystemLibrary("harfbuzz", .{});
    exe.root_module.linkSystemLibrary("brotlicommon", .{});
    exe.root_module.linkSystemLibrary("c", .{});

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}
