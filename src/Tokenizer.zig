const std = @import("std");
const root = @import("root.zig");
const StaticIntegralMap = root.StaticIntegralMap;

const Self = @This();

source: [:0]const u8,
offset: usize,

pub fn init(source: [:0]const u8) Self {
    return .{ .source = source, .offset = 0 };
}

pub fn next(self: *Self) Token {
    var state: State = .Start;
    var token_length: usize = 0;

    var kind: ?TokenKind = null;
    while (kind == null): (final_states_map.getInto(state, &kind)) {
        const c = self.source[self.offset + token_length];
        const class = character_class_map.get(c);
        state = transition_map.get(state).get(class);

        const advance = state_advance_map.get(state);
        token_length += @intCast(advance.token);
        self.offset  += @intCast(advance.cursor);
    }

    const token_start = self.offset;
    self.offset += token_length;

    return .{
        .kind = kind orelse std.debug.panic("unhandled final state: {any}\n", .{ state }),
        .offset = @intCast(token_start),
    };
}

pub const TokenKind = enum {
    eof,
    illegal,
    identifier,
    integer,
    float,
    character,
    comment,
};

pub const Token = struct {
    kind: TokenKind,
    offset: u32,
};

const CharacterClass = enum(u8) {
    pub const digit_range: root.Range(@This()) = .{ .start = .@"0", .end = .@"9" };
    pub const letter_range: root.Range(@This()) = .{ .start = .a, .end = .@"_" };

    Eof,
    Character,

    @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",

    a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    @"_",

    Whitespace,
    @"\n",

    @"/",
    @".",
};

test {
    std.debug.print("CharacterClass Max: {}\n", .{ comptime root.totalItems(CharacterClass) });
}

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

    .{ .pattern = .{ .basic = '0' }, .result = .@"0" },
    .{ .pattern = .{ .basic = '1' }, .result = .@"1" },
    .{ .pattern = .{ .basic = '2' }, .result = .@"2" },
    .{ .pattern = .{ .basic = '3' }, .result = .@"3" },
    .{ .pattern = .{ .basic = '4' }, .result = .@"4" },
    .{ .pattern = .{ .basic = '5' }, .result = .@"5" },
    .{ .pattern = .{ .basic = '6' }, .result = .@"6" },
    .{ .pattern = .{ .basic = '7' }, .result = .@"7" },
    .{ .pattern = .{ .basic = '8' }, .result = .@"8" },
    .{ .pattern = .{ .basic = '9' }, .result = .@"9" },

    .{ .pattern = .{ .basic = 'a' }, .result = .a },
    .{ .pattern = .{ .basic = 'b' }, .result = .b },
    .{ .pattern = .{ .basic = 'c' }, .result = .c },
    .{ .pattern = .{ .basic = 'd' }, .result = .d },
    .{ .pattern = .{ .basic = 'e' }, .result = .e },
    .{ .pattern = .{ .basic = 'f' }, .result = .f },
    .{ .pattern = .{ .basic = 'g' }, .result = .g },
    .{ .pattern = .{ .basic = 'h' }, .result = .h },
    .{ .pattern = .{ .basic = 'i' }, .result = .i },
    .{ .pattern = .{ .basic = 'j' }, .result = .j },
    .{ .pattern = .{ .basic = 'k' }, .result = .k },
    .{ .pattern = .{ .basic = 'l' }, .result = .l },
    .{ .pattern = .{ .basic = 'm' }, .result = .m },
    .{ .pattern = .{ .basic = 'n' }, .result = .n },
    .{ .pattern = .{ .basic = 'o' }, .result = .o },
    .{ .pattern = .{ .basic = 'p' }, .result = .p },
    .{ .pattern = .{ .basic = 'q' }, .result = .q },
    .{ .pattern = .{ .basic = 'r' }, .result = .r },
    .{ .pattern = .{ .basic = 's' }, .result = .s },
    .{ .pattern = .{ .basic = 't' }, .result = .t },
    .{ .pattern = .{ .basic = 'u' }, .result = .u },
    .{ .pattern = .{ .basic = 'v' }, .result = .v },
    .{ .pattern = .{ .basic = 'w' }, .result = .w },
    .{ .pattern = .{ .basic = 'x' }, .result = .x },
    .{ .pattern = .{ .basic = 'y' }, .result = .y },
    .{ .pattern = .{ .basic = 'z' }, .result = .z },

    .{ .pattern = .{ .basic = 'A' }, .result = .A },
    .{ .pattern = .{ .basic = 'B' }, .result = .B },
    .{ .pattern = .{ .basic = 'C' }, .result = .C },
    .{ .pattern = .{ .basic = 'D' }, .result = .D },
    .{ .pattern = .{ .basic = 'E' }, .result = .E },
    .{ .pattern = .{ .basic = 'F' }, .result = .F },
    .{ .pattern = .{ .basic = 'G' }, .result = .G },
    .{ .pattern = .{ .basic = 'H' }, .result = .H },
    .{ .pattern = .{ .basic = 'I' }, .result = .I },
    .{ .pattern = .{ .basic = 'J' }, .result = .J },
    .{ .pattern = .{ .basic = 'K' }, .result = .K },
    .{ .pattern = .{ .basic = 'L' }, .result = .L },
    .{ .pattern = .{ .basic = 'M' }, .result = .M },
    .{ .pattern = .{ .basic = 'N' }, .result = .N },
    .{ .pattern = .{ .basic = 'O' }, .result = .O },
    .{ .pattern = .{ .basic = 'P' }, .result = .P },
    .{ .pattern = .{ .basic = 'Q' }, .result = .Q },
    .{ .pattern = .{ .basic = 'R' }, .result = .R },
    .{ .pattern = .{ .basic = 'S' }, .result = .S },
    .{ .pattern = .{ .basic = 'T' }, .result = .T },
    .{ .pattern = .{ .basic = 'U' }, .result = .U },
    .{ .pattern = .{ .basic = 'V' }, .result = .V },
    .{ .pattern = .{ .basic = 'W' }, .result = .W },
    .{ .pattern = .{ .basic = 'X' }, .result = .X },
    .{ .pattern = .{ .basic = 'Y' }, .result = .Y },
    .{ .pattern = .{ .basic = 'Z' }, .result = .Z },
    .{ .pattern = .{ .basic = '_' }, .result = .@"_" },

    .{ .pattern = .{ .basic = 'b' }, .result = .B },
    .{ .pattern = .{ .basic = 'x' }, .result = .X },
    .{ .pattern = .{ .basic = 'o' }, .result = .O },

    .{ .pattern = .{ .basic = ' ' }, .result = .Whitespace },
    .{ .pattern = .{ .range = .{ .start = '\t', .end = '\r' } }, .result = .Whitespace },
    .{ .pattern = .{ .basic = '\n' }, .result = .@"\n" }, // Overwrite
    
    .{ .pattern = .{ .basic = '/' }, .result = .@"/" },
    .{ .pattern = .{ .basic = '.' }, .result = .@"." },
});

