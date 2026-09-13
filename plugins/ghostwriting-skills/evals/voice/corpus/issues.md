# Issues

---

Rotor skips a log file with a space in its name. The file is never rotated and grows without a
limit. No error is printed.

```
$ ls /var/log/app
access log.txt  error.log
$ rotor run --verbose
rotated /var/log/app/error.log
```

Seen on rotor 1.4.2, Linux.

---

`rotor check` exits 0 when `rotor.toml` sets a retention window of `0d`. The pruner then deletes
every archive on the next run.

```toml
[retention]
window = "0d"
```

Seen on rotor 1.5.0.
