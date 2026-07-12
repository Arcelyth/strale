# Strale

A memory efficient compact, copy-on-write (COW) string type for Zig. <br>
The type occupies **16 bytes** on 64-bit platforms.

Strale combines:
- Small String Optimization (SSO)
- Reference counting
- Zero-copy substring views
- Copy-on-write mutation
- Optional UTF-8 support
- Optional thread-safety support 
- Support global allocator to further reduce heap memory usage

## Installation

Add to your `build.zig.zon`:
```zig
    .dependencies = .{
        .strale = .{ 
            .url = "https://github.com/Arcelyth/strale/archive/refs/heads/main.tar.gz", 
            .hash = "..." 
        },
    },
```
Add to your `build.zig`: 
```zig
    const strale = b.dependency("strale", .{
        .target = target,
        .optimize = optimize,
    });
    exe_module.addImport("strale", strale.module("strale"));
```


## Example

```zig
const std = @import("std");
const strale = @import("strale");
const StraleBytes = strale.StraleBytes;
const StraleUtf8Atomic = strale.StraleUtf8Atomic;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var a = try StraleBytes.initSlice(alloc, "hello");
    defer a.deinit();

    var b = a.clone();
    try b.push(alloc, '!');
    std.debug.print("a = {s}\n", .{a.slice()});
    std.debug.print("b = {s}\n", .{b.slice()});

    var long = try StraleBytes.initSlice(
        alloc,
        "abcdefghijklmnopqrstuvwxyz",
    );
    defer long.deinit();

    var sub = long.substr(10, 10);
    defer sub.deinit();

    std.debug.print("sub = {s}\n", .{sub.slice()});

    var utf8 = try StraleUtf8Atomic.initSlice(alloc, "你好,世界");
    defer utf8.deinit();

    defer utf8.deinit();

    var iter = utf8.split(",");

    while (iter.next()) |c| {
        std.debug.print("{s}\n", .{c});
    }
}
```

## LICENSE

MIT License
