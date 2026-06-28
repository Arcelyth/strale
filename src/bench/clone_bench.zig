const strale = @import("strale");
const Benchmark = @import("Benchmark.zig");
const std = @import("std");

pub fn CloneBench(comptime format: strale.Format, comptime atomicity: strale.Atomicity) type {
    return struct {
        const Self = @This();
        s: strale.Strale(format, atomicity),

        pub fn init(alloc: std.mem.Allocator) !Self {
            const str = strale.Strale(format, atomicity);
            return .{
                .s = try str.initSlice(alloc, "abcdefghijklmnopqrstuvwxyz"),
            };
        }

        pub fn deinit(self: *Self) void {
            self.s.deinit();
        }

        pub fn step(ptr: *anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(ptr));

            std.mem.doNotOptimizeAway(self.s);
            const c = self.s.clone();
            std.mem.doNotOptimizeAway(c);
        }

        pub fn bench(self: *@This()) Benchmark {
            return .{
                .ptr = self,
                .stepFn = step,
            };
        }
    };
}
