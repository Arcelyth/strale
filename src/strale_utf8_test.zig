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

test "utf8 init from char" {
    var s = try StraleUtf8.initChar('好');
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqualStrings("好", s.slice());
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

test "pop utf8 front inline" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "你好",
    );
    defer s.deinit();

    try testing.expectEqual('你', s.popFront());
    try testing.expectEqualStrings("好", s.slice());
}

test "pop utf8 front heap" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "その世界で死んだ人達ってさ、まあほら魔王軍に殺された訳じゃない",
    );
    defer s.deinit();

    try testing.expectEqual('そ', s.peek());
    try testing.expectEqual('そ', s.popFront());
    try testing.expectEqualStrings("の世界で死んだ人達ってさ、まあほら魔王軍に殺された訳じゃない", s.slice());
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

test "split utf8 iterator" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "猫和狗和パン和머리",
    );
    defer s.deinit();

    var iter = s.splitToStrale("和");
    defer iter.deinit();

    // first
    var part1 = iter.first();
    defer part1.deinit();
    try testing.expectEqualStrings(
        "猫",
        part1.slice(),
    );

    // peek
    var part2 = iter.peek().?;
    defer part2.deinit();
    try testing.expectEqualStrings(
        "狗",
        part2.slice(),
    );

    // next
    var part3 = iter.next().?;
    defer part3.deinit();
    try testing.expectEqualStrings(
        "狗",
        part3.slice(),
    );

    var part4 = iter.next().?;
    defer part4.deinit();
    try testing.expectEqualStrings(
        "パン",
        part4.slice(),
    );

    // rest
    var remain = iter.rest();
    defer remain.deinit();
    try testing.expectEqualStrings(
        "머리",
        remain.slice(),
    );

    // reset
    iter.reset();
    var part5 = iter.next().?;
    defer part5.deinit();
    try testing.expectEqualStrings(
        "猫",
        part5.slice(),
    );

    var part6 = iter.next().?;
    defer part6.deinit();
    try testing.expectEqualStrings(
        "狗",
        part6.slice(),
    );

    var part7 = iter.next().?;
    defer part7.deinit();
    try testing.expectEqualStrings(
        "パン",
        part7.slice(),
    );

    var part8 = iter.next().?;
    defer part8.deinit();
    try testing.expectEqualStrings(
        "머리",
        part8.slice(),
    );

    try testing.expect(iter.next() == null);
}

test "repeat utf8" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "?哈?",
    );
    defer s.deinit();

    var r = try s.repeat(testing.allocator, 7);
    defer r.deinit();

    try testing.expectEqualStrings(
        "?哈??哈??哈??哈??哈??哈??哈?",
        r.slice(),
    );
}

test "toLowercase utf8" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "アカリン! ABCde",
    );
    defer s.deinit();

    var lower = try s.toLowercase(
        testing.allocator,
    );
    defer lower.deinit();

    try testing.expectEqualStrings(
        "アカリン! abcde",
        lower.slice(),
    );
}

test "toUppercase" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "hello 世界",
    );
    defer s.deinit();

    var upper = try s.toUppercase(
        testing.allocator,
    );
    defer upper.deinit();

    try testing.expectEqualStrings(
        "HELLO 世界",
        upper.slice(),
    );
}

test "toCapitalized" {
    var s = try StraleUtf8.initSlice(
        testing.allocator,
        "hELLo 世界",
    );
    defer s.deinit();

    var cap = try s.toCapitalized(
        testing.allocator,
    );
    defer cap.deinit();

    try testing.expectEqualStrings(
        "Hello 世界",
        cap.slice(),
    );
}

test "reverse utf8" {
    var s = try StraleUtf8.initSlice(testing.allocator, "a界b🙂");
    defer s.deinit();

    try s.reverse();

    try testing.expectEqualStrings(
        "🙂b界a",
        s.slice(),
    );
}
