# Strale

A memory efficient compact, copy-on-write (COW) string type for Zig. <br>
The type occupies **16 bytes** on 64-bit platforms.

Features:
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

## Benchmarks

Benchmark environment:

- OS: macOS 26.5.2 (Darwin 25.5.0)
- Architecture: arm64
- Zig: 0.16.0

### Compact string operations

| Operation | Bytes | Strale | Heap-Allocated []u8 |
|---|---:|---:|---:|
| Creation | 0 | 2.77 ns | 2.78 ns |
| Creation | 11 | 3.31 ns | 11.97 ns |
| Creation | 12 | 3.57 ns | 12.84 ns |
| Creation | 22 | 16.38 ns | 15.48 ns |
| Creation | 23 | 17.99 ns | 16.15 ns |
| Creation | 24 | 15.64 ns | 14.86 ns |
| Creation | 25 | 14.12 ns | 14.78 ns |
| Creation | 50 | 15.55 ns | 14.88 ns |
| Clone | 0 | 1.27 ns | 2.77 ns |
| Clone | 11 | 1.33 ns | 12.63 ns |
| Clone | 12 | 1.33 ns | 12.64 ns |
| Clone | 22 | 1.95 ns | 15.97 ns |
| Clone | 23 | 1.93 ns | 15.54 ns |
| Clone | 24 | 1.92 ns | 14.81 ns |
| Clone | 25 | 1.96 ns | 14.52 ns |
| Clone | 50 | 1.97 ns | 15.01 ns |
| Access | 0 | 1.02 ns | 0.80 ns |
| Access | 11 | 1.01 ns | 0.76 ns |
| Access | 12 | 1.01 ns | 0.77 ns |
| Access | 22 | 1.10 ns | 0.76 ns |
| Access | 23 | 1.09 ns | 0.76 ns |
| Access | 24 | 1.10 ns | 0.76 ns |
| Access | 25 | 1.10 ns | 0.76 ns |
| Access | 50 | 1.09 ns | 0.76 ns |


### Word indexing

The idea and input for this benchmark come from [html5ever Tendril](https://github.com/servo/html5ever/blob/main/tendril-bench/benches/tendril.rs)'s benchmark.


| Input | Size | Heap-Allocated []u8 | Strale |
|---|---:|---:|---:|
| English 1 | 64 KiB | 235.41 us | 161.17 us |
| English 1 | 1 MiB | 3606.88 us | 2365.52 us |
| English 2 | 64 KiB | 238.81 us | 163.89 us |
| English 2 | 1 MiB | 3660.98 us | 2329.87 us |
| Korean | 64 KiB | 115.07 us | 76.25 us |
| Korean | 1 MiB | 1746.92 us | 1104.08 us |
| Korean HTML | 64 KiB | 98.25 us | 64.47 us |
| Korean HTML | 1 MiB | 1497.99 us | 934.74 us |


Run benchmarks by yourself:
```shell
zig build bench -- [iterations]
```

## LICENSE

MIT License
