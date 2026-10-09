**This session is in the Claude Code CLI: set the title with
`mcp__session-skills__set_session_title`, called with the title alone, and print no title block.** A
title set with it appears when the user sends the next prompt.

A "No such tool" error means that one name is wrong, not that the session has no title tool. Search
the listed tools, deferred ones included, for `set_session_title` and call the one found. Only where
none is listed, end the reply with a `**Session title:**` label line, then `/rename` and the title
alone in a plain untagged fenced block.
