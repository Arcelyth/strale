const std = @import("std");
const testing = std.testing;
const strale = @import("strale.zig");
const BufferDeque = @import("buffer_deque.zig").BufferDeque;

const Buffer = BufferDeque(.byte, .not_atomic);
const Str = strale.Strale(.byte, .not_atomic);

test "pop" {
    const alloc = std.heap.page_allocator;
    var s = try Str.initSlice(alloc, "hello");
    defer s.deinit();
    var buf = try Buffer.init(alloc);
    defer buf.deinit();
    try buf.push_back(s.clone());
    try testing.expect(!buf.isEmpty());

    var result = buf.pop_front().?;
    defer result.deinit();

    try testing.expectEqualStrings("hello", result.slice());
    try testing.expect(buf.isEmpty());
}
