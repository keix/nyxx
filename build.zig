const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_wasm = target.result.cpu.arch == .wasm32;
    const is_wasi = target.result.os.tag == .wasi;

    const exe = b.addExecutable(.{
        .name = "nyxx",
        .root_source_file = if (is_wasm) b.path("src/main_wasm.zig") else b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (is_wasm) {
        if (is_wasi) {
            // WASI target - keep main entry point but no SDL
        } else {
            // Freestanding WASM - disable entry point and add explicit exports
            exe.entry = .disabled;
            exe.export_memory = true;
            // Explicit exports not supported in build.zig for Zig 0.13.0
            // Use manual build command instead
        }
    } else {
        // Native target - Link SDL2
        exe.linkLibC();
        exe.linkSystemLibrary("SDL2");
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // WASM build step
    const wasm_step = b.step("wasm", "Build WASM with explicit exports");

    const wasm_cmd = b.addSystemCommand(&.{
        "zig",                    "build-exe",               "src/main_wasm.zig",
        "-target",                "wasm32-freestanding",     "-O",
        "ReleaseSmall",           "-fno-entry",              "--export=init",
        "--export=start",         "--export=step",           "--export=getFrameBufferPtr",
        "--export=getFrameWidth", "--export=getFrameHeight", "--export=setButtonState",
        "--export=deinit",        "--name",                  "nyxx",
    });

    // Install the built WASM file
    wasm_cmd.addArg("-femit-bin=zig-out/bin/nyxx.wasm");

    wasm_step.dependOn(&wasm_cmd.step);
}
