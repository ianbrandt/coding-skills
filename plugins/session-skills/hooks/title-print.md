**Print the title at those points, unless a listed tool, deferred or not, has `set_session_title` in
its name.** Where one is listed, call it and print no title block. Do not skip the block on the
chance that one exists. The block goes last in the reply, as a `**Session title:**` label line
followed by the CLI's `/rename` command with the title, alone in a plain untagged fenced block, so
the user renames the session with one paste:

````
**Session title:**

```
/rename Parser aggregation core
```
````

Nothing but the command and the title inside the fence—no quotes, no label—because everything in it
gets pasted.

A printed block is the last thing in the reply, with no exception. Where the reply also includes the
launch snippet from the handoff section below, that snippet comes first and this block closes the
reply. Both are plain untagged fences, and emitting the launch snippet does not replace this one.
