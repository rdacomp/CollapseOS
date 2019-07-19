#!/usr/bin/env python3
# Generate almost all possible combination for instructions from instruction
# tables

import sys

# Those lines below are improperly assembled by scas and are skipped by tests.
BLACKLIST = {
    "AND (IX)",
    "AND (IY)",
}

argspecTbl = {
    'A': "A",
    'B': "B",
    'C': "C",
    'k': "(C)",
    'D': "D",
    'E': "E",
    'H': "H",
    'L': "L",
    'I': "I",
    'R': "R",
    'h': "HL",
    'l': "(HL)",
    'd': "DE",
    'e': "(DE)",
    'b': "BC",
    'c': "(BC)",
    'a': "AF",
    'f': "AF'",
    'X': "IX",
    'x': "(IX)",
    'Y': "IY",
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
    chr(0x04): "bdXs",
    chr(0x05): "bdYs",
    chr(0x0a): "ZzC=+-12",
    chr(0x0b): "BCDEHLA",
}

def cleanupLine(line):
    line = line.strip()
    idx = line.rfind(';')
    if idx >= 0:
        line = line[:idx]
    return line

def getDbLines(fp, tblname):
    lookingFor = f"{tblname}:"
    line = fp.readline()
    while line:
        line = cleanupLine(line)
        if line == lookingFor:
            break
        line = fp.readline()
    else:
        raise Exception(f"{tblname} not found")

    result = []
    line = fp.readline()
    while line:
        line = cleanupLine(line)
        if line:
            if not line.startswith('.db'):
                break
            result.append([s.strip() for s in line[4:].split(',')])
        line = fp.readline()
    return result

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
    if argspec in 'xy':
        # IX/IY displacement is special
        base = argspecTbl[argspec]
        result = [base]
        argspec = argspec.upper()
        for n in [1, 10, 100, 127]:
            result.append(f"(I{argspec}+{n})")
        # TODO: support minus
        return result
    if argspec in argspecTbl:
        return [argspecTbl[argspec]]
    grp = argGrpTbl[argspec]
    return [argspecTbl[a] for a in grp]

def p(line):
    if line not in BLACKLIST:
        print(line)


def main():
    asmfile = sys.argv[1]
    with open(asmfile, 'rt') as fp:
        instrTbl = getDbLines(fp, 'instrTBl')
    for row in instrTbl:
        n = row[0][2:] # remove I_
        # we need to adjust for zero-char name filling
        a1 = eval(row[1])
        a2 = eval(row[2])
        args1 = genargs(a1)
        # special case handling
        if n == 'JP' and isinstance(a1, str) and a1 in 'xy':
            # we don't test the displacements for IX/IY because there can't be
            # any.
            args1 = args1[:1]
        if n in {'BIT', 'SET', 'RES'}:
            # we only want to keep 1, 2, 4
            args1 = args1[:3]
        if n == 'IM':
            args1 = [0, 1, 2]
        if args1:
            for arg1 in args1:
                args2 = genargs(a2)
                if args2:
                    for arg2 in args2:
                        p(f"{n} {arg1}, {arg2}")
                else:
                    p(f"{n} {arg1}")
        else:
            p(n)
    pass

if __name__ == '__main__':
    main()
