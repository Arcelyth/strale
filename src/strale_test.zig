const std = @import("std");
const testing = std.testing;

const strale = @import("strale.zig");
const StraleBytes = strale.StraleBytes;

test "init empty" {
    var s = StraleBytes.initEmpty();
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqual(0, s.slice().len);
    try testing.expectEqualStrings("", s.slice());
}

test "inline string" {
    var s = try StraleBytes.initSlice(testing.allocator, "hello");
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqualStrings("hello", s.slice());
    s.clear();
    try testing.expectEqualStrings("", s.slice());
}

test "inline 15 bytes string" {
    const str = "123456789abcdef";

    comptime {
        std.debug.assert(str.len == 15);
    }

    var s = try StraleBytes.initSlice(testing.allocator, str);
    defer s.deinit();

    try testing.expect(s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

test "heap 16 bytes string" {
    const str = "123456789abcdefg";

    comptime {
        std.debug.assert(str.len == 16);
    }

    var s = try StraleBytes.initSlice(testing.allocator, str);
    defer s.deinit();

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(str, s.slice());
    s.clear();
    try testing.expect(s.isInline());
    try testing.expectEqualStrings("", s.slice());
}

test "long string" {
    const str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    var s = try StraleBytes.initSlice(testing.allocator, str);
    defer s.deinit();

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(str, s.slice());
}

test "clone inline string" {
    var s1 = try StraleBytes.initSlice(testing.allocator, "hello");
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

    var s1 = try StraleBytes.initSlice(testing.allocator, str);
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    try testing.expectEqualStrings(
        s1.slice(),
        s2.slice(),
    );

    try testing.expectEqual(2, s1.ref_count());
}

test "multiple clones" {
    const str = "this string is definitely larger than fifteen bytes";

    var s1 = try StraleBytes.initSlice(testing.allocator, str);
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    var s3 = s1.clone();
    defer s3.deinit();

    var s4 = s1.clone();
    defer s4.deinit();

    for ([4]StraleBytes{ s1, s2, s3, s4 }) |s| {
        try testing.expectEqual(4, s.ref_count());

        try testing.expectEqualStrings(str, s.slice());
    }
}

test "clone then destroy clone" {
    const str = "123456789abcdefg";

    var s1 = try StraleBytes.initSlice(testing.allocator, str);
    defer s1.deinit();

    var s2 = s1.clone();

    try testing.expectEqual(2, s2.ref_count());

    s2.deinit();

    try testing.expectEqual(1, s1.ref_count());

    try testing.expectEqualStrings(str, s1.slice());
}

// Substr tests
test "substr inline to inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello world",
    );
    defer s.deinit();

    var sub = s.substr(0, 5);
    defer sub.deinit();

    try testing.expect(sub.isInline());
    try testing.expectEqualStrings(
        "hello",
        sub.slice(),
    );
}

test "substr heap to inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    var sub = s.substr(5, 3);
    defer sub.deinit();

    try testing.expect(sub.isInline());
    try testing.expectEqualStrings(
        "fgh",
        sub.slice(),
    );
}

test "substr heap to heap" {
    const text =
        "abcdefghijklmnopqrstuvwxyz";

    var s = try StraleBytes.initSlice(
        testing.allocator,
        text,
    );
    defer s.deinit();

    var sub = s.substr(5, 20);
    defer sub.deinit();

    try testing.expect(!sub.isInline());

    try testing.expectEqualStrings(
        text[5..25],
        sub.slice(),
    );

    try testing.expectEqual(2, s.ref_count());
}

// COW tests
test "cow unique allocation" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
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

test "cow shared allocation" {
    var s1 = try StraleBytes.initSlice(
        testing.allocator,
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

test "cow after shared substr" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    var sub = s.substr(2, 20);
    defer sub.deinit();

    try sub.cow();

    try testing.expectEqualStrings(
        "cdefghijklmnopqrstuv",
        sub.slice(),
    );
}

// Push tests
test "push inline" {
    var s = StraleBytes.initEmpty();
    defer s.deinit();

    try s.push(testing.allocator, 'a');
    try s.push(testing.allocator, 'b');
    try s.push(testing.allocator, 'c');

    try testing.expect(s.isInline());
    try testing.expectEqualStrings(
        "abc",
        s.slice(),
    );
}

test "push converts inline to heap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "123456789abcdef",
    );
    defer s.deinit();

    try testing.expect(s.isInline());
    try s.push(testing.allocator, 'g');

    try testing.expect(!s.isInline());
    try testing.expectEqualStrings(
        "123456789abcdefg",
        s.slice(),
    );
}

