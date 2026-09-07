const std = @import("std");
const strale = @import("strale");
const Benchmark = @import("Benchmark.zig");

const Str = strale.Strale(.utf8, .not_atomic, false);

pub const StraleClone = struct {
    value: Str,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) !StraleClone {
        return .{ .value = try Str.initSlice(allocator, input) };
    }

    pub fn deinit(self: *StraleClone) void {
        self.value.deinit();
    }

    pub fn step(self: *StraleClone) !usize {
        var value = self.value.clone();
        defer value.deinit();
        std.mem.doNotOptimizeAway(&value);
        return value.len();
    }

    pub fn benchmark(self: *StraleClone, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};

pub const StringClone = struct {
    allocator: std.mem.Allocator,
    value: []u8,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) !StringClone {
        return .{ .allocator = allocator, .value = try allocator.dupe(u8, input) };
    }

    pub fn deinit(self: *StringClone) void {
        self.allocator.free(self.value);
    }

    pub fn step(self: *StringClone) !usize {
        const value = try self.allocator.dupe(u8, self.value);
        defer self.allocator.free(value);
        std.mem.doNotOptimizeAway(value.ptr);
        return value.len;
    }

    pub fn benchmark(self: *StringClone, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};
