const std = @import("std");
const root = @import("root.zig");
const StaticIntegralMap = root.StaticIntegralMap;

fn ClassifiedCharacter(comptime SpecialClass: type) type {
    const SpecialOrLiteral = enum(u1) { special, literal };
    return packed struct {
        data: packed union {
            special: SpecialClass,
            literal: u8,
        },
        tag: SpecialOrLiteral,

        pub inline fn special(kind: SpecialClass) @This() {
            return .{ .tag = .special, .data = .{ .special = kind } };
        }

        pub inline fn literal(kind: u8) @This() {
            return .{ .tag = .literal, .data = .{ .literal = kind } };
        }
    };
}

const SpecialCharacterKind = enum(u8) {
    Unknown,
    Eof,

    Whitespace,
    Letter,
    Digit,
};
const CharacterKind = ClassifiedCharacter(SpecialCharacterKind);

const SpecialState = enum(u8) {
    Illegal,
    Start,
    Eof,

    InIdentifier,
    EndIdentifier,

    InInteger,
    EndInteger,
};
const State = ClassifiedCharacter(SpecialState);

test {
    try std.testing.expectEqual(@bitSizeOf(CharacterKind), 9);
    try std.testing.expectEqual(@bitSizeOf(State), 9);
}

const SpecialTokenKind = enum(u8) {
    Illegal,
    Identifier,
    Integer,

    KeywordPub,
    KeywordFn,

    TypeVoid,
    TypeI32,
};
const TokenKind = ClassifiedCharacter(SpecialTokenKind);

const character_map = StaticIntegralMap(u8, CharacterKind).init(CharacterKind.special(.Unknown), &.{
    .{ .pattern = .{ .basic =  0  }, .result = CharacterKind.special(.Eof) },

    .{ .pattern = .{ .range = .{ .start = '0', .end = '9' } }, .result = CharacterKind.special(.Digit) },
    .{ .pattern = .{ .range = .{ .start = 'a', .end = 'z' } }, .result = CharacterKind.special(.Letter) },
    .{ .pattern = .{ .range = .{ .start = 'A', .end = 'Z' } }, .result = CharacterKind.special(.Letter) },
    .{ .pattern = .{ .basic = '_' }, .result = CharacterKind.special(.Letter) },

    .{ .pattern = .{ .basic = ' ' }, .result = CharacterKind.special(.Whitespace) },
    .{ .pattern = .{ .range = .{ .start = '\t', .end = '\r' } }, .result = CharacterKind.special(.Whitespace) },

    .{ .pattern = .{ .basic = '(' }, .result = CharacterKind.literal('(') },
    .{ .pattern = .{ .basic = ')' }, .result = CharacterKind.literal(')') },

    .{ .pattern = .{ .basic = '{' }, .result = CharacterKind.literal('{') },
    .{ .pattern = .{ .basic = '}' }, .result = CharacterKind.literal('}') },

    .{ .pattern = .{ .basic = ';' }, .result = CharacterKind.literal(';') },
    .{ .pattern = .{ .basic = ':' }, .result = CharacterKind.literal(':') },
    .{ .pattern = .{ .basic = ',' }, .result = CharacterKind.literal(',') },

    .{ .pattern = .{ .basic = '+' }, .result = CharacterKind.literal('+') },
});

const CharToState = StaticIntegralMap(CharacterKind, State);
const transition_map = StaticIntegralMap(State, CharToState).init(CharToState.init(State.special(.Illegal), &.{}), &.{

    .{ .pattern = .{ .basic = State.special(.Start) }, .result = CharToState.init(State.special(.Illegal), &.{
        .{ .pattern = .{ .basic = CharacterKind.special(.Eof)    }, .result = State.special(.Eof) },
        .{ .pattern = .{ .basic = CharacterKind.special(.Letter) }, .result = State.special(.InIdentifier) },
        .{ .pattern = .{ .basic = CharacterKind.special(.Digit)  }, .result = State.special(.InInteger) },

        .{ .pattern = .{ .basic = CharacterKind.literal('(') }, .result = State.literal('(') },
        .{ .pattern = .{ .basic = CharacterKind.literal(')') }, .result = State.literal(')') },

        .{ .pattern = .{ .basic = CharacterKind.literal('{') }, .result = State.literal('{') },
        .{ .pattern = .{ .basic = CharacterKind.literal('}') }, .result = State.literal('}') },

        .{ .pattern = .{ .basic = CharacterKind.literal(',') }, .result = State.literal(',') },
        .{ .pattern = .{ .basic = CharacterKind.literal(';') }, .result = State.literal(';') },
        .{ .pattern = .{ .basic = CharacterKind.literal(':') }, .result = State.literal(':') },

        .{ .pattern = .{ .basic = CharacterKind.literal('+') }, .result = State.literal('+') },
    }) },

    .{ .pattern = .{ .basic = State.special(.InIdentifier) }, .result = CharToState.init(State.special(.EndIdentifier), &.{
        .{ .pattern = .{ .basic = CharacterKind.special(.Letter) }, .result = State.special(.InIdentifier) },
        .{ .pattern = .{ .basic = CharacterKind.special(.Digit)  }, .result = State.special(.InIdentifier) },
    }) },

    .{ .pattern = .{ .basic = State.special(.InInteger) }, .result = CharToState.init(State.special(.EndInteger), &.{
        .{ .pattern = .{ .basic = CharacterKind.special(.Digit)  }, .result = State.special(.InInteger) },
    }) },

});

