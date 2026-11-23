#!/usr/bin/env python3
"""Static pre-commit checks for app.R.

Catches the failure modes that repeatedly cost RStudio deploy cycles, plus one
team coding-standard check:
  1. Unbalanced (), [] or {} — the paren/brace imbalance.
  2. Unterminated strings — what an unescaped apostrophe inside a
     single-quoted R string (e.g. 'It's here') actually produces.
  3. Base R pipe |>  — the team standard is the magrittr pipe %>% (tidyverse).
     Flagged in code only; mentions inside comments/strings are ignored.

This is a lightweight tokeniser, NOT a full R parser: it walks the file,
skips over comments and string contents, and only tracks bracket nesting
and string state. It cannot prove the file parses — RStudio's parse() /
runApp() remains the gold-standard check — but it reliably flags these
classes without needing R installed.

Exit 0 = clean. Exit 1 = problem found (message on stderr).
Usage: python3 tools/check_app.py [path-to-app.R]
"""

import sys

PAIRS = {")": "(", "]": "[", "}": "{"}
OPENERS = set(PAIRS.values())


def check(path):
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    stack = []          # (opener_char, line) awaiting a close
    base_pipes = []     # line numbers where a base R pipe |> appears in code
    i, line = 0, 1
    n = len(src)

    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue

        # Comment: '#' runs to end of line (we're in normal state here).
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue

        # String or backtick-quoted name: consume until the matching delimiter.
        if c in ("'", '"', "`"):
            quote = c
            start_line = line
            i += 1
            while i < n:
                d = src[i]
                if d == "\\" and quote != "`":      # backslash escape (not in backticks)
                    i += 2
                    continue
                if d == "\n":
                    line += 1
                elif d == quote:
                    i += 1
                    break
                i += 1
            else:
                return (f"Unterminated {quote}-delimited string starting at line "
                        f"{start_line}. Likely an unescaped apostrophe inside a "
                        f"single-quoted string, or a missing closing quote.")
            continue

        # Base R pipe |> in code (comments/strings already skipped above).
        if c == "|" and i + 1 < n and src[i + 1] == ">":
            base_pipes.append(line)

        # Bracket tracking.
        if c in OPENERS:
            stack.append((c, line))
        elif c in PAIRS:
            if not stack:
                return f"Unmatched closing '{c}' at line {line}."
            opener, oline = stack.pop()
            if opener != PAIRS[c]:
                return (f"Mismatched bracket at line {line}: found '{c}' but the "
                        f"nearest unclosed opener is '{opener}' from line {oline}.")

        i += 1

    if stack:
        opener, oline = stack[-1]
        return (f"Unclosed '{opener}' opened at line {oline} — "
                f"{len(stack)} bracket(s) still open at end of file.")

    if base_pipes:
        shown = ", ".join(str(l) for l in base_pipes[:10])
        more = "" if len(base_pipes) <= 10 else f" (and {len(base_pipes) - 10} more)"
        return (f"Base R pipe |> found at line(s) {shown}{more}. Team standard is "
                f"the magrittr pipe %>% — replace |> with %>%.")
    return None


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "app.R"
    try:
        problem = check(path)
    except FileNotFoundError:
        print(f"check_app.py: {path} not found", file=sys.stderr)
        return 1
    if problem:
        print(f"app.R static check FAILED: {problem}", file=sys.stderr)
        return 1
    print("app.R static check passed (brackets balanced, strings terminated, no base pipes).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
