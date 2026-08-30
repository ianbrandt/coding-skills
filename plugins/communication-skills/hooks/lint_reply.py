#!/usr/bin/env python3
# House-style lint for the assistant's replies, in two halves.
#   --record  Stop hook: lint the final reply, save the hits, never block.
#   --emit    UserPromptSubmit hook: print the saved hits into the next turn, then clear them.
# Never blocking is the point: a Stop hook cannot patch a reply, so blocking one
# costs a full re-emission of an answer the reader has already seen. The
# correction lands on the next reply instead.
import io
import json
import os
import re
import sys
import tempfile
from collections import Counter, OrderedDict

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


def lint(text):
    """Pure: text in, list of (group, matched_text) out."""
    stripped = strip_code(text)
    return [
        (name, m.group(0))
        for name, pattern in GROUPS
        for m in pattern.finditer(stripped)
    ]


# Naming the pattern is not enough: a note that defers to "the rules loaded at
# session start" measured no better than no note at all. Each line carries its
# own rule so the note stands alone.
RULES = {
    "banned word": "that word is banned in prose; use a plain synonym",
    "spaced em dash": "an em dash takes no surrounding spaces: write word\u2014word, never word \u2014 word",
    "inanimate agency": "an inanimate subject must not take a verb of speech, volition, "
                        "perception, or possession; name the real actor or rewrite around the act",
}


def summarize(hits):
    """Pure: hits in, the note the next turn opens with out."""
    groups = OrderedDict()
    for group, matched in hits:
        groups.setdefault(group, Counter())[matched] += 1
    lines = ["A house-style lint flagged the previous reply:"]
    for group, counter in groups.items():
        example = counter.most_common(1)[0][0]
        lines.append('- %s x%d, e.g. "%s". Rule: %s.'
                     % (group, sum(counter.values()), example, RULES.get(group, "")))
    lines.append(
        "Apply these rules in the reply you are about to write, including in "
        "markdown headings. Do not re-send the previous reply and do not correct "
        "it; there is no need to mention this note unless the user asks about it. "
        "Leave a literal sense (a Slack channel, an array shape, a timetable "
        "slot) alone."
    )
    return "\n".join(lines) + "\n"


def state_path(data):
    key = str(data.get("session_id") or "default").replace("/", "_")
    return os.path.join(tempfile.gettempdir(), "claude-reply-lint-%s.txt" % key)


def discard(path):
    try:
        os.remove(path)
    except OSError:
        pass


def record(data):
    """Stop hook: save the hits for the next turn. Returns what was saved, or ''."""
    path = state_path(data)
    hits = lint(data.get("last_assistant_message") or "")
    if not hits:
        discard(path)  # a clean reply clears whatever the last one left
        return ""
    note = summarize(hits)
    with open(path, "w") as f:
        f.write(note)
    return note


def emit(data, out=sys.stdout):
    """UserPromptSubmit hook: print the saved note as context, then clear it."""
    path = state_path(data)
    try:
        with open(path) as f:
            note = f.read()
    except OSError:
        return ""
    discard(path)
    out.write(note)
    return note


def run(mode, stdin_text, out=sys.stdout):
    try:
        data = json.loads(stdin_text)
        emit(data, out) if mode == "--emit" else record(data)
    except Exception:
        pass  # unparseable input, an unwritable temp dir, anything: never interfere
    return 0


def self_test():
    cases = 0

    assert any(g == "inanimate agency" for g, _ in lint("The build script says the tests pass."))
    cases += 1

    assert any(g == "inanimate agency" for g, _ in lint("The report says everything is fine."))
    cases += 1

    assert any(g == "banned word" and m.lower() == "vacuous"
               for g, m in lint("This fix is not vacuous at all."))
    cases += 1

    assert any(g == "spaced em dash" for g, _ in lint("This is one thing — and another."))
    cases += 1

    assert lint("Code:\n```\nshape = (1, 2)\n```\nAnd inline `shape` too.") == []
    cases += 1

    assert lint("The function returns early when the list is empty, keeping the loop simple.") == []
    cases += 1

    assert lint("This is correct—no space here, nothing else flagged.") == []
    cases += 1

    note = summarize(lint("A — B — C, and the report says so."))  # counted, one example each
    assert "spaced em dash x2" in note and "inanimate agency x1" in note, note
    assert "never word — word" in note and "name the real actor" in note, note  # rules inline
    assert "loaded at session start" not in note, note  # never defer the rule to elsewhere
    cases += 1

    data = {"session_id": "selftest", "last_assistant_message": "This shape is vacuous."}
    assert record(data)  # record saves...
    buf = io.StringIO()
    assert "banned word" in emit(data, buf) and "banned word" in buf.getvalue()  # ...emit drains
    assert emit(data, io.StringIO()) == ""  # ...and a second read finds nothing
    cases += 1

    record(data)  # a clean reply clears a pending note
    record({"session_id": "selftest", "last_assistant_message": "Plain prose, nothing flagged."})
    assert emit(data, io.StringIO()) == ""
    cases += 1

    assert run("--record", "not json at all {{{") == 0  # garbage stdin never interferes
    assert run("--emit", "not json at all {{{") == 0
    cases += 1

    print("PASS (%d cases)" % cases)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        try:
            sys.exit(run("--emit" if "--emit" in sys.argv else "--record", sys.stdin.read()))
        except SystemExit:
            raise
        except Exception:
            sys.exit(0)
