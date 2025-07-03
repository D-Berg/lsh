const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // const translate = b.addTranslateC(.{
    //     .target = target,
    //     .optimize = optimize,
    //     .root_source_file = b.path("src/c.h"),
    // });

    const helper_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    helper_mod.addCSourceFile(.{ .file = b.path("src/helper.c") });
    helper_mod.addIncludePath(b.path("src"));

    const helper_lib = b.addLibrary(.{
        .name = "helper",
        .root_module = helper_mod,
        .linkage = .static,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = b.option(bool, "strip", "strip the binary"),
    });

    const exe = b.addExecutable(.{
        .name = "lsh",
        .root_module = exe_mod,
    });

    exe.linkLibrary(helper_lib);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