test "push heap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "123456789abcdefg",
    );
    defer s.deinit();

    try s.push(testing.allocator, 'h');

    try testing.expectEqualStrings(
        "123456789abcdefgh",
        s.slice(),
    );
}

test "push triggers cow" {
    var s1 = try StraleBytes.initSlice(
        testing.allocator,
        "hello world hello world",
    );
    defer s1.deinit();

    var s2 = s1.clone();
    defer s2.deinit();

    try s1.push(testing.allocator, '!');

    try testing.expectEqualStrings(
        "hello world hello world!",
        s1.slice(),
    );

    try testing.expectEqualStrings(
        "hello world hello world",
        s2.slice(),
    );
}

test "push after substring" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    var sub = s.substr(10, 10);
    defer sub.deinit();

    try sub.push(testing.allocator, 'X');

    try testing.expectEqualStrings(
        "klmnopqrstX",
        sub.slice(),
    );

    try testing.expectEqualStrings(
        "abcdefghijklmnopqrstuvwxyz",
        s.slice(),
    );
}

// Pop tests
test "pop inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abc",
    );
    defer s.deinit();

    try testing.expectEqual('c', s.pop());
    try testing.expectEqualStrings("ab", s.slice());
}

test "pop heap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    try testing.expectEqual('z', s.pop());
    try testing.expectEqual(25, s.len());
}

test "pop until empty" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abc",
    );
    defer s.deinit();

    _ = s.pop();
    _ = s.pop();
    _ = s.pop();

    try testing.expect(s.isEmpty());
    try testing.expectEqual(null, s.pop());
}

test "pop substring" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    var sub = s.substr(5, 5);
    defer sub.deinit();

    _ = sub.pop();

    try testing.expectEqualStrings("fghi", sub.slice());
    try testing.expectEqualStrings(
        "abcdefghijklmnopqrstuvwxyz",
        s.slice(),
    );
}

// Pop front tests
test "pop front inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abc",
    );
    defer s.deinit();

    try testing.expectEqual('a', s.popFront());
    try testing.expectEqualStrings("bc", s.slice());
}

test "pop front heap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    try testing.expectEqual('a', s.peek());
    try testing.expectEqual('a', s.popFront());
    try testing.expectEqual(25, s.len());
}

// Drop front tests
test "drop front inline" {
    var str = try StraleBytes.initSlice(
        testing.allocator,
        "hello world",
    );
    defer str.deinit();

    str.dropFront(6);
    try testing.expectEqualStrings("world", str.slice());
    try testing.expect(str.isInline());

    str.dropFront(5);
    try testing.expectEqualStrings("", str.slice());
    try testing.expectEqual(@as(usize, 0), str.slice().len);

    str.dropFront(10);
    try testing.expectEqualStrings("", str.slice());
}

test "drop front heap to inline" {
    const long_str = "abcdefghijklmnopqrstuvwxyz";
    var str = try StraleBytes.initSlice(
        testing.allocator,
        long_str,
    );

    defer str.deinit();

    try testing.expect(!str.isInline());

    str.dropFront(5);
    try testing.expectEqualStrings("fghijklmnopqrstuvwxyz", str.slice());
    try testing.expect(!str.isInline());

    str.dropFront(10);
    try testing.expectEqualStrings("pqrstuvwxyz", str.slice());
    try testing.expect(str.isInline());
}

// Append tests
test "append inline" {
    var str = try StraleBytes.initSlice(
        testing.allocator,
        "abc",
    );

    defer str.deinit();

    try str.append(testing.allocator, "def");
    try testing.expectEqualStrings("abcdef", str.slice());
    try testing.expect(str.isInline());
}

test "append inline to heap" {
    var str = try StraleBytes.initSlice(
        testing.allocator,
        "0123456789",
    );

    defer str.deinit();
    try testing.expect(str.isInline());

    try str.appendAlloc(testing.allocator, "abcdef");
    try testing.expectEqualStrings("0123456789abcdef", str.slice());
    try testing.expect(!str.isInline());
}

