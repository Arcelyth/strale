const std = @import("std");
const testing = std.testing;

const strale = @import("strale.zig");
const Strale = strale.Strale;

test "init empty" {
    var s = Strale.initEmpty();
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqual(0, s.slice().len);
    try testing.expectEqualStrings("", s.slice());
}

test "inline string" {
    var s = try Strale.initSlice(testing.allocator, "hello");
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqualStrings("hello", s.slice());
}

test "inline 15 bytes string" {
    const str = "123456789abcdef";

    comptime {
        std.debug.assert(str.len == 15);
    }

    var s = try Strale.initSlice(testing.allocator, str);
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

test "heap 16 bytes string" {
    const str = "123456789abcdefg";

    comptime {
        std.debug.assert(str.len == 16);
    }

    var s = try Strale.initSlice(testing.allocator, str);
    defer s.deinit();

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

test "long string" {
    const str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    var s = try Strale.initSlice(testing.allocator, str);
    defer s.deinit();

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

test "clone inline string" {
    var s1 = try Strale.initSlice(testing.allocator, "hello");
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    try testing.expect(s1.isInline());
    try testing.expect(s2.isInline());

    try testing.expectEqualStrings(
        s1.slice(),
        s2.slice(),
    );
}

test "clone heap string and ref count" {
    const str = "123456789abcdefg";

    var s1 = try Strale.initSlice(testing.allocator, str);
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    try testing.expectEqualStrings(
        s1.slice(),
        s2.slice(),
    );

    try testing.expectEqual(
        2,
        s1.ref_count(),
    );
}

test "multiple clones" {
    const str = "this string is definitely larger than fifteen bytes";

    var s1 = try Strale.initSlice(testing.allocator, str);
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    var s3 = s1.clone();
    defer s3.deinit();

    var s4 = s1.clone();
    defer s4.deinit();

    for ([4]Strale{ s1, s2, s3, s4 }) |s| {
        try testing.expectEqual(
            4,
            s.ref_count(),
        );

        try testing.expectEqualStrings(str, s.slice());
    }
}

test "clone then destroy clone" {
    const str = "123456789abcdefg";

    var s1 = try Strale.initSlice(testing.allocator, str);
    defer s1.deinit();

    var s2 = s1.clone();

    try testing.expectEqual(
        2,
        s2.ref_count(),
    );

    s2.deinit();

    try testing.expectEqual(
        1,
        s1.ref_count(),
    );

    try testing.expectEqualStrings(str, s1.slice());
}