const state_widths_map = StaticIntegralMap(State, u1).init(1, &.{
    .{ .pattern = .{ .basic =  State.special(.Eof)           }, .result = 0 },
    .{ .pattern = .{ .basic =  State.special(.EndIdentifier) }, .result = 0 },
});

const final_states_map = StaticIntegralMap(State, bool).init(false, &.{
    .{ .pattern = .{ .basic =  State.special(.Eof)           }, .result = true },
    .{ .pattern = .{ .basic =  State.special(.Illegal)       }, .result = true },
    .{ .pattern = .{ .basic =  State.special(.EndIdentifier) }, .result = true },
    .{ .pattern = .{ .basic =  State.special(.EndInteger)    }, .result = true },

    .{ .pattern = .{ .basic =  State.literal('(') }, .result = true },
    .{ .pattern = .{ .basic =  State.literal(')') }, .result = true },

    .{ .pattern = .{ .basic =  State.literal('{') }, .result = true },
    .{ .pattern = .{ .basic =  State.literal('}') }, .result = true },

    .{ .pattern = .{ .basic =  State.literal(';') }, .result = true },
    .{ .pattern = .{ .basic =  State.literal(':') }, .result = true },
    .{ .pattern = .{ .basic =  State.literal(',') }, .result = true },

    .{ .pattern = .{ .basic =  State.literal('+') }, .result = true },
});

const keywords_map = std.StaticStringMap(TokenKind).initComptime(&.{
    .{ "pub",  TokenKind.special(.KeywordPub) },
    .{ "fn",   TokenKind.special(.KeywordFn)  },

    .{ "void", TokenKind.special(.TypeVoid) },
    .{ "i32",  TokenKind.special(.TypeI32)  },
});

const Tokenizer = struct {
    const Self = @This();

    source: [:0]const u8,
    offset: usize,

    pub fn init(source: [:0]const u8) Self {
        return .{ .source = source, .offset = 0 };
    }

    pub fn next(self: *Self) ?struct { []const u8, TokenKind } {
        if (self.offset >= self.source.len) return null;

        var state = State.special(.Start);
        var token_length: usize = 0;

        while (std.ascii.isWhitespace(self.source[self.offset])): (self.offset += 1) { }

        while (!final_states_map.get(state)) {
            const c = self.source[self.offset + token_length];
            const character_kind = character_map.get(c);
            state = transition_map.get(state).get(character_kind);
            token_length += state_widths_map.get(state);
        }

        const token = self.source[self.offset..(self.offset + token_length)];
        self.offset += token_length;

        const kind = if (state.tag == .special) switch (state.data.special) {
            .Illegal       => TokenKind.special(.Illegal),
            .EndIdentifier => keywords_map.get(token) orelse TokenKind.special(.Identifier),
            .EndInteger    => TokenKind.special(.Integer),
            else => unreachable,
        } else
            TokenKind.literal(token[0]);

        return .{ token, kind };
    }
};

pub fn main() !void {
    const source = 
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;

    var iter = Tokenizer.init(source);
    while (iter.next()) |p| {
        const token, const kind = p;
        switch (kind.tag) {
            .special => std.debug.print("`{s}`: {any}\n", .{ token, kind.data.special }),
            .literal => std.debug.print("`{s}`: {c}\n",   .{ token, kind.data.literal }),
        }
    }
}

