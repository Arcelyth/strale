const std = @import("std");
const Benchmark = @import("Benchmark.zig");
const IndexWords = @import("index_words_bench.zig");

const small_size = 65_536;
const large_size = 1 << 20;
const default_iterations = 100;

const en_1 = "Hello world.";
const en_2 = "On the most rudimentary level there is simply terror of feeling like an immigrant in a place where your children are natives—where you're always going to be behind the 8-ball because they can develop the technology faster than you can learn it. It's what I call the learning curve of Sisyphus. And the only people who are going to be comfortable with that are people who don't mind confusion and ambiguity. I look at confusing circumstances as an opportunity—but not everybody feels that way. That's not the standard neurotic response. We've got a culture that's based on the ability of people to control everything. Once you start to embrace confusion as a way of life, concomitant with that is the assumption that you really don't control anything. At best it's a matter of surfing the whitewater.";

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const iterations = if (args.len > 1)
        try std.fmt.parseInt(u64, args[1], 10)
    else
        default_iterations;

    try runGroup(init.gpa, init.io, "en_1", en_1, iterations);
    try runGroup(init.gpa, init.io, "en_2", en_2, iterations);
}

fn runGroup(
    allocator: std.mem.Allocator,
    io: std.Io,
    group: []const u8,
    text: []const u8,
    iterations: u64,
) !void {
    var small_string = try IndexWords.StringBench.init(allocator, text, small_size);
    defer small_string.deinit();
    var small_strale = try IndexWords.StraleBench.init(allocator, text, small_size);
    defer small_strale.deinit();
    var large_string = try IndexWords.StringBench.init(allocator, text, large_size);
    defer large_string.deinit();
    var large_strale = try IndexWords.StraleBench.init(allocator, text, large_size);
    defer large_strale.deinit();

    const benches = [_]Benchmark{
        small_string.benchmark("index_words_small_string"),
        small_strale.benchmark("index_words_small_strale"),
        large_string.benchmark("index_words_big_string"),
        large_strale.benchmark("index_words_big_strale"),
    };
    for (benches) |bench| {
        const elapsed = try bench.run(iterations, io);
        printResult(group, bench.name, iterations, elapsed);
    }
}

fn printResult(group: []const u8, name: []const u8, iterations: u64, elapsed: i96) void {
    const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
    std.debug.print("{s}/{s}\n    time: {d:.2} us\n", .{ group, name, ns_per_op / 1_000.0 });
}
