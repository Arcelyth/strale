const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

/// A compact string type with Small String Optimization (SSO).
/// Strings up to 15 bytes are stored directly inside the object without
/// heap allocation. Larger strings are stored in a reference-counted
/// shared buffer.
///
/// This type is not thread-safe as the ref_count field is not change
/// atomic. You can use this type if you are using single thread or just
/// small string.
pub const Strale = struct {
    const Self = @This();
    const init_capacity = 32;
    const cap_factor = 2;

    inner: extern union { inline_repr: extern struct {
        tag_and_len: u8,
        data: [15]u8,
    }, remote_repr: extern struct {
        ptr: usize,
        offset: u32,
        len: u32,
    } },

    const Header = struct {
        alloc: Allocator,
        ref_count: u32,
        capacity: u32,
    };

    pub inline fn isInline(self: *const Self) bool {
        return (self.inner.inline_repr.tag_and_len & 1) == 1;
    }

    /// Create an empty string.
    pub fn initEmpty() Self {
        return Self{ .inner = .{ .inline_repr = .{
            .tag_and_len = 1,
            .data = undefined,
        } } };
    }

    /// Create a string from the given byte slice.
    ///
    /// If the slice length is 15 bytes or less, the contents are copied
    /// directly into the inline storage.
    ///
    /// For longer strings, a shared heap allocation is created containing
    /// both a reference-counted header and the string data.
    pub fn initSlice(alloc: Allocator, src: []const u8) !Self {
        if (src.len <= 15) {
            var self = Self{
                .inner = .{
                    .inline_repr = .{
                        .tag_and_len = @as(u8, @intCast(src.len << 1)) | 1,
                        .data = undefined,
                    },
                },
            };
            @memcpy(self.inner.inline_repr.data[0..src.len], src);
            return self;
        } else {
            const total_size = @sizeOf(Header) + src.len;
            const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
            const header = @as(*Header, @ptrCast(bytes.ptr));

            header.* = .{
                .alloc = alloc,
                .ref_count = 1,
                .capacity = @intCast(src.len),
            };

            const data_ptr = bytes[@sizeOf(Header)..];
            @memcpy(data_ptr, src);

            return Self{
                .inner = .{
                    .remote_repr = .{
                        .ptr = @intFromPtr(header),
                        .offset = 0,
                        .len = @intCast(src.len),
                    },
                },
            };
        }
    }

    /// Release the resources owned by this string.
    ///
    /// Inline strings require no cleanup.
    ///
    /// For remote strings, the reference count is decremented and the
    /// backing allocation is freed when the count reaches zero.
    pub fn deinit(self: *Self) void {
        if (self.isInline()) return;

        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
        header.ref_count -= 1;
        if (header.ref_count == 0) {
            const total_size = @sizeOf(Header) + header.capacity;
            const alloc = header.alloc;
            const bytes = @as([*]align(@alignOf(Header)) u8, @ptrCast(header))[0..total_size];
            alloc.free(bytes);
        }
    }

    /// Return the reference count if 'self' is not inline.
    pub fn ref_count(self: *const Self) ?u32 {
        if (self.isInline()) return null;

        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
        return header.ref_count;
    }

    /// Create a new reference to this string.
    ///
    /// Inline strings are copied directly.
    ///
    /// Heap-backed strings share the same underlying allocation. The
    /// allocation's reference count is incremented and the returned value
    /// points to the same storage.
    ///
    /// The caller becomes responsible for eventually calling `deinit()`
    /// on the returned string.
    ///
    /// Copying a `Strale` using plain assignment does not update the
    /// reference count and may result in double-free errors. Use `clone()`
    /// whenever an additional owned reference is required.
    pub fn clone(self: *const Self) Self {
        if (self.isInline()) return self.*;

        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
        header.ref_count += 1;
        return self.*;
    }

    /// Return the string contents as a read-only byte slice.
    pub fn slice(self: *const Self) []const u8 {
        if (self.isInline()) {
            const length = self.inner.inline_repr.tag_and_len >> 1;
            return self.inner.inline_repr.data[0..length];
        } else {
            const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
            const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
            return base_data_ptr[self.inner.remote_repr.offset .. self.inner.remote_repr.offset + self.inner.remote_repr.len];
        }
    }

    /// Return a substring of this string.
    ///
    /// For substrings whose length is 15 bytes or less, the result is stored
    /// inline and does not share storage with the original string.
    ///
    /// Longer substrings share the underlying allocation by incrementing the
    /// reference count and adjusting the slice offset.
    pub fn substr(self: *const Self, offset: comptime_int, len: comptime_int) Self {
        const current = self.slice();

        std.debug.assert(offset + len <= current.len);

        if (len <= 15) {
            const sub_src = current[offset .. offset + len];
            var inline_res = Self{
                .inner = .{
                    .inline_repr = .{
                        .tag_and_len = @as(u8, @intCast(len << 1)) | 1,
                        .data = undefined,
                    },
                },
            };
            @memcpy(inline_res.inner.inline_repr.data[0..len], sub_src);
            return inline_res;
        }

        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
        header.ref_count += 1;
        return Self{
            .inner = .{
                .remote_repr = .{
                    .ptr = self.inner.remote_repr.ptr,
                    .offset = self.inner.remote_repr.offset + offset,
                    .len = len,
                },
            },
        };
    }

    /// Providing clone-on-write (COW) functionality.
    ///
    /// If the string is stored inline, no action is performed.
    ///
    /// If the string is heap-allocated and shared by multiple instances,
    /// a new allocation is created and the current contents are copied into it.
    ///
    /// After this call returns successfully, any heap-backed string is
    /// guaranteed to have a reference count of one and may be safely modified
    /// in-place by internal mutation routines.
    pub fn cow(self: *Self) !void {
        if (self.isInline()) return;

        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
        if (header.ref_count == 1) return;

        const current_data = self.slice();
        const alloc = header.alloc;
        const new_data = try Self.initSlice(alloc, current_data);

        header.ref_count -= 1;
        self.* = new_data;
    }

    /// Append a single character to the string.
    ///
    /// If the string is inline and has room, it writes directly.
    /// If it needs to grow or trigger COW, it expands geometrically (doubling capacity 
    /// by default) to maintain high performance for consecutive pushes.
    pub fn push(self: *Self, alloc: Allocator, char: u8) !void {
        if (self.isInline()) {
            const current_len = self.inner.inline_repr.tag_and_len >> 1;

            if (current_len < 15) {
                self.inner.inline_repr.data[current_len] = char;
                self.inner.inline_repr.tag_and_len = @as(u8, @intCast((current_len + 1) << 1)) | 1;
                return;
            } else {
                const new_capacity = init_capacity;
                const total_size = @sizeOf(Header) + new_capacity;
                const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
                const header = @as(*Header, @ptrCast(bytes.ptr));

                header.* = .{
                    .alloc = alloc,
                    .ref_count = 1,
                    .capacity = new_capacity,
                };

                const data_ptr = bytes[@sizeOf(Header)..];
                @memcpy(data_ptr[0..15], self.inner.inline_repr.data[0..15]);
                data_ptr[15] = char;

                self.inner = .{
                    .remote_repr = .{
                        .ptr = @intFromPtr(header),
                        .offset = 0,
                        .len = 16,
                    },
                };
                return;
            }
        }

        const current_len = self.inner.remote_repr.len;
        const current_offset = self.inner.remote_repr.offset;
        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));

        // not shared
        if (header.ref_count == 1 and (current_offset + current_len) < header.capacity) {
            const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
            base_data_ptr[current_offset + current_len] = char;
            self.inner.remote_repr.len += 1;
        } else {
            // shared
            const old_alloc = header.alloc;
            const current_slice = self.slice();

            const new_capacity = @max((current_len + 1) * cap_factor, @as(u32, 32));
            const total_size = @sizeOf(Header) + new_capacity;

            const bytes = try old_alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
            const new_header = @as(*Header, @ptrCast(bytes.ptr));

            new_header.* = .{
                .alloc = old_alloc,
                .ref_count = 1,
                .capacity = new_capacity,
            };

            const data_ptr = bytes[@sizeOf(Header)..];
            @memcpy(data_ptr[0..current_len], current_slice);
            data_ptr[current_len] = char;

            header.ref_count -= 1;
            if (header.ref_count == 0) {
                const old_total_size = @sizeOf(Header) + header.capacity;
                const old_bytes = @as([*]align(@alignOf(Header)) u8, @ptrCast(header))[0..old_total_size];
                old_alloc.free(old_bytes);
            }

            self.inner.remote_repr = .{
                .ptr = @intFromPtr(new_header),
                .offset = 0,
                .len = current_len + 1,
            };
        }
    }
};
