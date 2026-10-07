# Docs sections

---

## Retention

Rotor deletes an archive once it is older than the retention window. Set the window in `rotor.toml`:

```toml
[retention]
window = "30d"
```

The window takes a number and a unit: `h`, `d`, or `w`. Rotor reads an archive's date from its file
name, such as `app-2026-08-01.log.gz`, and uses the modification time only when the name has no
date. With no window set, rotor deletes nothing.

Run `rotor prune --dry-run` to print the archives a window would delete without deleting them.

---

## Compression

Rotor compresses each archive with gzip by default. To use zstd, set `compression` in `rotor.toml`:

```toml
compression = "zstd"
```

Archives written before the change stay in gzip, and rotor reads both. On a 2 GB sample log, zstd
finished in 11 seconds against 38 for gzip, at a similar size.
