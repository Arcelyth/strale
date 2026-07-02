const std = @import("std");
const CloneBench = @import("clone_bench.zig").CloneBench;

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.c_allocator;
    const iterations = 10_000;
    const io = init.io;

    const short = "abcde";
    const long = "abcdefghijklmnopqrstuvwxyz";
    var clone_inline = try CloneBench(.utf8, .not_atomic).init(alloc, short);
    defer clone_inline.deinit();
    var clone = try CloneBench(.utf8, .not_atomic).init(alloc, long);
    defer clone.deinit();
    var clone_atomic = try CloneBench(.utf8, .atomic).init(alloc, long);
    defer clone_atomic.deinit();

    var bench = clone_inline.bench();
    var ns = try bench.run(iterations, io);
    printResult("CloneBenchInline", iterations, ns);

    bench = clone.bench();
    ns = try bench.run(iterations, io);
    printResult("CloneBench", iterations, ns);

    bench = clone_atomic.bench();
    ns = try bench.run(iterations, io);
    printResult("CloneBenchAtomic", iterations, ns);

}

fn printResult(name: []const u8, iterations: u64, elapsed_ns: i96) void {
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1e9);
    std.debug.print("{s:<32} | {d:9.2} ns/op | {d:14.0} ops/s\n", .{ name, ns_per_op, ops_per_sec });
}
