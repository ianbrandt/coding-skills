#!/usr/bin/env python3
# House-style lint and reminders for the assistant's prose, in three parts.
#   --record  Stop hook: lint the final reply, save the hits, never block.
#   --emit    UserPromptSubmit hook: print any saved hits into the next turn,
#             then clear them, then print the standing style reminder.
#   --nudge   PostToolUse hook on Write|Edit: when the file just written is
#             prose, tell the model to re-read and fix it in place now.
# Never blocking is the point: a Stop hook cannot patch a reply, so blocking one
# costs a full re-emission of an answer the reader has already seen. The
# correction lands on the next reply instead; the reminders lower how often a
# correction is needed at all.
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

# Inanimate agency, inverted from the old design: no noun list. Any
# determiner-led subject counts unless it is animate; what is closed is the
# verb list, because speech/volition/possession/authorship is a bounded
# semantic class where nouns are not. Runtime-mechanism verbs (returns,
# resolves, flattens, matches, asserts, prints) stay off the list so a running
# program acting at runtime never flags.
VERB_FORMS = """
says said tells told wants wanted knows knew decides decided carries carried
holds held offers offered names named shares shared joins joined withholds
withheld produces produced claims claimed asks asked expects expected promises
promised cares cared configures configured enables enabled believes believed
thinks thought notices noticed concludes concluded notes noted states stated
writes wrote gives gave uses used exempts exempted keeps kept declares declared
credits credited owns owned wishes wished intends intended refuses refused
insists insisted assumes assumed remembers remembered forgets forgot adds added
sees saw finds found sets
""".split()
# Volition/speech verbs stay flagged even with a bare pronoun subject ("It
# exempts a range"). The possession/action tier (holds, keeps, adds, uses...)
# needs a real noun subject: "This keeps the diff small" with an action
# antecedent is idiomatic English, not personification.
STRICT_FORMS = set("""
says said tells told wants wanted knows knew decides decided claims claimed
asks asked expects expected promises promised believes believed thinks thought
concludes concluded notes noted states stated exempts exempted declares
declared insists insisted refuses refused assumes assumed credits credited
""".split())
PARTICIPLES = """
declaring naming telling asking offering giving stating claiming holding
keeping wanting knowing deciding promising configuring crediting owning
insisting assuming
""".split()

# Subjects that legitimately act: people, roles, and the agents/sessions that
# contain one. Checked with any possessive suffix stripped.
ANIMATE = set("""
i we you he she they user users author authors maintainer maintainers reviewer
reviewers team teams developer developers dev devs engineer engineers
contributor contributors reader readers writer writers person people agent
agents assistant model human humans folks everyone someone anybody nobody who
session sessions subagent subagents
""".split())

DET = r"(?:the|a|an|this|that|these|those|each|every|its|our|my|your|neither|either|both|no)"
VERB = r"(?:" + "|".join(VERB_FORMS) + r")"
STRICT = r"(?:" + "|".join(sorted(STRICT_FORMS)) + r")"
PART = r"(?:" + "|".join(PARTICIPLES) + r")"
BE = r"(?:is|are|was|were|be|been|being|to|not|n't|does|do|did|can|could|will|would|may|might|must|should)"
ADV = r"(?:never|also|always|still|then|only|just|already|itself)"
W = r"[\w'’-]+"
# A gap word may be neither an auxiliary/copula (kills passives: "the file is
# named") nor a determiner (kills adjectival participles: "the declared bound"
# never matches, because "declared" would need a determiner directly before it).
GAP = r"(?:(?!" + BE + r"\b|" + DET + r"\b)" + W + r"[ \t]+)"

# "the build wrote", "every non-static field in the class hierarchy holds"
SUBJECT_VERB_RE = re.compile(
    r"\b" + DET + r"[ \t]+(" + GAP + r"{1,6}?)(?:" + ADV + r"[ \t]+)?(" + VERB + r")\b",
    re.IGNORECASE)
# "declaration that wrote", "the alias, which gives"
RELATIVE_RE = re.compile(
    r"\b(" + W + r"),?[ \t]+(?:that|which)[ \t]+(?:" + ADV + r"[ \t]+)?(?!" + BE + r"\b)("
    + VERB + r")\b",
    re.IGNORECASE)
# "a libs.versions.toml declaring an alias"
PARTICIPLE_RE = re.compile(
    r"\b" + DET + r"[ \t]+(" + GAP + r"{1,4}?)(" + PART + r")\b",
    re.IGNORECASE)
