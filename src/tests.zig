comptime {
    _ = @import("strale_test.zig");
    _ = @import("strale_utf8_test.zig");
    _ = @import("strale_atomic_test.zig");
    _ = @import("buffer_deque_test.zig");
}

pub const strale = @import("strale.zig");
pub const buffer = @import("buffer_deque.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
