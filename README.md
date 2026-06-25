# Strale

A memory efficient compact, copy-on-write (COW) string type for Zig.

Strale combines:
- Small String Optimization (SSO)
- Reference counting
- Zero-copy substring views
- Copy-on-write mutation

The type occupies **16 bytes** on 64-bit platforms.

## Example

```zig
var s1 = try Strale.initSlice(
    testing.allocator,
    "hello world",
);
defer s1.deinit();

var s2 = s1.clone();
defer s2.deinit();

try s1.push(testing.allocator, '!');

try testing.expectEqualStrings(
    "hello world!",
    s1.slice(),
);

try testing.expectEqualStrings(
    "hello world",
    s2.slice(),
);
```

## LICENSE

MIT License
