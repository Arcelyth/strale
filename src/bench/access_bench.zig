const std = @import("std");
const strale = @import("strale");
const Benchmark = @import("Benchmark.zig");

const Str = strale.Strale(.utf8, .not_atomic, false);

pub const StraleAccess = struct {
    value: Str,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) !StraleAccess {
        return .{ .value = try Str.initSlice(allocator, input) };
    }

    pub fn deinit(self: *StraleAccess) void {
        self.value.deinit();
    }

    pub fn step(self: *StraleAccess) !usize {
        const value = self.value.slice();
        std.mem.doNotOptimizeAway(value.ptr);
        return value.len;
    }

    pub fn benchmark(self: *StraleAccess, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};

pub const StringAccess = struct {
    allocator: std.mem.Allocator,
    value: []u8,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) !StringAccess {
        return .{ .allocator = allocator, .value = try allocator.dupe(u8, input) };
    }

    pub fn deinit(self: *StringAccess) void {
        self.allocator.free(self.value);
    }

    // Do nothing here.
    pub fn step(self: *StringAccess) !usize {
        std.mem.doNotOptimizeAway(self.value.ptr);
        return self.value.len;
    }

    pub fn benchmark(self: *StringAccess, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};
