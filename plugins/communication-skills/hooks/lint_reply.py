#!/usr/bin/env python3
# Stop hook: lint the assistant's final reply for AI-writing patterns.
# Blocks the stop once (exit 2) on a hit so the model re-judges and rewrites.
import io
import json
import re
import sys

BANNED_WORDS = [
    "load-bearing", "vacuous", "vacuously", "non-vacuous", "shape", "shapes",
    "owe", "owes", "owed", "slot", "slots", "channel", "channels",
    "deleak", "de-risk", "derisk",
]
BANNED_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(w) for w in BANNED_WORDS) + r")\b", re.IGNORECASE
)

EMDASH_RE = re.compile(r"[ \t]—|—[ \t]")

DETERMINERS = ["the", "a", "an", "this", "that", "each", "every", "its", "our", "my", "your"]
NOUNS = [
    "report", "entry", "row", "project", "version", "build", "PR", "issue", "doc", "docs",
    "document", "file", "list", "table", "spec", "plugin", "skill", "page", "section",
    "README", "commit", "branch", "repo", "repository", "test", "suite", "diff", "patch",
    "draft", "message", "comment", "post", "note", "memo", "roadmap", "backlog", "item",
    "codebase", "config", "flag", "option", "property", "setting",
]
# -s form and past-tense/irregular form of each governing verb
VERBS = [
    "says", "said", "tells", "told", "wants", "wanted", "knows", "knew",
    "decides", "decided", "carries", "carried", "holds", "held", "offers", "offered",
    "names", "named", "shares", "shared", "joins", "joined", "withholds", "withheld",
    "produces", "produced", "claims", "claimed", "asks", "asked", "expects", "expected",
    "promises", "promised", "cares", "cared", "configures", "configured", "sets", "set",
    "enables", "enabled", "believes", "believed", "thinks", "thought", "sees", "saw",
    "notices", "noticed",
]
BIGRAM_RE = re.compile(
    r"\b(?:" + "|".join(DETERMINERS) + r")\s+(?:"
    + "|".join(re.escape(n) for n in NOUNS) + r")\s+(?:\w+\s+)?(?:"
    + "|".join(VERBS) + r")\b",
    re.IGNORECASE,
)

GROUPS = [
    ("banned word", BANNED_RE),
    ("spaced em dash", EMDASH_RE),
    ("inanimate agency", BIGRAM_RE),
]


def strip_code(text):
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"~~~.*?~~~", "", text, flags=re.DOTALL)
    text = re.sub(r"`[^`]*`", "", text)
    return text


def excerpt(text, start, end, width=60):
    pad = max((width - (end - start)) // 2, 0)
    return text[max(0, start - pad):min(len(text), end + pad)].strip()


def lint(text):
    """Pure: text in, list of (group, matched_text, excerpt) out."""
    stripped = strip_code(text)
    hits = []
    for name, pattern in GROUPS:
        for m in pattern.finditer(stripped):
            hits.append((name, m.group(0), excerpt(stripped, m.start(), m.end())))
    return hits


def evaluate(data):
    if data.get("stop_hook_active"):  # loop guard: never bounce twice in one turn
        return []
    text = data.get("last_assistant_message")
    if not text:
        return []
    return lint(text)


def format_message(hits):
    lines = ["A pre-send lint flagged possible AI-writing patterns in the reply.", ""]
    for group, matched, exc in hits:
        lines.append('%s: "%s" - %s' % (group, matched, exc))
    lines.append("")
    lines.append(
        "Each hit is a flag for judgment, not a verdict. Judge it against the "
        "matching rule in the communication rules loaded at session start. A "
        "literal sense (a Slack channel, an array shape, a timetable slot, "
        "quoted text) stays as written. Rewrite only real violations, leave "
        "the rest of the reply unchanged, and send the corrected reply."
    )
    return "\n".join(lines) + "\n"


def run(stdin_text, err=sys.stderr):
    try:
        hits = evaluate(json.loads(stdin_text))
        if not hits:
            return 0
        err.write(format_message(hits))
        return 2
    except Exception:
        return 0  # unparseable/missing input or any internal error: never block


def main():
    sys.exit(run(sys.stdin.read()))


def self_test():
    cases = 0

    hits = lint("The build script says the tests pass.")  # personification, intervening word
    assert any(h[0] == "inanimate agency" for h in hits)
    cases += 1

    hits = lint("The report says everything is fine.")  # personification, no intervening word
    assert any(h[0] == "inanimate agency" for h in hits)
    cases += 1

    hits = lint("This fix is not vacuous at all.")  # banned word
    assert any(h[0] == "banned word" and h[1].lower() == "vacuous" for h in hits)
    cases += 1

    hits = lint("This is one thing — and another thing.")  # spaced em dash
    assert any(h[0] == "spaced em dash" for h in hits)
    cases += 1

    text = "Here is code:\n```\nshape = (1, 2)\n```\nAnd inline `shape` too."  # code-fenced, no hit
    assert lint(text) == []
    cases += 1

    code = run(json.dumps({  # stop_hook_active suppresses everything
        "stop_hook_active": True, "last_assistant_message": "vacuous shape — x"
    }))
    assert code == 0
    cases += 1

    hits = lint(  # ordinary engineering prose, no hit
        "The function returns early when the input list is empty, which keeps the loop simple."
    )
    assert hits == []
    cases += 1

    hits = lint("This is correct—no space here, nothing else flagged.")  # unspaced em dash
    assert hits == []
    cases += 1

    code = run("not json at all {{{")  # garbage stdin
    assert code == 0
    cases += 1

    buf = io.StringIO()  # end-to-end: a real hit exits 2 and writes the message
    code = run(json.dumps({"last_assistant_message": "This shape is vacuous."}), err=buf)
    assert code == 2 and "banned word" in buf.getvalue()
    cases += 1

    print("PASS (%d cases)" % cases)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        try:
            main()
        except SystemExit:
            raise
        except Exception:
            sys.exit(0)
