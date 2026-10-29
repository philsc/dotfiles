#!/usr/bin/env python3
"""Reflows a PR's body to 72 columns after Claude runs `gh pr create/edit`.

GitHub's squash-merge dialog hard-wraps the PR body at 72 columns when it
proposes the commit message. It only splits long lines, so a 73-char line
leaves a one-word orphan in the middle of a paragraph, and unwrapped list
items lose their continuation indent. Wrapping the body ourselves, with a
markdown-aware formatter, gives GitHub nothing to rewrap.

Runs as a Claude Code PostToolUse hook on Bash (see ~/.claude/settings.json):
it reads the hook's JSON on stdin, finds the PR URL that `gh pr create` or
`gh pr edit` printed, formats the body with prettier and pushes it back with
`gh pr edit --body-file -` if anything changed.

The trailers at the end (e.g. `Assisted-By: Claude`) are kept verbatim, since
prettier would join a multi-line trailer block into one line. What counts as
trailers is up to `git interpret-trailers`, which applies the rule git uses
when it makes the squash commit.

Debugging:

    python3 reflow_pr_body.py --stdin-body < body.md

prints the reflowed body without touching GitHub.

Notes:
- Prettier normalizes `*` bullets to `-` and `*em*` to `_em_`. Harmless.
- The hook's own `gh pr edit` doesn't trigger the hook again; hooks only fire
  on Claude's tool calls.
- The hook never fails the tool call: errors go to stderr and it exits 0.
"""

import json
import re
import shutil
import subprocess
import sys
import traceback

WIDTH = 72
PRETTIER = "prettier@3.6.2"
GH_PR_RE = re.compile(r"\bgh\s+pr\s+(create|edit)\b")
PR_URL_RE = re.compile(r"https://github\.com/[^/\s]+/[^/\s]+/pull/\d+")


def split_trailers(body: str) -> tuple[str, str]:
    """Splits `body` into the text before its trailers and the trailers.

    The trailers are the last paragraph, when git sees trailers in it. A body
    of a single paragraph has no trailers, nor does a paragraph with a line
    over WIDTH: real trailers are short, and a long `Note: ...` line is prose
    that git happens to parse as a trailer.
    """
    body = body.rstrip()
    head, sep, last = body.rpartition("\n\n")
    if not sep or not head.strip():
        return body, ""
    if any(len(line) > WIDTH for line in last.splitlines()):
        return body, ""
    parsed = subprocess.run(
        ["git", "interpret-trailers", "--parse"],
        input=body,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if not parsed.strip():
        return body, ""
    return head, last.strip("\n")


def prettier(text: str) -> str:
    npx = shutil.which("npx")
    if not npx:
        raise RuntimeError("npx isn't on PATH")
    return subprocess.run(
        [
            npx,
            "--yes",
            PRETTIER,
            "--no-config",
            "--no-editorconfig",
            "--parser=markdown",
            "--prose-wrap=always",
            f"--print-width={WIDTH}",
        ],
        input=text,
        capture_output=True,
        text=True,
        check=True,
    ).stdout


def reflow(body: str) -> str:
    """Returns `body` wrapped at WIDTH columns, trailers left as they are.

    A body whose lines all fit already comes back as it is, apart from line
    endings, so the hook leaves Claude's own wrapping alone.
    """
    body = body.replace("\r\n", "\n")
    if all(len(line) <= WIDTH for line in body.splitlines()):
        return body.rstrip()
    text, trailers = split_trailers(body)
    out = prettier(text).rstrip() if text.strip() else ""
    if trailers:
        out = f"{out}\n\n{trailers}" if out else trailers
    return out


def gh(*args: str, input: str | None = None) -> str:
    return subprocess.run(
        ["gh", *args], input=input, capture_output=True, text=True, check=True
    ).stdout


def handle_hook(event: dict) -> None:
    command = (event.get("tool_input") or {}).get("command") or ""
    if not GH_PR_RE.search(command):
        return
    response = event.get("tool_response") or {}
    stdout = response.get("stdout") if isinstance(response, dict) else str(response)
    urls = PR_URL_RE.findall(stdout or "")
    if not urls:
        return
    url = urls[-1]
    body = gh("pr", "view", url, "--json", "body", "-q", ".body")
    if not body.strip():
        return
    new = reflow(body)
    if new == body.replace("\r\n", "\n").rstrip():
        return
    gh("pr", "edit", url, "--body-file", "-", input=new + "\n")
    print(json.dumps({"systemMessage": f"Reflowed the body of {url} to {WIDTH} columns"}))


def main() -> int:
    if sys.argv[1:] == ["--stdin-body"]:
        sys.stdout.write(reflow(sys.stdin.read()) + "\n")
        return 0
    try:
        handle_hook(json.load(sys.stdin))
    except subprocess.CalledProcessError as e:
        print(f"reflow_pr_body: {e}\n{e.stderr}", file=sys.stderr)
    except Exception:
        traceback.print_exc()
    return 0


if __name__ == "__main__":
    sys.exit(main())
