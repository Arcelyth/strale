const std = @import("std");
const testing = std.testing;

const strale = @import("strale.zig");
const StraleBytes = strale.StraleBytesGlobal;

//strale.global_allocator = testing.allocator;

test "global: heap 16 bytes string" {
    strale.global_allocator = testing.allocator;
    const str = "123456789abcdefg";

    comptime {
        std.debug.assert(str.len == 16);
    }

    var s = try StraleBytes.initSlice(str);
    defer s.deinit();

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

test "global: long string" {
    strale.global_allocator = testing.allocator;
    const str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    var s = try StraleBytes.initSlice(str);
    defer s.deinit();

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

// COW tests
test "global: cow unique allocation" {
    strale.global_allocator = testing.allocator;
    var s = try StraleBytes.initSlice(
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    const old_ptr = s.inner.remote_repr.ptr;

    try s.cow();

    try testing.expectEqual(
        old_ptr,
        s.inner.remote_repr.ptr,
    );
}

test "global: cow shared allocation" {
    strale.global_allocator = testing.allocator;
    var s1 = try StraleBytes.initSlice(
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    const old_ptr = s1.inner.remote_repr.ptr;

    try s1.cow();

    try testing.expect(
        s1.inner.remote_repr.ptr != old_ptr,
    );

    try testing.expectEqualStrings(
        s1.slice(),
        s2.slice(),
    );
}

test "global: push converts inline to heap" {
    strale.global_allocator = testing.allocator;
    var s = try StraleBytes.initSlice(
        "123456789abcdef",
    );
    defer s.deinit();

    try testing.expect(s.isInline());
    try s.push('g');

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(
        "123456789abcdefg",
        s.slice(),
    );
}

test "global: push heap" {
    var s = try StraleBytes.initSlice(
        "123456789abcdefg",
    );
    defer s.deinit();

    try s.push('h');

    try testing.expectEqualStrings(
        "123456789abcdefgh",
        s.slice(),
    );
}