test "empty string" {
    var s = StraleBytes.initEmpty();
    defer s.deinit();

    try testing.expect(s.isEmpty());
    try testing.expectEqual(0, s.len());
    try testing.expectEqual(null, s.pop());
}

test "inline len" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello",
    );
    defer s.deinit();

    try testing.expectEqual(5, s.len());
}

test "heap len" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    try testing.expectEqual(26, s.len());
}

test "inline cap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello",
    );
    defer s.deinit();

    try testing.expectEqual(null, s.cap());
}

test "heap cap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    try testing.expect(s.cap().? >= s.len());
}

test "charAt inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello",
    );
    defer s.deinit();

    try testing.expectEqual('h', s.charAt(0));
    try testing.expectEqual('o', s.charAt(4));
    try testing.expectEqual(null, s.charAt(5));
}

test "charAt substring" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    var sub = s.substr(5, 5);
    defer sub.deinit();

    try testing.expectEqual('f', sub.charAt(0));

    try testing.expectEqual('j', sub.charAt(4));
}

// Concat tests
test "concat inline" {
    var a = try StraleBytes.initSlice(testing.allocator, "hello");
    defer a.deinit();

    var b = try StraleBytes.initSlice(testing.allocator, "world");
    defer b.deinit();

    var c = try a.concat(testing.allocator, &b);
    defer c.deinit();

    try testing.expect(c.isInline());
    try testing.expectEqualStrings("helloworld", c.slice());
}

test "concat heap" {
    var a = try StraleBytes.initSlice(testing.allocator, "hello");
    defer a.deinit();

    const long = " world world world world";

    var b = try StraleBytes.initSlice(testing.allocator, long);
    defer b.deinit();

    var c = try a.concat(testing.allocator, &b);
    defer c.deinit();

    try testing.expect(!c.isInline());
    try testing.expectEqualStrings("hello world world world world", c.slice());
}

// Order tests
test "order same heap slice fast path" {
    var a = try StraleBytes.initSlice(testing.allocator, "hello world");
    defer a.deinit();

    var b = a.clone();
    defer b.deinit();

    try testing.expectEqual(.eq, a.order(&b));
}

test "order inline equality" {
    var a = try StraleBytes.initSlice(testing.allocator, "abc");
    defer a.deinit();

    var b = try StraleBytes.initSlice(testing.allocator, "abc");
    defer b.deinit();

    try testing.expectEqual(.eq, a.order(&b));
}

test "order ordering" {
    var a = try StraleBytes.initSlice(testing.allocator, "abc");
    defer a.deinit();

    var b = try StraleBytes.initSlice(testing.allocator, "abd");
    defer b.deinit();

    try testing.expectEqual(.lt, a.order(&b));
}

// Find/rind tests
test "find substring" {
    var s = try StraleBytes.initSlice(testing.allocator, "hello world");
    defer s.deinit();

    try testing.expectEqual(6, s.find("world"));
}

test "find missing" {
    var s = try StraleBytes.initSlice(testing.allocator, "hello");
    defer s.deinit();

    try testing.expectEqual(null, s.find("zzz"));
}

test "rfind multiple occurrences" {
    var s = try StraleBytes.initSlice(testing.allocator, "ababa");
    defer s.deinit();

    try testing.expectEqual(4, s.rfind("a"));
}

// Trims' tests
test "trimStart" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "   hello",
    );
    defer s.deinit();

    var t = s.trimStart(null);
    defer t.deinit();

    try testing.expectEqualStrings("hello", t.slice());
}

test "trimEnd" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello   ",
    );
    defer s.deinit();

    var t = s.trimEnd(null);
    defer t.deinit();

    try testing.expectEqualStrings("hello", t.slice());
}

test "trim" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "   hello   ",
    );
    defer s.deinit();

    var t = s.trim(null);
    defer t.deinit();

    try testing.expectEqualStrings("hello", t.slice());
}

test "trim custom pattern" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "***hello***",
    );
    defer s.deinit();

    var t = s.trim("***");
    defer t.deinit();

    try testing.expectEqualStrings("hello", t.slice());
}