# "It exempts a range" (strict verbs only); "Neither adds a constraint" (a bare
# correlative subject stands for a thing, so the full verb list counts).
PRONOUN_RE = re.compile(
    r"\b(it|this|that)[ \t]+(?:" + ADV + r"[ \t]+)?(" + STRICT + r")\b"
    r"|\b(neither|either|both|each)[ \t]+(?:" + ADV + r"[ \t]+)?(" + VERB + r")\b",
    re.IGNORECASE)

AGENCY_PATTERNS = [SUBJECT_VERB_RE, RELATIVE_RE, PARTICIPLE_RE, PRONOUN_RE]

PREPOSITIONS = {
    "in", "at", "on", "by", "above", "below", "under", "over", "within",
    "there", "here", "earlier",
}


def strip_code(text):
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"~~~.*?~~~", "", text, flags=re.DOTALL)
    # Replace inline code with a placeholder noun so the sentence keeps its
    # subject: "a `plugins` block declaration wrote" must stay matchable.
    text = re.sub(r"`[^`]*`", "CODE", text)
    return text


def _base(word):
    word = word.lower().strip(",.;:")
    for suffix in ("'s", "’s"):
        if word.endswith(suffix):
            return word[: -len(suffix)]
    return word


def _agency_hits(stripped):
    hits = []
    for pattern in AGENCY_PATTERNS:
        for m in pattern.finditer(stripped):
            groups = [g for g in m.groups() if g]
            subject_words = groups[0].split()
            verb = groups[-1].lower()
            matched = m.group(0)
            if any(_base(w) in ANIMATE for w in subject_words):
                continue
            # "a session's notes": a possessive before the "verb" makes it a noun.
            if subject_words[-1].endswith(("'s", "’s", "s'")):
                continue
            # "That said, ..." is a discourse idiom, not a talking pronoun.
            if matched.lower().startswith("that said"):
                continue
            # "the rule stated in ..." is a reduced passive, not an act: skip a
            # past form followed directly by a preposition.
            if not verb.endswith("s"):
                after = re.match(r"[ \t]+(" + W + r")", stripped[m.end():])
                if after and after.group(1).lower() in PREPOSITIONS:
                    continue
            hits.append(("inanimate agency", matched))
    return hits


def lint(text):
    """Pure: text in, list of (group, matched_text) out."""
    stripped = strip_code(text)
    hits = [
        (name, m.group(0))
        for name, pattern in (("banned word", BANNED_RE), ("spaced em dash", EMDASH_RE))
        for m in pattern.finditer(stripped)
    ]
    return hits + _agency_hits(stripped)


# Naming the pattern is not enough: a note that defers to "the rules loaded at
# session start" measured no better than no note at all. Each line carries its
# own rule so the note stands alone.
RULES = {
    "banned word": "that word is banned in prose; use a plain synonym",
    "spaced em dash": "an em dash takes no surrounding spaces: write word—word, never word — word",
    "inanimate agency": "an inanimate subject must not take a verb of speech, volition, "
                        "perception, or possession; name the real actor or rewrite around the act",
}

REMINDER = (
    "Style, for this reply and any prose written to files: an inanimate subject "
    "takes no agentive verb—\"the entry declared in the `plugins` block\", never "
    "\"the `plugins` block owns/says/gives\". Em dashes unspaced (word—word). "
    "Plain words.\n"
)

NUDGE = (
    "You just wrote prose to a file. Re-read it now for inanimate agency "
    "(report/build/entry/declaration as subject of says/gives/owns/wrote/holds), "
    "spaced em dashes, and banned vocabulary; fix in place before moving on. If "
    "this text will publish under the user's name, run the ghostwrite §3 "
    "fresh-context sweep before hand-over."
)

PROSE_SUFFIXES = (".md", ".markdown", ".txt")


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
    """UserPromptSubmit hook: print any saved note, clear it, then the reminder."""
    path = state_path(data)
    note = ""
    try:
        with open(path) as f:
            note = f.read()
        discard(path)
    except OSError:
        pass
    out.write(note + REMINDER)
    return note + REMINDER


def nudge(data, out=sys.stdout):
    """PostToolUse hook: on a prose-file Write/Edit, tell the model to sweep it."""
    file_path = str((data.get("tool_input") or {}).get("file_path") or "")
    if not file_path.lower().endswith(PROSE_SUFFIXES):
        return ""
    payload = json.dumps({"hookSpecificOutput": {
        "hookEventName": "PostToolUse", "additionalContext": NUDGE}})
    out.write(payload)
    return payload


