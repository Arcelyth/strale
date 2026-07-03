const strale = @import("strale.zig");
const std = @import("std");

pub fn BufferDeque(comptime format: strale.Format, comptime atomicity: strale.Atomicity) type {
    return struct {
        const Self = @This();
        const T = strale.Strale(format, atomicity);
        pub const CharType = switch (T.getFormat()) {
            .utf8 => u21,
            .byte => u8,
        };

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

        pub fn popFront(self: *Self) ?T {
            return self.buffer.popFront();
        }

        pub fn popBack(self: *Self) ?T {
            return self.buffer.popBack();
        }

        pub fn pushFront(self: *Self, item: T) error{OutOfMemory}!void {
            if (item.len() == 0) return;
            try self.buffer.pushFront(self.allocator, item);
        }

        pub fn pushBack(self: *Self, item: T) error{OutOfMemory}!void {
            if (item.len() == 0) return;
            try self.buffer.pushBack(self.allocator, item);
        }

        pub fn peekChar(self: *Self) ?CharType {
            if (self.buffer.front()) |f| {
                return f.peek();
            }
            return null;
        }

        pub fn nextChar(self: *Self) ?CharType {
            if (self.buffer.frontPtr()) |f| {
                const c = f.popFront() orelse return null;

                if (f.isEmpty()) {
                    _ = self.buffer.popFront();
                }

                return c;
            }

            return null;
        }
    };
}
