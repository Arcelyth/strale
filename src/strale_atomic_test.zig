const std = @import("std");
const testing = std.testing;
const strale = @import("strale.zig");
const StraleAtomic = strale.StraleAtomic;

test "atomic clone and refcount" {
    var s1 = try StraleAtomic.initSlice(
        testing.allocator,
        "this is a very long string",
    );
    defer s1.deinit();

    try testing.expectEqual(1, s1.ref_count());

    var s2 = s1.clone();
    defer s2.deinit();

    try testing.expectEqual(2, s1.ref_count());

    var s3 = s1.clone();
    defer s3.deinit();

    try testing.expectEqual(3, s1.ref_count());
}

test "atomic substr" {
    var s = try StraleAtomic.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    try testing.expectEqual(1, s.ref_count());

    var sub = s.substr(5, 20);
    defer sub.deinit();

    try testing.expectEqual(2, s.ref_count());

    try testing.expectEqualStrings(
        "fghijklmnopqrstuvwxy",
        sub.slice(),
    );
}

test "atomic cow" {
    var s1 = try StraleAtomic.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    try testing.expectEqual(2, s1.ref_count());

    try s2.pushByte(testing.allocator, 'X');

    try testing.expectEqualStrings(
        "abcdefghijklmnopqrstuvwxyz",
        s1.slice(),
    );
    try testing.expectEqualStrings(
        "abcdefghijklmnopqrstuvwxyzX",
        s2.slice(),
    );

    try testing.expectEqual(1, s1.ref_count());
    try testing.expectEqual(1, s2.ref_count());
}

test "atomic multi clone" {
    var s = try StraleAtomic.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    var arr: [100]StraleAtomic = undefined;

    for (&arr) |*v| {
        v.* = s.clone();
    }

    try testing.expectEqual(101, s.ref_count());

    for (&arr) |*v| {
        v.deinit();
    }

    try testing.expectEqual(1, s.ref_count());
}
