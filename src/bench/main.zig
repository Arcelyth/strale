const std = @import("std");
const Benchmark = @import("Benchmark.zig");
const IndexWords = @import("index_words_bench.zig");

const small_size = 65_536;
const large_size = 1 << 20;
const default_iterations = 100;

//const en_1 = "Hello world.";
//const en_2 = "On the most rudimentary level there is simply terror of feeling like an immigrant in a place where your children are natives—where you're always going to be behind the 8-ball because they can develop the technology faster than you can learn it. It's what I call the learning curve of Sisyphus. And the only people who are going to be comfortable with that are people who don't mind confusion and ambiguity. I look at confusing circumstances as an opportunity—but not everybody feels that way. That's not the standard neurotic response. We've got a culture that's based on the ability of people to control everything. Once you start to embrace confusion as a way of life, concomitant with that is the assumption that you really don't control anything. At best it's a matter of surfing the whitewater.";

// Used for comparison with other string implementations.
// Additional test data from external projects may be added below.

// Test data from Tendril: https://github.com/servo/tendril/blob/main/src/bench.rs
const tendril_en_1 = "Days turn to nights turn to paper into rocks into plastic";
const tendril_en_2 = "Here the notes in my laboratory journal cease. I was able to write the last words only with great effort. By now it was already clear to me that LSD had been the cause of the remarkable experience of the previous Friday, for the altered perceptions were of the same type as before, only much more intense. I had to struggle to speak intelligibly. I asked my laboratory assistant, who was informed of the self-experiment, to escort me home. We went by bicycle, no automobile being available because of wartime restrictions on their use. On the way home, my condition began to assume threatening forms. Everything in my field of vision wavered and was distorted as if seen in a curved mirror. I also had the sensation of being unable to move from the spot. Nevertheless, my assistant later told me that we had traveled very rapidly. Finally, we arrived at home safe and sound, and I was just barely capable of asking my companion to summon our family doctor and request milk from the neighbors.\n\nIn spite of my delirious, bewildered condition, I had brief periods of clear and effective thinking—and chose milk as a nonspecific antidote for poisoning.";
const tendril_kr_1 = "러스트(Rust)는 모질라(mozilla.org)에서 개발하고 있는, 메모리-안전하고 병렬 프로그래밍이 쉬운 차세대 프로그래밍 언어입니다. 아직 개발 단계이며 많은 기능이 구현 중으로, MIT/Apache2 라이선스로 배포됩니다.";
const tendril_html_kr_1 = "<p>러스트(<a href=\"http://rust-lang.org\">Rust</a>)는 모질라(<a href=\"https://www.mozilla.org/\">mozilla.org</a>)에서 개발하고 있는, 메모리-안전하고 병렬 프로그래밍이 쉬운 차세대 프로그래밍 언어입니다. 아직 개발 단계이며 많은 기능이 구현 중으로, MIT/Apache2 라이선스로 배포됩니다.</p>";

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const iterations = if (args.len > 1)
        try std.fmt.parseInt(u64, args[1], 10)
    else
        default_iterations;

    //    try runGroup(init.gpa, init.io, "en_1", en_1, iterations);
    //    try runGroup(init.gpa, init.io, "en_2", en_2, iterations);

    try runGroup(init.gpa, init.io, "tendril_en_1", tendril_en_1, iterations);
    try runGroup(init.gpa, init.io, "tendril_en_2", tendril_en_2, iterations);
    try runGroup(init.gpa, init.io, "tendril_kr_1", tendril_kr_1, iterations);
    try runGroup(init.gpa, init.io, "tendril_html_kr_1", tendril_html_kr_1, iterations);
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
