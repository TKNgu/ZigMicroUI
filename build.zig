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

    exe.root_module.addIncludePath(.{
        .cwd_relative = "lib/install/include",
    });
    exe.root_module.addLibraryPath(.{
        .cwd_relative = "lib/install/lib64",
    });
    exe.root_module.linkSystemLibrary("SDL3", .{});
    exe.root_module.linkSystemLibrary("SDL3_image", .{});
    exe.root_module.linkSystemLibrary("SDL3_ttf", .{});
    exe.root_module.linkSystemLibrary("freetype", .{});
    exe.root_module.linkSystemLibrary("c", .{});

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
