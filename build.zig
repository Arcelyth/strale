const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const strale_module = b.addModule("strale", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // --- test
    const test_module = b.addModule("strale-test", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{ .name = "tests", .root_module = test_module });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);

    // --- bench
    const bench_module = b.addModule("strale-bench", .{
        .root_source_file = b.path("src/bench/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const bench = b.addExecutable(.{
        .name = "benches",
        .root_module = bench_module,
    });

    const run_bench = b.addRunArtifact(bench);
    bench.root_module.addImport("strale", strale_module);

    const bench_step = b.step("bench", "Run strale benchmarks");
    bench_step.dependOn(&run_bench.step);
}
