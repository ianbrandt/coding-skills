# PR bodies

---

Rotor now compresses an archive with zstd when `compression = "zstd"` is set in `rotor.toml`. The
default stays gzip. On the 2 GB sample log, zstd finished in 11 seconds against 38 for gzip, at a
similar size.

Fixes #212.

---

Skip a symlinked log directory during the scan instead of following it. Following the link walked
into `/proc` on one reported machine and never finished. A directory listed by its real path is still
scanned.

Fixes #230.

---

Print the path of each archive the pruner deletes when `--verbose` is passed. Before this change the
pruner deleted archives with no output, and a mistyped retention window was hard to spot.