test "count" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abababa",
    );
    defer s.deinit();

    try testing.expectEqual(3, s.count("ab"));
}

test "reverse inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello",
    );
    defer s.deinit();

    try s.reverse();

    try testing.expectEqualStrings("olleh", s.slice());
}

test "reverse heap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer s.deinit();

    try s.reverse();

    try testing.expectEqualStrings(
        "zyxwvutsrqponmlkjihgfedcba",
        s.slice(),
    );
}

test "splitToStrale iterator" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "one,two,three,four",
    );
    defer s.deinit();

    var iter = s.splitToStrale(",");
    defer iter.deinit();

    // first
    var part1 = iter.first();
    defer part1.deinit();
    try testing.expectEqualStrings(
        "one",
        part1.slice(),
    );

    // peek
    var part2 = iter.peek().?;
    defer part2.deinit();
    try testing.expectEqualStrings(
        "two",
        part2.slice(),
    );

    // next
    var part3 = iter.next().?;
    defer part3.deinit();
    try testing.expectEqualStrings(
        "two",
        part3.slice(),
    );

    var part4 = iter.next().?;
    defer part4.deinit();
    try testing.expectEqualStrings(
        "three",
        part4.slice(),
    );

    // rest
    var remain = iter.rest();
    defer remain.deinit();
    try testing.expectEqualStrings(
        "four",
        remain.slice(),
    );

    // reset
    iter.reset();
    var part5 = iter.next().?;
    defer part5.deinit();
    try testing.expectEqualStrings(
        "one",
        part5.slice(),
    );

    var part6 = iter.next().?;
    defer part6.deinit();
    try testing.expectEqualStrings(
        "two",
        part6.slice(),
    );

    var part7 = iter.next().?;
    defer part7.deinit();
    try testing.expectEqualStrings(
        "three",
        part7.slice(),
    );

    var part8 = iter.next().?;
    defer part8.deinit();
    try testing.expectEqualStrings(
        "four",
        part8.slice(),
    );

    try testing.expect(iter.next() == null);
}

test "linesToStrale iterator" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "line1\nline2\nline3",
    );
    defer s.deinit();

    var iter = s.linesToStrale();
    defer iter.deinit();

    var line1 = iter.next().?;
    defer line1.deinit();
    try testing.expectEqualStrings(
        "line1",
        line1.slice(),
    );

    var line2 = iter.next().?;
    defer line2.deinit();
    try testing.expectEqualStrings(
        "line2",
        line2.slice(),
    );

    var line3 = iter.next().?;
    defer line3.deinit();
    try testing.expectEqualStrings(
        "line3",
        line3.slice(),
    );

    try testing.expect(iter.next() == null);
}

test "repeat inline" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "ab",
    );
    defer s.deinit();

    var r = try s.repeat(testing.allocator, 3);
    defer r.deinit();

    try testing.expect(r.isInline());
    try testing.expectEqualStrings(
        "ababab",
        r.slice(),
    );
}

test "repeat heap" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "abcdef",
    );
    defer s.deinit();

    var r = try s.repeat(testing.allocator, 4);
    defer r.deinit();

    try testing.expect(!r.isInline());
    try testing.expectEqualStrings(
        "abcdefabcdefabcdefabcdef",
        r.slice(),
    );
}

test "toLowercase" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "HELLO World 123",
    );
    defer s.deinit();

    var lower = try s.toLowercase(
        testing.allocator,
    );
    defer lower.deinit();

    try testing.expectEqualStrings(
        "hello world 123",
        lower.slice(),
    );
}

test "toUppercase" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hello World 123",
    );
    defer s.deinit();

    var upper = try s.toUppercase(
        testing.allocator,
    );
    defer upper.deinit();

    try testing.expectEqualStrings(
        "HELLO WORLD 123",
        upper.slice(),
    );
}

test "toCapitalized" {
    var s = try StraleBytes.initSlice(
        testing.allocator,
        "hELLo WoRLD",
    );
    defer s.deinit();

    var cap = try s.toCapitalized(
        testing.allocator,
    );
    defer cap.deinit();

    try testing.expectEqualStrings(
        "Hello world",
        cap.slice(),
    );
}
