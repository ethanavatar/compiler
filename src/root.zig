const std = @import("std");

pub fn HandleMap(comptime T: type, comptime Context: type) type {
    return struct {
        pub const empty: @This() = .{ };
        pub const Handle = struct { handle: u32 };
        map: std.ArrayHashMapUnmanaged(T, void, Context, true) = .empty,

        pub fn put(self: *@This(), allocator: std.mem.Allocator, item: T) !Handle {
            const gop = try self.map.getOrPut(allocator, item);
            return .{ .handle = @intCast(gop.index) };
        }

        pub fn get(self: *@This(), handle: Handle) []const u8 {
            return self.map.keys()[handle.handle];
        }
    };
}

pub fn totalItems(comptime T: type) usize {
    return switch (@typeInfo(T)) {
        .@"enum" => |enum_info| {
            if (enum_info.fields.len == 0) @compileError("Enum has no fields.");

            var max_value = enum_info.fields[0].value;
            inline for (enum_info.fields[1..]) |field| {
                max_value = @max(max_value, field.value);
            }

            return max_value + 1;
        },
        .@"int", .@"comptime_int" => std.math.maxInt(T) + 1,
        else => @compileError("supports only enums and integers"),
    };
}

pub fn asIndex(comptime T: type, i: anytype) usize {
    if (@TypeOf(i) != T) @compileError("type mismatch");
    return switch (@typeInfo(T)) {
        .@"enum" => @intFromEnum(i),
        .@"int", .@"comptime_int" => i,
        else => @compileError("supports only enums and integers"),
    };
}

pub fn Range(comptime T: type) type {
    return struct { start: T, end: T };
}

pub fn StaticIntegralMap(
    comptime K: type,
    comptime V: type,
) type {
    return struct {
        const Self = @This();
        const Case = struct {
            pattern: union(enum) {
                basic: K,
                range: Range(K),
            },
            result: V,
        };

        items: [totalItems(K)]V,

        pub inline fn init(default_value: V, cases: []const Case) Self {
            var self: Self = .{ .items = @splat(default_value) };
            for (cases) |case| {
                switch (case.pattern) {
                    .basic => |i| {
                        self.items[asIndex(K, i)] = case.result;
                    },
                    .range => |r| for (asIndex(K, r.start)..asIndex(K, r.end) + 1) |i| {
                        self.items[i] = case.result;
                    },
                }
            }
            return self;
        }

        pub inline fn initItems(items: [totalItems(K)]V, cases: []const Case) Self {
            var self: Self = .{ .items = items };
            for (cases) |case| {
                switch (case.pattern) {
                    .basic => |i| {
                        self.items[asIndex(K, i)] = case.result;
                    },
                    .range => |r| for (asIndex(K, r.start)..asIndex(K, r.end) + 1) |i| {
                        self.items[i] = case.result;
                    },
                }
            }
            return self;
        }

        pub inline fn get(self: *const Self, key: K) V {
            return self.items[asIndex(K, key)];
        }
    };
}

