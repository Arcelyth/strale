const strale = @import("strale.zig");
pub const Strale = strale.Strale;
pub const StraleBytes = strale.StraleBytes;
pub const StraleUtf8 = strale.StraleUtf8;
pub const StraleAtomic = strale.StraleAtomic;
pub const StraleUtf8Atomic = strale.StraleUtf8Atomic;
pub const StraleBytesGlobal = strale.StraleBytesGlobal;
pub const StraleUtf8Global = strale.StraleUtf8Global;
pub const StraleAtomicGlobal = strale.StraleAtomicGlobal;
pub const StraleUtf8AtomicGlobal = strale.StraleUtf8AtomicGlobal;
pub const setGlobalAlloc = strale.setGlobalAlloc;

pub const Format = strale.Format;
pub const Atomicity = strale.Atomicity;

const bd = @import("buffer_deque.zig");
pub const BufferDeque = bd.BufferDeque; 

pub const buffer = @import("buffer_deque.zig");

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("strale_test.zig");
    _ = @import("strale_utf8_test.zig");
    _ = @import("strale_atomic_test.zig");
    _ = @import("strale_global_test.zig");
    _ = @import("buffer_deque_test.zig");
}
