const std = @import("std");
const root = @import("root.zig");
const StaticIntegralMap = root.StaticIntegralMap;

const CharacterClass = enum(u8) {
    const Self = @This();
    pub const digit_range: root.Range(Self) = .{ .start = .Zero, .end = .NonZeroDigit };
    pub const letter_range: root.Range(Self) = .{ .start = .Letter, .end = .O };

    Eof,
    Character,

    Zero, One, NonZeroDigit,

    Letter, B, X, O,
    Whitespace, NewLine,

    ForwardSlash,
    Period,
};

const State = enum(u8) {
    Illegal,
    Start,
    Eof,

    Character,

    InIdentifier, EndIdentifier,

    FoundZero,
    InNumber, EndInteger,
    InFloat, EndFloat,
    InHex, EndHex,
    InBinary, EndBinary,
    InOctal, EndOctal,

    FoundForwardSlash, EndForwardSlash,
    InLineComment, EndLineComment,
};

const character_class_map = StaticIntegralMap(u8, CharacterClass).init(.Character, &.{
    .{ .pattern = .{ .basic =  0 }, .result = .Eof },

    .{ .pattern = .{ .range = .{ .start = '0', .end = '9' } }, .result = .NonZeroDigit  },
    .{ .pattern = .{ .basic = '0' }, .result = .Zero }, // Overwrite
    .{ .pattern = .{ .basic = '1' }, .result = .One }, // Overwrite

    .{ .pattern = .{ .range = .{ .start = 'a', .end = 'z' } }, .result = .Letter },
    .{ .pattern = .{ .range = .{ .start = 'A', .end = 'Z' } }, .result = .Letter },
    .{ .pattern = .{ .basic = '_' }, .result = .Letter },

    .{ .pattern = .{ .basic = 'b' }, .result = .B },
    .{ .pattern = .{ .basic = 'x' }, .result = .X },
    .{ .pattern = .{ .basic = 'o' }, .result = .O },

    .{ .pattern = .{ .basic = ' ' }, .result = .Whitespace },
    .{ .pattern = .{ .range = .{ .start = '\t', .end = '\r' } }, .result = .Whitespace },
    .{ .pattern = .{ .basic = '\n' }, .result = .NewLine }, // Overwrite
    
    .{ .pattern = .{ .basic = '/' }, .result = .ForwardSlash },
    .{ .pattern = .{ .basic = '.' }, .result = .Period       },
});

const CharacterClassToState = StaticIntegralMap(CharacterClass, State);
const default_transition = CharacterClassToState.init(State.Illegal, &.{});
const transition_map = StaticIntegralMap(State, CharacterClassToState).init(default_transition, &.{

    .{ .pattern = .{ .basic = .Start }, .result = CharacterClassToState.init(.Illegal, &.{
        .{ .pattern = .{ .basic = .Eof       }, .result = .Eof       },
        .{ .pattern = .{ .basic = .Character }, .result = .Character },

        // Transition back to start to skip a character, not counting it towards the token
        .{ .pattern = .{ .basic = .Whitespace }, .result = .Start },
        .{ .pattern = .{ .basic = .NewLine    }, .result = .Start },

        .{ .pattern = .{ .range = CharacterClass.letter_range }, .result = .InIdentifier },
        .{ .pattern = .{ .basic = .NonZeroDigit }, .result = .InNumber },
        .{ .pattern = .{ .basic = .Zero }, .result = .FoundZero },

        .{ .pattern = .{ .basic = .ForwardSlash }, .result = .FoundForwardSlash },
    }) },

    .{ .pattern = .{ .basic = .FoundForwardSlash }, .result = CharacterClassToState.init(.EndForwardSlash, &.{
        .{ .pattern = .{ .basic = .ForwardSlash }, .result = .InLineComment },
    }) },

    .{ .pattern = .{ .basic = .InLineComment }, .result = CharacterClassToState.init(.InLineComment, &.{
        .{ .pattern = .{ .basic = .NewLine }, .result = .EndLineComment },
    }) },

    .{ .pattern = .{ .basic = .InIdentifier }, .result = CharacterClassToState.init(.EndIdentifier, &.{
        .{ .pattern = .{ .range = CharacterClass.letter_range }, .result = .InIdentifier },
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InIdentifier },
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InIdentifier },
    }) },

    .{ .pattern = .{ .basic = .FoundZero }, .result = CharacterClassToState.init(.EndInteger, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InNumber },
        .{ .pattern = .{ .basic = .Period }, .result = .InFloat },
        .{ .pattern = .{ .basic = .X }, .result = .InHex },
        .{ .pattern = .{ .basic = .B }, .result = .InBinary },
        .{ .pattern = .{ .basic = .O }, .result = .InOctal },
    }) },

    .{ .pattern = .{ .basic = .InHex }, .result = CharacterClassToState.init(.EndHex, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InHex },
        .{ .pattern = .{ .range = CharacterClass.letter_range }, .result = .InHex },
    }) },

    .{ .pattern = .{ .basic = .InBinary }, .result = CharacterClassToState.init(.EndBinary, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InBinary },
    }) },

    .{ .pattern = .{ .basic = .InOctal }, .result = CharacterClassToState.init(.EndOctal, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InOctal },
    }) },

    .{ .pattern = .{ .basic = .InNumber }, .result = CharacterClassToState.init(.EndInteger, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InNumber },
        .{ .pattern = .{ .basic = .Period }, .result = .InFloat },
    }) },

    .{ .pattern = .{ .basic = .InFloat }, .result = CharacterClassToState.init(.EndFloat, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InFloat },
    }) },

});

