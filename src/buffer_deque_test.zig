const std = @import("std");
const testing = std.testing;
const strale = @import("strale.zig");
const BufferDeque = @import("buffer_deque.zig").BufferDeque;

const Buffer = BufferDeque(.byte, .not_atomic, false);
const Str = strale.Strale(.byte, .not_atomic, false);

fn asciiEq(a: u8, b: u8) bool {
    return a == b;
}

fn asciiEqIgnoreCase(a: u8, b: u8) bool {
    return std.ascii.toLower(a) == std.ascii.toLower(b);
}

test "pop" {
    const alloc = std.heap.page_allocator;
    var s = try Str.initSlice(alloc, "hello");
    defer s.deinit();
    const s2 = try Str.initSlice(alloc, "world");

    var buf = try Buffer.init(alloc);
    defer buf.deinit();
    try buf.pushBack(s.clone());
    // s2 only use once so move to buf
    try buf.pushBack(s2);
    try testing.expect(!buf.isEmpty());

    var result = buf.popFront().?;
    defer result.deinit();

    var result2 = buf.popFront().?;
    defer result2.deinit();

    try testing.expectEqualStrings("hello", result.slice());
    try testing.expectEqualStrings("world", result2.slice());
    try testing.expect(buf.isEmpty());
}

test "buffer peek next char" {
    const alloc = std.heap.page_allocator;
    var buf = try Buffer.init(alloc);
    defer buf.deinit();
    const s2 = try Str.initSlice(alloc, "hello");
    try buf.pushBack(s2);

    try buf.pushBackSlice("world");
    try testing.expect(!buf.isEmpty());

    try testing.expectEqual('h', buf.peekChar());
    try testing.expectEqual('h', buf.nextChar());
    var f = buf.popFront().?;
    defer f.deinit();
    try testing.expectEqualStrings("hello", s2.slice());
    try testing.expectEqualStrings("ello", f.slice());
}

test "match exact" {
    const alloc = std.heap.page_allocator;
    var deque = try Buffer.init(alloc);
    defer deque.deinit();

    try deque.pushBackSlice("helloWoRld");

    try testing.expect(deque.consume("hello", asciiEq));
    try testing.expect(deque.consume("world", asciiEqIgnoreCase));
    try testing.expect(deque.isEmpty());
}