def run(mode, stdin_text, out=sys.stdout):
    try:
        data = json.loads(stdin_text)
        if mode == "--emit":
            emit(data, out)
        elif mode == "--nudge":
            nudge(data, out)
        else:
            record(data)
    except Exception:
        pass  # unparseable input, an unwritable temp dir, anything: never interfere
    return 0


def self_test():
    cases = 0

    def agency(text):
        return [h for h in lint(text) if h[0] == "inanimate agency"]

    # The nine violations confirmed in the R74 issue draft (2026-08-30), the
    # measured ground truth this design was rebuilt against.
    r74 = [
        "A version catalog plugin alias bounds a `plugins` block declaration that never used it",
        "a `plugins` block declaration that wrote its own version range inline",
        "so the report is no longer a function of the declarations the build wrote",
        "with the `rejectVersionIf` rule the README gives for respecting declared bounds",
        "With a `gradle/libs.versions.toml` declaring an alias for that plugin id",
        "Every non-static field in the class hierarchy holds the same value",
        "Neither adds a constraint to the buildscript classpath configuration.",
        "It exempts a range on the grounds that a required range keeps its own interval",
        "Recovery runs only when the declared version states a range",
    ]
    for text in r74:
        assert agency(text), text
    cases += 1

    for text in [
        "The build script says the tests pass.",
        "The report says everything is fine.",
        "The report concluded the build is fine.",
        "The stability report noted a regression.",
        "The cap is gone, so the report offers the upgrade anyway.",
        "The plugins block owns the version for every alias in it.",
        "Each carries its own version range.",
    ]:
        assert agency(text), text
    cases += 1

    for text in [
        "The user says the build is slow on CI.",
        "The maintainer wrote the original recovery in 2023.",
        "The function returns early when the list is empty, keeping the loop simple.",
        "The test passes on Gradle 8.4 and fails on 9.0.0.",
        "Gradle flattens the alias to a bare require on the marker.",
        "The claim file is named by the session that holds the lease.",
        "I wrote the fix and we decided to keep the flag off by default.",
        "The value is used only when the declared version is exact.",
        "This keeps the diff small and the behaviour unchanged.",
        "That said, the guard is still worth a test.",
        "The declared bound is a ceiling, not a floor.",
        "The rule stated in the README covers this case.",
        "A reviewer who knows the codebase can confirm this in minutes.",
        "The upgrade is left out of the report when the rule fires.",
        "Run the suite before you commit anything.",
        "A session's notes are kept under the scratchpad.",
    ]:
        assert agency(text) == [], (text, agency(text))
    cases += 1

    assert any(g == "banned word" and m.lower() == "vacuous"
               for g, m in lint("This fix is not vacuous at all."))
    cases += 1

    assert any(g == "spaced em dash" for g, _ in lint("This is one thing — and another."))
    cases += 1

    assert lint("Code:\n```\nshape = (1, 2)\n```\nAnd inline `shape` too.") == []
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
    assert REMINDER in buf.getvalue()  # ...with the standing reminder appended
    second = io.StringIO()
    emit(data, second)  # a second read finds no note, only the reminder
    assert second.getvalue() == REMINDER
    cases += 1

    record(data)  # a clean reply clears a pending note
    record({"session_id": "selftest", "last_assistant_message": "Plain prose, nothing flagged."})
    clean = io.StringIO()
    emit(data, clean)
    assert clean.getvalue() == REMINDER
    cases += 1

    buf = io.StringIO()
    out = nudge({"tool_input": {"file_path": "/tmp/draft.md"}}, buf)
    parsed = json.loads(out)
    assert parsed["hookSpecificOutput"]["additionalContext"] == NUDGE
    assert parsed["hookSpecificOutput"]["hookEventName"] == "PostToolUse"
    assert nudge({"tool_input": {"file_path": "/src/Main.kt"}}, io.StringIO()) == ""
    assert nudge({}, io.StringIO()) == ""
    cases += 1

    assert run("--record", "not json at all {{{") == 0  # garbage stdin never interferes
    assert run("--emit", "not json at all {{{") == 0
    assert run("--nudge", "not json at all {{{") == 0
    cases += 1

    print("PASS (%d cases)" % cases)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        try:
            mode = "--record"
            for candidate in ("--emit", "--nudge"):
                if candidate in sys.argv:
                    mode = candidate
            sys.exit(run(mode, sys.stdin.read()))
        except SystemExit:
            raise
        except Exception:
            sys.exit(0)
