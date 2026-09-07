const std = @import("std");
const strale = @import("strale");
const Benchmark = @import("Benchmark.zig");

const Str = strale.Strale(.utf8, .not_atomic, false);

pub const StraleCreation = struct {
    allocator: std.mem.Allocator,
    input: []const u8,

    pub fn step(self: *StraleCreation) !usize {
        std.mem.doNotOptimizeAway(self.input.ptr);
        var value = try Str.initSlice(self.allocator, self.input);
        defer value.deinit();
        std.mem.doNotOptimizeAway(&value);
        return value.len();
    }

    pub fn benchmark(self: *StraleCreation, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};

pub const StringCreation = struct {
    allocator: std.mem.Allocator,
    input: []const u8,

    pub fn step(self: *StringCreation) !usize {
        std.mem.doNotOptimizeAway(self.input.ptr);
        const value = try self.allocator.dupe(u8, self.input);
        defer self.allocator.free(value);
        std.mem.doNotOptimizeAway(value.ptr);
        return value.len;
    }

    pub fn benchmark(self: *StringCreation, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};