const CharacterClassToState = StaticIntegralMap(CharacterClass, State);
const transition_map = StaticIntegralMap(State, CharacterClassToState).init(.empty, &.{

    .{ .pattern = .{ .basic = .Start }, .result = CharacterClassToState.init(.Illegal, &.{
        .{ .pattern = .{ .basic = .Eof       }, .result = .Eof       },
        .{ .pattern = .{ .basic = .Character }, .result = .Character },

        // Transition back to start to skip a character, not counting it towards the token
        .{ .pattern = .{ .basic = .Whitespace }, .result = .Start },
        .{ .pattern = .{ .basic = .@"\n"      }, .result = .Start },

        .{ .pattern = .{ .range = CharacterClass.letter_range }, .result = .InIdentifier },
        .{ .pattern = .{ .range = .{ .start = .@"1", .end = .@"9" } }, .result = .InNumber },
        .{ .pattern = .{ .basic = .@"0" }, .result = .FoundZero },

        .{ .pattern = .{ .basic = .@"/" }, .result = .FoundForwardSlash },
    }) },

    .{ .pattern = .{ .basic = .FoundForwardSlash }, .result = CharacterClassToState.init(.EndForwardSlash, &.{
        .{ .pattern = .{ .basic = .@"/" }, .result = .InLineComment },
    }) },

    .{ .pattern = .{ .basic = .InLineComment }, .result = CharacterClassToState.init(.InLineComment, &.{
        .{ .pattern = .{ .basic = .@"\n" }, .result = .EndLineComment },
    }) },

    .{ .pattern = .{ .basic = .InIdentifier }, .result = CharacterClassToState.init(.EndIdentifier, &.{
        .{ .pattern = .{ .range = CharacterClass.letter_range }, .result = .InIdentifier },
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InIdentifier },
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InIdentifier },
    }) },

    .{ .pattern = .{ .basic = .FoundZero }, .result = CharacterClassToState.init(.EndInteger, &.{
        .{ .pattern = .{ .range = CharacterClass.digit_range }, .result = .InNumber },
        .{ .pattern = .{ .basic = .@"." }, .result = .InFloat },
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
        .{ .pattern = .{ .basic = .@"." }, .result = .InFloat },
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

const final_states_map = StaticIntegralMap(State, ?TokenKind).init(null, &.{
    .{ .pattern = .{ .basic =  .Eof            }, .result = .eof     },
    .{ .pattern = .{ .basic =  .Illegal        }, .result = .illegal },

    .{ .pattern = .{ .basic =  .EndIdentifier  }, .result = .identifier },
    .{ .pattern = .{ .basic =  .EndInteger     }, .result = .integer    },
    .{ .pattern = .{ .basic =  .EndHex         }, .result = .integer    },
    .{ .pattern = .{ .basic =  .EndBinary      }, .result = .integer    },
    .{ .pattern = .{ .basic =  .EndOctal       }, .result = .integer    },
    .{ .pattern = .{ .basic =  .EndFloat       }, .result = .float      },

    .{ .pattern = .{ .basic =  .EndLineComment }, .result = .comment   },
    .{ .pattern = .{ .basic =  .Character      }, .result = .character },
});
