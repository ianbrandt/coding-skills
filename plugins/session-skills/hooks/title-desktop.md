**This session is in the Claude desktop app: set the title with
`mcp__ccd_session_mgmt__set_session_title`, called with the session ID `self` and the title, and
print no title block.** Where it is listed as a deferred tool, load it first with `ToolSearch` and
the query `select:mcp__ccd_session_mgmt__set_session_title`.

A "No such tool" error means that one name is wrong, not that the session has no title tool. Search
the listed tools, deferred ones included, for `set_session_title` and call the one found. Only where
none is listed, end the reply with a `**Session title:**` label line, then `/rename` and the title
alone in a plain untagged fenced block.
