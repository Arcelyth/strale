/// Benchmarks word indexing, compares zig slice with Strale.
const std = @import("std");
const strale = @import("strale");
const Benchmark = @import("Benchmark.zig");

const Str = strale.Strale(.utf8, .not_atomic, false);

pub const StringBench = struct {
    allocator: std.mem.Allocator,
    input: []u8,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, size: usize) !StringBench {
        const repetitions = (size + text.len - 1) / text.len;
        const input = try allocator.alloc(u8, repetitions * text.len);
        for (0..repetitions) |i| @memcpy(input[i * text.len ..][0..text.len], text);
        return .{ .allocator = allocator, .input = input };
    }

    pub fn deinit(self: *StringBench) void {
        self.allocator.free(self.input);
    }

    pub fn step(self: *StringBench) !usize {
        var index: std.AutoHashMap(u21, std.ArrayList([]u8)) = .init(self.allocator);
        defer {
            var values = index.valueIterator();
            while (values.next()) |words| {
                for (words.items) |word| self.allocator.free(word);
                words.deinit(self.allocator);
            }
            index.deinit();
        }

        var words = std.mem.splitScalar(u8, self.input, ' ');
        while (words.next()) |word| {
            if (word.len == 0) continue;
            const key = std.unicode.utf8Decode(word[0..try std.unicode.utf8ByteSequenceLength(word[0])]) catch word[0];
            const owned = try self.allocator.dupe(u8, word);
            errdefer self.allocator.free(owned);
            const entry = try index.getOrPut(key);
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            try entry.value_ptr.append(self.allocator, owned);
        }
        return index.count();
    }

    pub fn benchmark(self: *StringBench, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};

pub const StraleBench = struct {
    allocator: std.mem.Allocator,
    input: Str,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, size: usize) !StraleBench {
        var input = Str.initEmpty();
        errdefer input.deinit();
        while (input.len() < size) try input.append(allocator, text);
        return .{ .allocator = allocator, .input = input };
    }

    pub fn deinit(self: *StraleBench) void {
        self.input.deinit();
    }

    pub fn step(self: *StraleBench) !usize {
        var index: std.AutoHashMap(u21, std.ArrayList(Str)) = .init(self.allocator);
        defer {
            var values = index.valueIterator();
            while (values.next()) |words| {
                for (words.items) |*word| word.deinit();
                words.deinit(self.allocator);
            }
            index.deinit();
        }

        var words = self.input.splitToStrale(" ");
        defer words.deinit();
        while (words.next()) |word_value| {
            var word = word_value;
            if (word.isEmpty()) {
                word.deinit();
                continue;
            }
            const key = word.peek().?;
            const entry = try index.getOrPut(key);
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            entry.value_ptr.append(self.allocator, word) catch |err| {
                word.deinit();
                return err;
            };
        }
        return index.count();
    }

    pub fn benchmark(self: *StraleBench, name: []const u8) Benchmark {
        return Benchmark.init(name, self, step);
    }
};
