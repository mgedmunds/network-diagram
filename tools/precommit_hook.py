#!/usr/bin/env python3
"""PreToolUse hook glue for Claude Code.

Reads the hook JSON on stdin. If the Bash command being run is a git commit,
it runs the app.R static check (tools/check_app.py). If the check fails, it
emits a PreToolUse "deny" decision so the commit is blocked before it happens;
otherwise it stays silent and the commit proceeds.

Wired in .claude/settings.local.json as a PreToolUse hook on the Bash matcher.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_app import check


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0  # can't parse input — don't block

    command = data.get("tool_input", {}).get("command", "")
    if "git commit" not in command:
        return 0

    app_path = os.path.join(os.getcwd(), "app.R")
    if not os.path.exists(app_path):
        return 0  # no app.R here — nothing to check

    problem = check(app_path)
    if problem:
        deny(f"Commit blocked by app.R static check — {problem} "
             f"Fix app.R (run `python3 tools/check_app.py` to re-check), then commit again.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