const Advance = struct {
    const T = i8;
    pub const zero: @This() = .{ .cursor = 0, .token = 0 };
    pub const one:  @This() = .{ .cursor = 0, .token = 1 };
    pub const skip: @This() = .{ .cursor = 1, .token = 0 };
    cursor: T, token: T,
};

const state_advance_map = StaticIntegralMap(State, Advance).init(.one, &.{
    .{ .pattern = .{ .basic =  .Start          }, .result = .skip },
    .{ .pattern = .{ .basic =  .Eof            }, .result = .zero },

    .{ .pattern = .{ .basic =  .EndIdentifier   }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndInteger      }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndFloat        }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndHex          }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndBinary       }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndOctal        }, .result = .zero },

    .{ .pattern = .{ .basic =  .EndForwardSlash }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndLineComment  }, .result = .zero },
});

const final_states_map = StaticIntegralMap(State, bool).init(false, &.{
    .{ .pattern = .{ .basic =  .Eof            }, .result = true },
    .{ .pattern = .{ .basic =  .Illegal        }, .result = true },

    .{ .pattern = .{ .basic =  .EndIdentifier  }, .result = true },
    .{ .pattern = .{ .basic =  .EndInteger     }, .result = true },
    .{ .pattern = .{ .basic =  .EndFloat       }, .result = true },
    .{ .pattern = .{ .basic =  .EndHex         }, .result = true },
    .{ .pattern = .{ .basic =  .EndBinary      }, .result = true },
    .{ .pattern = .{ .basic =  .EndOctal       }, .result = true },

    .{ .pattern = .{ .basic =  .EndLineComment }, .result = true },
    .{ .pattern = .{ .basic =  .Character      }, .result = true },
});

const TokenKind = union(enum) {
    illegal: void,
    identifier: IdentifiersMap.Handle,
    integer: u32,
    float: f32,

    keyword_pub: void,
    keyword_fn: void,

    type_void: void,
    type_i32: void,

    character: u8,
    comment: void,
};

// TODO: replace this with perfect hashing,
// because this does a linear search on every lookup
const keywords_map = std.StaticStringMap(TokenKind).initComptime(&.{
    .{ "pub",  .keyword_pub },
    .{ "fn",   .keyword_fn  },

    .{ "void", .type_void },
    .{ "i32",  .type_i32  },
});

const IdentifiersMap = root.HandleMap([]const u8, std.array_hash_map.StringContext);

const Tokenizer = struct {
    const Self = @This();

    source: [:0]const u8,
    offset: usize,

    allocator: std.mem.Allocator,
    identifiers: IdentifiersMap = .empty,

    pub fn init(allocator: std.mem.Allocator, source: [:0]const u8) Self {
        return .{ .source = source, .offset = 0, .allocator = allocator };
    }

    pub fn next(self: *Self) !?struct { []const u8, TokenKind } {
        if (self.offset >= self.source.len) return null;

        var state: State = .Start;
        var token_length: usize = 0;

        while (!final_states_map.get(state)) {
            const c = self.source[self.offset + token_length];
            const class = character_class_map.get(c);
            state = transition_map.get(state).get(class);

            const advance = state_advance_map.get(state);
            token_length += @intCast(advance.token);
            self.offset  += @intCast(advance.cursor);
        }

        const token = self.source[self.offset..(self.offset + token_length)];
        self.offset += token_length;

        //std.debug.print("{s}: {any}\n", .{ token, state });

        const kind: TokenKind = switch (state) {
            .Illegal       => .illegal,
            .EndIdentifier => blk: {
                if (keywords_map.get(token)) |keyword| break :blk keyword;
                break :blk .{ .identifier = try self.identifiers.put(self.allocator, token) };
            },

            .EndInteger, .EndHex,
            .EndOctal, .EndBinary => .{ .integer = try std.fmt.parseInt(u32, token, 0) },
            .EndFloat   => .{ .float   = try std.fmt.parseFloat(f32, token) },

            .Character  => .{ .character = token[0] },
            .EndLineComment => .comment,

            else => {
                std.debug.print("unhandled: {any}\n", .{ state });
                unreachable;
            },
        };

        return .{ token, kind };
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const source = 
        \\pub fn add(a: i32, b: i32) i32 {
        \\    c = 42; 
        \\    _ = c; // Unused
        \\    return a + b;
        \\}
        \\
        \\pub fn main() !void {
        \\    const _f2  = 2.0;
        \\    const _f02 = 0.2;
        \\
        \\    const decimal_int = 98222;
        \\    const hex_int = 0xff;
        \\    const another_hex_int = 0xFF;
        \\    const octal_int = 0o755;
        \\    const binary_int = 0b11110000;
        \\}
    ;

    var iter = Tokenizer.init(allocator, source);
    while (try iter.next()) |p| {
        const token, const kind = p;
        switch (kind) {
            .character => |c| std.debug.print("{c}\n", .{ c }),
            else => std.debug.print("{s}\t{any}\n", .{ token, kind }),
        }
    }
}

