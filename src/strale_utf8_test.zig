const std = @import("std");
const testing = std.testing;

const strale = @import("strale.zig");
const StraleUtf8 = strale.StraleUtf8;

test "basic utf8" {
    var s = try StraleUtf8.initSlice(testing.allocator, "死んだ");
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqualStrings("死んだ", s.slice());
}

test "push utf8" {
    var s = StraleUtf8.initEmpty();
    defer s.deinit();

    try s.pushUtf8(testing.allocator, '你');
    try s.pushUtf8(testing.allocator, '好');

    try testing.expectEqualStrings("你好", s.slice());
}

test "pop utf8" {
    var s = try StraleUtf8.initSlice(testing.allocator, "a界b");
    defer s.deinit();

    const c3 = s.pop().?;
    try testing.expectEqual(@as(u21, 'b'), c3);

    const c2 = s.pop().?;
    try testing.expect(c2 == '界');

    const c1 = s.pop().?;
    try testing.expectEqual(@as(u21, 'a'), c1);
}

test "utf8 remote to inline" {
    var s = try StraleUtf8.initSlice(testing.allocator, "this_is_a_long_string");
    defer s.deinit();

    while (s.len() > 5) {
        _ = s.popByte();
    }

    try testing.expect(s.isInline());
    try testing.expectEqual(5, s.len());
}
