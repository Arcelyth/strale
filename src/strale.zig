const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const Format = enum(u2) {
    utf8,
    byte,
};

/// A compact string type with Small String Optimization (SSO).
/// Strings up to 15 bytes are stored directly inside the object without
/// heap allocation. Larger strings are stored in a reference-counted
/// shared buffer.
///
/// This type is not thread-safe as the ref_count field is not change
/// atomic. You can use this type if you are using single thread or just
/// small string.
pub fn Strale(comptime format: ?Format) type {
    return struct {
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

        pub const CharType = switch (Self.getFormat()) {
            .utf8 => u21,
            .byte => u8,
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

        // Return string's length.
        pub inline fn len(self: *const Self) usize {
            if (self.isInline()) {
                return self.inner.inline_repr.tag_and_len >> 1;
            } else {
                return self.inner.remote_repr.len;
            }
        }

        // Return string's capacity if 'self' is not inline.
        pub fn cap(self: *const Self) ?usize {
            if (self.isInline()) return null;

            const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
            return header.capacity;
        }

        // Return the character at specific position.
        // Return null if string is empty.
        pub fn charAt(self: *const Self, pos: usize) ?u8 {
            if (self.isInline()) {
                const cur_len = self.inner.inline_repr.tag_and_len >> 1;
                if (pos >= cur_len) return null;
                return self.inner.inline_repr.data[pos];
            } else {
                if (pos >= self.inner.remote_repr.len) return null;
                const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
                const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
                return base_data_ptr[self.inner.remote_repr.offset + pos];
            }
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len() == 0;
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
        pub fn substr(self: *const Self, offset: comptime_int, length: comptime_int) Self {
            const current = self.slice();

            std.debug.assert(offset + length <= current.len);

            if (length <= 15) {
                const sub_src = current[offset .. offset + length];
                var inline_res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(length << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                @memcpy(inline_res.inner.inline_repr.data[0..length], sub_src);
                return inline_res;
            }

            const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
            header.ref_count += 1;
            return Self{
                .inner = .{
                    .remote_repr = .{
                        .ptr = self.inner.remote_repr.ptr,
                        .offset = self.inner.remote_repr.offset + offset,
                        .len = length,
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

        /// Append a character to the string and its behaviour depends on the format.
        pub fn push(
            self: *Self,
            alloc: Allocator,
            char: comptime_int,
        ) !void {
            const f = Self.getFormat();
            switch (f) {
                .utf8 => {
                    try self.pushUtf8(alloc, @as(u21, @intCast(char)));
                },

                else => {
                    try self.pushByte(alloc, @as(u8, @intCast(char)));
                },
            }
        }

        /// Append a single byte to the string.
        pub fn pushByte(self: *Self, alloc: Allocator, char: u8) !void {
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

        /// Append a single UTF-8 codepoint to the string.
        pub fn pushUtf8(self: *Self, alloc: Allocator, codepoint: u21) !void {
            var buf: [4]u8 = undefined;
            const n = try std.unicode.utf8Encode(codepoint, &buf);
            const utf8_bytes = buf[0..n];
            const n_u32 = @as(u32, @intCast(n));

            if (self.isInline()) {
                const current_len = self.inner.inline_repr.tag_and_len >> 1;

                if (current_len + n <= 15) {
                    @memcpy(self.inner.inline_repr.data[current_len .. current_len + n], utf8_bytes);
                    self.inner.inline_repr.tag_and_len = @as(u8, @intCast((current_len + n) << 1)) | 1;
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
                    @memcpy(data_ptr[0..current_len], self.inner.inline_repr.data[0..current_len]);
                    @memcpy(data_ptr[current_len .. current_len + n], utf8_bytes);

                    self.inner = .{
                        .remote_repr = .{
                            .ptr = @intFromPtr(header),
                            .offset = 0,
                            .len = @as(u32, @intCast(current_len + n)),
                        },
                    };
                    return;
                }
            }

            const current_len = self.inner.remote_repr.len;
            const current_offset = self.inner.remote_repr.offset;
            const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));

            if (header.ref_count == 1 and (current_offset + current_len + n_u32) <= header.capacity) {
                const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
                @memcpy(base_data_ptr[current_offset + current_len ..][0..n], utf8_bytes);
                self.inner.remote_repr.len += n_u32;
            } else {
                const old_alloc = header.alloc;
                const current_slice = self.slice();

                const new_capacity = @max((current_len + n_u32) * cap_factor, @as(u32, 32));
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
                @memcpy(data_ptr[current_len .. current_len + n], utf8_bytes);

                header.ref_count -= 1;
                if (header.ref_count == 0) {
                    const old_total_size = @sizeOf(Header) + header.capacity;
                    const old_bytes = @as([*]align(@alignOf(Header)) u8, @ptrCast(header))[0..old_total_size];
                    old_alloc.free(old_bytes);
                }

                self.inner.remote_repr = .{
                    .ptr = @intFromPtr(new_header),
                    .offset = 0,
                    .len = current_len + n_u32,
                };
            }
        }

        /// Remove the last character from the string and return it and
        /// does not trigger copy-on-write. Return `null` if the string is empty.
        pub fn pop(self: *Self) ?CharType {
            const f = Self.getFormat();
            switch (f) {
                .utf8 => return self.popUtf8(),
                .byte => return self.popByte(),
            }
        }

        /// Remove the last ascii character from the string and return it.
        pub fn popByte(self: *Self) ?u8 {
            if (self.isInline()) {
                const current_len = self.inner.inline_repr.tag_and_len >> 1;
                if (current_len == 0) return null;

                const char = self.inner.inline_repr.data[current_len - 1];
                self.inner.inline_repr.tag_and_len = @as(u8, @intCast((current_len - 1) << 1)) | 1;
                return char;
            } else {
                const current_len = self.inner.remote_repr.len;
                if (current_len == 0) return null;
                const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
                const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
                const char = base_data_ptr[self.inner.remote_repr.offset + current_len - 1];
                self.inner.remote_repr.len -= 1;

                const new_len = current_len - 1;

                if (new_len <= 15) {
                    self.remoteToInner(new_len);
                }
                return char;
            }
        }

        /// Remove the last utf8 character from the string and return it.
        pub fn popUtf8(self: *Self) ?u21 {
            const src = self.slice();
            if (src.len == 0) return null;

            var start = src.len - 1;

            while (start > 0 and (src[start] & 0xC0) == 0x80) {
                start -= 1;
            }

            const cp_len = src.len - start;

            const codepoint = std.unicode.utf8Decode(src[start..]) catch {
                const b = self.popByte() orelse return null;
                return @as(u21, b);
            };

            if (self.isInline()) {
                const cur = self.inner.inline_repr.tag_and_len >> 1;
                self.inner.inline_repr.tag_and_len = @as(u8, @intCast((cur - cp_len) << 1)) | 1;
            } else {
                self.inner.remote_repr.len -= @as(u32, @intCast(cp_len));

                const new_len = self.inner.remote_repr.len;
                if (new_len <= 15) {
                    self.remoteToInner(new_len);
                }
            }

            return codepoint;
        }

        /// Concatenate two strings and return a new `Strale` instance.
        pub fn concat(self: *const Self, alloc: Allocator, other: *const Self) !Self {
            const s1 = self.slice();
            const s2 = other.slice();
            const total_len = s1.len + s2.len;

            if (total_len <= 15) {
                var res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(total_len << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                @memcpy(res.inner.inline_repr.data[0..s1.len], s1);
                @memcpy(res.inner.inline_repr.data[s1.len..total_len], s2);
                return res;
            } else {
                const total_size = @sizeOf(Header) + total_len;
                const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
                const header = @as(*Header, @ptrCast(bytes.ptr));

                header.* = .{
                    .alloc = alloc,
                    .ref_count = 1,
                    .capacity = @intCast(total_len),
                };

                const data_ptr = bytes[@sizeOf(Header)..];
                @memcpy(data_ptr[0..s1.len], s1);
                @memcpy(data_ptr[s1.len..total_len], s2);

                return Self{
                    .inner = .{
                        .remote_repr = .{
                            .ptr = @intFromPtr(header),
                            .offset = 0,
                            .len = @intCast(total_len),
                        },
                    },
                };
            }
        }

        /// Compare two strings lexicographically.
        pub fn order(self: *const Self, other: *const Self) std.math.Order {
            if (!self.isInline() and !other.isInline()) {
                if (self.inner.remote_repr.ptr == other.inner.remote_repr.ptr and
                    self.inner.remote_repr.offset == other.inner.remote_repr.offset and
                    self.inner.remote_repr.len == other.inner.remote_repr.len)
                {
                    return .eq;
                }
            }

            return mem.order(u8, self.slice(), other.slice());
        }

        pub fn cmp(self: *const Self, other: *const Self) bool {
            switch (self.order(other)) {
                .eq => return true,
                else => return false,
            }
        }

        /// Find the first occurrence of a substring (`needle`) within this string.
        /// Returns the byte index of the match, or `null` if not found.
        pub fn find(self: *const Self, needle: []const u8) ?usize {
            return mem.indexOf(u8, self.slice(), needle);
        }

        /// Find the last occurrence of a substring (`needle`) within this string (Reverse Find).
        /// Returns the byte index of the match, or `null` if not found.
        pub fn rfind(self: *const Self, needle: []const u8) ?usize {
            return mem.lastIndexOf(u8, self.slice(), needle);
        }

        fn fromSubSlice(self: *const Self, sub: []const u8) Self {
            const original = self.slice();
            const length = sub.len;

            if (length <= 15) {
                var res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(length << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                @memcpy(res.inner.inline_repr.data[0..length], sub);
                return res;
            }

            const offset_diff = @intFromPtr(sub.ptr) - @intFromPtr(original.ptr);
            const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
            header.ref_count += 1;

            return Self{
                .inner = .{
                    .remote_repr = .{
                        .ptr = self.inner.remote_repr.ptr,
                        .offset = self.inner.remote_repr.offset + @as(u32, @intCast(offset_diff)),
                        .len = @as(u32, @intCast(length)),
                    },
                },
            };
        }

        /// Return a new string with all leading bytes matching `pat` removed.
        ///
        /// If `pat` is `null`, ASCII whitespace (`" \t\r\n"`) is trimmed.
        pub fn trimStart(self: *const Self, pat: ?[]const u8) Self {
            const p = if (pat) |pat_v| pat_v else " \t\r\n";
            return self.fromSubSlice(mem.trimStart(u8, self.slice(), p));
        }

        /// Return a new string with all trailing bytes matching `pat` removed.
        ///
        /// If `pat` is `null`, ASCII whitespace (`" \t\r\n"`) is trimmed.
        pub fn trimEnd(self: *const Self, pat: ?[]const u8) Self {
            const p = if (pat) |pat_v| pat_v else " \t\r\n";
            return self.fromSubSlice(mem.trimEnd(u8, self.slice(), p));
        }

        /// Return a new string with leading and trailing bytes matching `pat` removed.
        ///
        /// If `pat` is `null`, ASCII whitespace (`" \t\r\n"`) is trimmed.
        pub fn trim(self: *const Self, pat: ?[]const u8) Self {
            const p = if (pat) |pat_v| pat_v else " \t\r\n";
            return self.fromSubSlice(mem.trim(u8, self.slice(), p));
        }

        /// Count the total occurrences of a substring (`needle`) within this string.
        pub fn count(self: *const Self, needle: []const u8) usize {
            return mem.count(u8, self.slice(), needle);
        }

        /// Reverse the string contents in-place.
        ///
        /// If the string is inline, it mutates local bytes directly.
        /// If it is a shared remote string, it safely triggers COW (Copy-On-Write)
        /// using its internal allocator before reversing.
        pub fn reverse(self: *Self) !void {
            const f = Self.getFormat();
            switch (f) {
                .utf8 => {
                    if (self.isInline()) {
                        const inline_len = self.inner.inline_repr.tag_and_len >> 1;
                        if (inline_len <= 1) return;
                        reverseUtf8Slice(self.inner.inline_repr.data[0..inline_len]);
                    } else {
                        try self.cow();
                        const current_len = self.inner.remote_repr.len;
                        if (current_len <= 1) return;

                        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
                        const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
                        const mutable_slice = base_data_ptr[self.inner.remote_repr.offset .. self.inner.remote_repr.offset + current_len];
                        reverseUtf8Slice(mutable_slice);
                    }
                },

                else => {
                    if (self.isInline()) {
                        const inline_len = self.inner.inline_repr.tag_and_len >> 1;
                        if (inline_len <= 1) return;
                        mem.reverse(u8, self.inner.inline_repr.data[0..inline_len]);
                    } else {
                        try self.cow();
                        if (self.inner.remote_repr.len <= 1) return;

                        const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
                        const base_data_ptr = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
                        const mutable_slice = base_data_ptr[self.inner.remote_repr.offset .. self.inner.remote_repr.offset + self.inner.remote_repr.len];
                        mem.reverse(u8, mutable_slice);
                    }
                },
            }
        }

        fn reverseUtf8Slice(s: []u8) void {
            mem.reverse(u8, s);
            var i: usize = 0;
            while (i < s.len) {
                const start = i;
                while (i < s.len and (s[i] & 0xC0) == 0x80) : (i += 1) {}

                if (i < s.len) {
                    mem.reverse(u8, s[start .. i + 1]);
                    i += 1;
                } else {
                    mem.reverse(u8, s[start..i]);
                }
            }
        }

        /// Iterator returned by `splitToStrale()`.
        ///
        /// Each yielded element is a `Strale` that shares the original storage
        /// whenever possible. Small substrings (15 bytes or fewer) are stored
        /// inline automatically.
        ///
        /// The iterator owns one cloned reference to the original string.
        /// Call `deinit()` after iteration to release that reference.
        pub fn SplitIterator(comptime T: type) type {
            return struct {
                owner: Self,
                iter: T,

                /// Return the first substring.
                ///
                /// This resets the iterator to the beginning and returns the first element.
                pub fn first(self: *SplitIterator(T)) Self {
                    const sub = self.iter.first();
                    return self.owner.fromSubSlice(sub);
                }

                /// Advance the iterator and return the next substring.
                ///
                /// Return `null` when all substrings have been consumed.
                pub fn next(self: *SplitIterator(T)) ?Self {
                    const sub = self.iter.next() orelse return null;
                    return self.owner.fromSubSlice(sub);
                }

                /// Return the next substring without advancing the iterator.
                ///
                /// Return `null` if no more substrings remain.
                pub fn peek(self: *SplitIterator(T)) ?Self {
                    const sub = self.iter.peek() orelse return null;
                    return self.owner.fromSubSlice(sub);
                }

                /// Reset the iterator back to the beginning.
                pub fn reset(self: *SplitIterator(T)) void {
                    self.iter.reset();
                }

                /// Return the remaining portion of the string without further splitting.
                ///
                /// The returned string shares the original storage whenever possible.
                pub fn rest(self: SplitIterator(T)) Self {
                    const sub = self.iter.rest();
                    return self.owner.fromSubSlice(sub);
                }

                /// Release the iterator's internal reference to the original string.
                ///
                /// This must be called after the iterator is no longer needed.
                pub fn deinit(self: *SplitIterator(T)) void {
                    self.owner.deinit();
                }
            };
        }

        pub const SplitSeqIterator = SplitIterator(mem.SplitIterator(u8, .sequence));
        pub const SplitLineIterator = SplitIterator(mem.SplitIterator(u8, .scalar));

        /// Return a standard Zig split iterator yielding byte slices.
        pub fn split(self: *const Self, delimiter: []const u8) mem.SplitIterator(u8, .sequence) {
            return mem.splitSequence(u8, self.slice(), delimiter);
        }

        /// Return an iterator yielding `Strale` substrings.
        pub fn splitToStrale(self: *const Self, delimiter: []const u8) SplitSeqIterator {
            return SplitSeqIterator{
                .owner = self.clone(),
                .iter = mem.splitSequence(u8, self.slice(), delimiter),
            };
        }

        /// Return a standard Zig split iterator over the lines of a string.
        pub fn lines(self: *const Self) mem.SplitIterator(u8, .scalar) {
            return mem.splitScalar(u8, self.slice(), '\n');
        }

        /// Return an iterator over the lines of a string.
        pub fn linesToStrale(self: *const Self) SplitLineIterator {
            return SplitLineIterator{
                .owner = self.clone(),
                .iter = mem.splitScalar(u8, self.slice(), '\n'),
            };
        }

        /// Return a new string consisting of this string repeated `n` times.
        pub fn repeat(self: *const Self, alloc: Allocator, n: usize) !Self {
            const src = self.slice();
            if (n == 0 or src.len == 0) return initEmpty();

            const total_len = src.len * n;

            if (total_len <= 15) {
                var res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(total_len << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    @memcpy(res.inner.inline_repr.data[i * src.len .. (i + 1) * src.len], src);
                }
                return res;
            } else {
                const total_size = @sizeOf(Header) + total_len;
                const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
                const header = @as(*Header, @ptrCast(bytes.ptr));

                header.* = .{
                    .alloc = alloc,
                    .ref_count = 1,
                    .capacity = @intCast(total_len),
                };

                const data_ptr = bytes[@sizeOf(Header)..];
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    @memcpy(data_ptr[i * src.len .. (i + 1) * src.len], src);
                }

                return Self{
                    .inner = .{
                        .remote_repr = .{
                            .ptr = @intFromPtr(header),
                            .offset = 0,
                            .len = @intCast(total_len),
                        },
                    },
                };
            }
        }

        /// Convert all ASCII characters to lowercase.
        pub fn toLowercase(self: *const Self, alloc: Allocator) !Self {
            const src = self.slice();
            const length = src.len;

            if (length <= 15) {
                var res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(length << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                for (src, 0..) |c, i| {
                    res.inner.inline_repr.data[i] = std.ascii.toLower(c);
                }
                return res;
            }

            const total_size = @sizeOf(Header) + length;
            const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
            const header = @as(*Header, @ptrCast(bytes.ptr));
            header.* = .{
                .alloc = alloc,
                .ref_count = 1,
                .capacity = @intCast(length),
            };

            const data_ptr = bytes[@sizeOf(Header)..][0..length];
            for (src, 0..) |c, i| {
                data_ptr[i] = std.ascii.toLower(c);
            }

            return Self{
                .inner = .{
                    .remote_repr = .{
                        .ptr = @intFromPtr(header),
                        .offset = 0,
                        .len = @intCast(length),
                    },
                },
            };
        }

        /// Convert all ASCII characters to uppercase.
        pub fn toUppercase(self: *const Self, alloc: Allocator) !Self {
            const src = self.slice();
            const length = src.len;

            if (length <= 15) {
                var res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(length << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                for (src, 0..) |c, i| {
                    res.inner.inline_repr.data[i] = std.ascii.toUpper(c);
                }
                return res;
            }

            const total_size = @sizeOf(Header) + length;
            const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
            const header = @as(*Header, @ptrCast(bytes.ptr));
            header.* = .{
                .alloc = alloc,
                .ref_count = 1,
                .capacity = @intCast(length),
            };

            const data_ptr = bytes[@sizeOf(Header)..][0..length];
            for (src, 0..) |c, i| {
                data_ptr[i] = std.ascii.toUpper(c);
            }

            return Self{
                .inner = .{
                    .remote_repr = .{
                        .ptr = @intFromPtr(header),
                        .offset = 0,
                        .len = @intCast(length),
                    },
                },
            };
        }

        /// Convert the first ASCII character to uppercase and all
        /// remaining ASCII characters to lowercase.
        pub fn toCapitalized(self: *const Self, alloc: Allocator) !Self {
            const src = self.slice();
            const length = src.len;

            if (length <= 15) {
                var res = Self{
                    .inner = .{
                        .inline_repr = .{
                            .tag_and_len = @as(u8, @intCast(length << 1)) | 1,
                            .data = undefined,
                        },
                    },
                };
                res.inner.inline_repr.data[0] = std.ascii.toUpper(src[0]);
                for (src[1..], 1..) |c, i| {
                    res.inner.inline_repr.data[i] = std.ascii.toLower(c);
                }
                return res;
            }

            const total_size = @sizeOf(Header) + length;
            const bytes = try alloc.allocWithOptions(u8, total_size, mem.Alignment.of(Header), null);
            const header = @as(*Header, @ptrCast(bytes.ptr));
            header.* = .{
                .alloc = alloc,
                .ref_count = 1,
                .capacity = @intCast(length),
            };

            const data_ptr = bytes[@sizeOf(Header)..][0..length];
            data_ptr[0] = std.ascii.toUpper(src[0]);
            for (src[1..], 1..) |c, i| {
                data_ptr[i] = std.ascii.toLower(c);
            }

            return Self{
                .inner = .{
                    .remote_repr = .{
                        .ptr = @intFromPtr(header),
                        .offset = 0,
                        .len = @intCast(length),
                    },
                },
            };
        }

        pub inline fn getFormat() Format {
            const f = format orelse .byte;
            return f;
        }

        // Make sure new_len <= 15.
        fn remoteToInner(self: *Self, new_len: usize) void {
            const header = @as(*Header, @ptrFromInt(self.inner.remote_repr.ptr));
            const base = @as([*]u8, @ptrCast(header)) + @sizeOf(Header);
            var buf: [15]u8 = undefined;
            @memcpy(buf[0..new_len], base[self.inner.remote_repr.offset..][0..new_len]);

            self.deinit();
            self.inner = .{
                .inline_repr = .{
                    .tag_and_len = @as(u8, @intCast(new_len << 1)) | 1,
                    .data = buf,
                },
            };
        }
    };
}

pub const StraleBytes = Strale(.byte);
pub const StraleUtf8 = Strale(.utf8);
