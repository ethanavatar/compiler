const std = @import("std");

pub fn StaticIntegralMap(
    comptime K: type,
    comptime V: type,
) type {
    return struct {
        const Self = @This();
        const Case = struct {
            pattern: union(enum) {
                basic: K,
                range: struct { start: K, end: K },
            },
            result: V,
        };

        fn totalItems(comptime T: type) usize {
            return switch (@typeInfo(T)) {
                .@"struct" => return @bitSizeOf(T) * 255 + 1,
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

        fn asIndex(i: anytype) usize {
            return switch (@typeInfo(K)) {
                .@"struct" => blk: {
                    const as_int: std.meta.Int(.unsigned, @bitSizeOf(K)) = @bitCast(i);
                    break :blk @intCast(as_int);
                },
                .@"enum" => @intFromEnum(i),
                .@"int", .@"comptime_int" => i,
                else => @compileError("supports only enums and integers"),
            };
        }

        items: [totalItems(K)]V,

        pub inline fn init(default_value: V, cases: []const Case) Self {
            var self: Self = .{ .items = @splat(default_value) };
            for (cases) |case| {
                switch (case.pattern) {
                    .basic => |i| {
                        self.items[asIndex(i)] = case.result;
                    },
                    .range => |r| for (asIndex(r.start)..asIndex(r.end + 1)) |i| {
                        self.items[i] = case.result;
                    },
                }
            }
            return self;
        }

        pub inline fn get(self: *const Self, key: K) V {
            return self.items[asIndex(key)];
        }
    };
}

