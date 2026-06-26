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

    try s.pushUtf8(
        testing.allocator,
        '你',
    );

    try s.pushUtf8(
        testing.allocator,
        '好',
    );

    try testing.expectEqualStrings(
        "你好",
        s.slice(),
    );
}
