#!/usr/bin/python
# Generate almost all possible combination for instructions from instruction
# tables

argspecTbl = {
    'A': "A",
    'B': "B",
    'C': "C",
    'D': "D",
    'E': "E",
    'H': "H",
    'L': "L",
    'h': "HL",
    'l': "(HL)",
    'd': "DE",
    'e': "(DE)",
    'b': "BC",
    'c': "(BC)",
    'a': "AF",
    'f': "AF'",
    'x': "(IX)",
    'y': "(IY)",
    's': "SP",
    'p': "(SP)",
    'Z': "Z",
    'z': "NZ",
    '=': "NC",
    '+': "P",
    '-': "M",
    '1': "PO",
    '2': "PE",
}

argGrpTbl = {
    chr(0x01): "bdha",
    chr(0x02): "ZzC=",
    chr(0x03): "bdhs",
    chr(0x0a): "ZzC=+-12",
    chr(0x0b): "BCDEHLA",
}

instrTBlPrimary = [
    ("ADC", 'A', 'l', 0, 0x8e),
    ("ADC", 'A', 0xb, 0, 0b10001000),
    ("ADC", 'A', 'n', 0, 0xce	),
    ("ADD", 'A', 'l', 0, 0x86	),
    ("ADD", 'A', 0xb, 0, 0b10000000),
    ("ADD", 'A', 'n', 0, 0xc6 ),
    ("ADD", 'h', 0x3, 4, 0b00001001 ),
    ("AND", 'l', 0,   0, 0xa6	),
    ("AND", 0xb, 0,   0, 0b10100000),
    ("AND", 'n', 0,   0, 0xe6	),
    ("CALL",   0xa, 'N', 3, 0b11000100),
    ("CALL",   'N', 0,   0, 0xcd	),
    ("CCF", 0,   0,   0, 0x3f	),
    ("CP", 'l', 0,   0, 0xbe	),
    ("CP", 0xb, 0,   0, 0b10111000),
    ("CP", 'n', 0,   0, 0xfe	),
    ("CPL", 0,   0,   0, 0x2f	),
    ("DAA", 0,   0,   0, 0x27	),
    ("DI", 0,   0,   0, 0xf3	),
    ("DEC", 'l', 0,   0, 0x35	),
    ("DEC", 0xb, 0,   3, 0b00000101),
    ("DEC", 0x3, 0,   4, 0b00001011),
    ("DJNZ",   'n', 0,0x80, 0x10	),
    ("EI", 0,   0,   0, 0xfb	),
    ("EX", 'p', 'h', 0, 0xe3	),
    ("EX", 'a', 'f', 0, 0x08	),
    ("EX", 'd', 'h', 0, 0xeb	),
    ("EXX", 0,   0,   0, 0xd9	),
    ("HALT",   0,   0,   0, 0x76	),
    ("IN", 'A', 'm', 0, 0xdb	),
    ("INC", 'l', 0,   0, 0x34	),
    ("INC", 0xb, 0,   3, 0b00000100),
    ("INC", 0x3, 0,   4, 0b00000011),
    ("JP", 'l', 0,   0, 0xe9	),
    ("JP", 'N', 0,   0, 0xc3	),
    ("JR", 'n', 0,0x80, 0x18	),
    ("JR",'C','n',0x80, 0x38	),
    ("JR",'=','n',0x80, 0x30	),
    ("JR",'Z','n',0x80, 0x28	),
    ("JR",'z','n',0x80, 0x20	),
    ("LD", 'c', 'A', 0, 0x02	),
    ("LD", 'e', 'A', 0, 0x12	),
    ("LD", 'A', 'c', 0, 0x0a	),
    ("LD", 'A', 'e', 0, 0x0a	),
    ("LD", 's', 'h', 0, 0x0a	),
    ("LD", 'l', 0xb, 0, 0b01110000),
    ("LD", 0xb, 'l', 3, 0b01000110),
    ("LD", 'l', 'n', 0, 0x36	),
    ("LD", 0xb, 'n', 3, 0b00000110),
    ("LD", 0x3, 'N', 4, 0b00000001),
    ("LD", 'M', 'A', 0, 0x32	),
    ("LD", 'A', 'M', 0, 0x3a	),
    ("LD", 'M', 'h', 0, 0x22	),
    ("LD", 'h', 'M', 0, 0x2a	),
    ("NOP", 0,   0,   0, 0x00	),
    ("OR", 'l', 0,   0, 0xb6	),
    ("OR", 0xb, 0,   0, 0b10110000),
    ("OUT", 'm', 'A', 0, 0xd3	),
    ("POP", 0x1, 0,   4, 0b11000001),
    ("PUSH",   0x1, 0,   4, 0b11000101),
    ("RET", 0xa, 0,   3, 0b11000000),
    ("RET", 0,   0,   0, 0xc9	),
    ("RLA", 0,   0,   0, 0x17	),
    ("RLCA",   0,   0,   0, 0x07	),
    ("RRA", 0,   0,   0, 0x1f	),
    ("RRCA",   0,   0,   0, 0x0f	),
    ("SBC", 'A', 'l', 0, 0x9e	),
    ("SBC", 'A', 0xb, 0, 0b10011000),
    ("SCF", 0,   0,   0, 0x37	),
    ("SUB", 'A', 'l', 0, 0x96	),
    ("SUB", 'A', 0xb, 0, 0b10010000),
    ("SUB", 'n', 0,   0, 0xd6 ),
    ("XOR", 'l', 0,   0, 0xae	),
    ("XOR", 0xb, 0,   0, 0b10101000),
]

def genargs(argspec):
    if not argspec:
        return ''
    if not isinstance(argspec, str):
        argspec = chr(argspec)
    if argspec in 'nmNM':
        bits = 16 if argspec in 'NM' else 8
        nbs = [str(1 << i) for i in range(bits)]
        if argspec in 'mM':
            nbs = [f"({n})" for n in nbs]
        return nbs
    if argspec in argspecTbl:
        return [argspecTbl[argspec]]
    grp = argGrpTbl[argspec]
    return [argspecTbl[a] for a in grp]


def main():
    for n, a1, a2, f, op in instrTBlPrimary:
        args1 = genargs(a1)
        if args1:
            for arg1 in args1:
                args2 = genargs(a2)
                if args2:
                    for arg2 in args2:
                        print(f"{n} {arg1}, {arg2}")
                else:
                    print(f"{n} {arg1}")
        else:
            print(n)
    pass

if __name__ == '__main__':
    main()
