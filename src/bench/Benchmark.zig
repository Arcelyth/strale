const std = @import("std");
const Benchmark = @This();

ptr: *anyopaque,
stepFn: *const fn (*anyopaque) anyerror!void,

pub fn run(self: Benchmark, iterations: u64, io: std.Io) !i96 {
    const start = std.Io.Timestamp.now(io, .awake);

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        try self.stepFn(self.ptr);
    }

    return start.untilNow(io, .awake).toNanoseconds();
}
