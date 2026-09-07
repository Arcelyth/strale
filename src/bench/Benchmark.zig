const std = @import("std");
const Benchmark = @This();

name: []const u8,
ptr: *anyopaque,
stepFn: *const fn (*anyopaque) anyerror!usize,

pub fn init(
    name: []const u8,
    pointer: anytype,
    comptime stepFn: fn (@TypeOf(pointer)) anyerror!usize,
) Benchmark {
    const Ptr = @TypeOf(pointer);
    const gen = struct {
        fn step(ptr: *anyopaque) anyerror!usize {
            const self: Ptr = @ptrCast(@alignCast(ptr));
            return stepFn(self);
        }
    };
    return .{ .name = name, .ptr = pointer, .stepFn = gen.step };
}

pub inline fn step(self: Benchmark) !usize {
    return self.stepFn(self.ptr);
}

pub fn run(self: Benchmark, iterations: u64, io: std.Io) !i96 {
    const start = std.Io.Timestamp.now(io, .awake);

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const result = try self.stepFn(self.ptr);
        std.mem.doNotOptimizeAway(result);
    }

    return start.untilNow(io, .awake).toNanoseconds();
}
