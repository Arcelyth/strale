# Strale

A memory efficient compact, copy-on-write (COW) string type for Zig.

Strale combines:
- Small String Optimization (SSO)
- Reference counting
- Zero-copy substring views
- Copy-on-write mutation

The type occupies **16 bytes** on 64-bit platforms.

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
const Strale = strale.Strale;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    // create string
    var a = try Strale.initSlice(alloc, "hello");
    defer a.deinit();

    var b = try Strale.initSlice(alloc, " world");
    defer b.deinit();

    // concat
    var c = try a.concat(alloc, &b);
    defer c.deinit();
    std.debug.print("concat: {s}\n", .{c.slice()});

    // substring
    var sub = c.substr(6, 5);
    defer sub.deinit();
    std.debug.print("substr: {s}\n", .{sub.slice()});

    // push
    try sub.push(alloc, '!');
    std.debug.print("after push: {s}\n", .{sub.slice()});

    // pop
    const ch = sub.pop();
    std.debug.print("pop: {?c}\n", .{ch});
    std.debug.print("after pop: {s}\n", .{sub.slice()});

    // find
    const idx = c.find("world");
    std.debug.print("find 'world': {?}\n", .{idx});

    // charAt
    std.debug.print("charAt(1): {?c}\n", .{c.charAt(1)});
}
```

## LICENSE

MIT License
