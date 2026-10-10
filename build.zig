const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // base graphic module
    const graphic = b.addModule("graphic", .{
        .root_source_file = b.path("src/graphic/graphic.zig"),
        .target = target,
        .optimize = optimize,
    });
    graphic.addIncludePath(.{
        .cwd_relative = "lib/local/include",
    });
    graphic.addLibraryPath(.{
        .cwd_relative = "lib/local/lib",
    });
    graphic.linkSystemLibrary("SDL3", .{});
    graphic.linkSystemLibrary("SDL3_image", .{});
    graphic.linkSystemLibrary("SDL3_ttf", .{});
    graphic.linkSystemLibrary("freetype", .{});
    graphic.linkSystemLibrary("png", .{});
    graphic.linkSystemLibrary("png16", .{});
    graphic.linkSystemLibrary("z", .{});
    graphic.linkSystemLibrary("bz2", .{});
    graphic.linkSystemLibrary("brotlidec", .{});
    graphic.linkSystemLibrary("harfbuzz", .{});
    graphic.linkSystemLibrary("c", .{});

    // microui.c
    const c_microui_translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/microui/microui.h"),
        .target = target,
        .optimize = optimize,
    });
    c_microui_translate_c.addIncludePath(b.path("src/microui/"));
    c_microui_translate_c.addSystemIncludePath(.{
        .cwd_relative = "/usr/include",
    });

    const c_microui = c_microui_translate_c.createModule();
    c_microui.addCSourceFiles(.{
        .root = b.path("src/microui/"),
        .files = &.{
            "microui.c",
        },
    });
    c_microui.linkSystemLibrary("c", .{});

    const exe = b.addExecutable(.{
        .name = "ZigMicroUI",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "graphic", .module = graphic },
                .{ .name = "c_microui", .module = c_microui },
            },
        }),
    });

    // build libc
    const deps_exist = if (std.Io.Dir.cwd().access(b.*.graph.*.io, "lib/local/lib/libSDL3.a", .{})) |_| true else |_| false;

    if (!deps_exist) {
        const cmake_configure_libc = b.addSystemCommand(&.{
            "cmake",
            "-S",
            ".",
            "-B",
            "lib/build",
            "-DCMAKE_INSTALL_PREFIX=lib/local/",
            "-DCMAKE_INSTALL_LIBDIR=lib",
            "-DCMAKE_BUILD_TYPE=Release",
        });
        const cmake_build_libc = b.addSystemCommand(&.{ "cmake", "--build", "lib/build", "-j4" });
        cmake_build_libc.step.dependOn(&cmake_configure_libc.step);
        exe.step.dependOn(&cmake_build_libc.step);
    }

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}
