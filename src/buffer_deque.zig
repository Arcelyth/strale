const strale = @import("strale.zig");
const std = @import("std");

pub fn BufferDeque(comptime format: strale.Format, comptime atomicity: strale.Atomicity) type {
    return struct {
        const Self = @This();
        const T = strale.Strale(format, atomicity);
        buffer: std.Deque(T),
        allocator: std.mem.Allocator,

        pub fn init(alloc: std.mem.Allocator) !Self {
            return Self{
                .buffer = try std.Deque(strale.Strale(format, atomicity)).initCapacity(alloc, 16),
                .allocator = alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.allocator);
        }

        pub fn isEmpty(self: Self) bool {
            return self.buffer.len == 0;
        }

        pub fn pop_front(self: *Self) ?T {
            return self.buffer.popFront();
        }

        pub fn pop_back(self: *Self) ?T {
            return self.buffer.popBack();
        }

        pub fn push_front(self: *Self, item: T) error{OutOfMemory}!void {
            if (item.len() == 0) return;
            try self.buffer.pushFront(self.allocator, item);
        }

        pub fn push_back(self: *Self, item: T) error{OutOfMemory}!void {
            if (item.len() == 0) return;
            try self.buffer.pushBack(self.allocator, item);
        }
    };
}
