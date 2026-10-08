# CLAUDE.md

libxml2 for OpenVMS x86-64, built with VSI's clang (LP64) for clang programs (vms-php),
wrapped by the same tooling as `~/projects/vms-zlib`, `vms-pcre2` and the other sibling ports
(read vms-grep's `CLAUDE.md` for the ground rules and VMS/ssh pitfalls, and vms-mariadb's for
the clang ones; they all apply). In short:

- **Never edit `staging/`, `cache/` or `out/`.** Upstream files change only through
  `patches/` (listed in `patches/series`); our files live in `overlay/vmsport/`.
- **Use `tools/vms.sh`** for remote work; never raw `ssh host cmd`, never `WAIT` over ssh.
- **Committed files must not contain real node details** (they live in `tools/nodes.conf`).
- The work directory is the one the other dependencies use (vms-zlib, vms-pcre2), so that
  their install trees sit side by side.
- `BUILD.COM` compiles a source only when its object is older; it does not track headers or
  flags: `tools/build.sh x86 CLEAN` after changing either.
- In DCL test procedures, redirect a program's output with `PIPE cmd > f 2> g`, not
  `DEFINE/USER SYS$OUTPUT` (it outlives an image that fails to activate) or a process-mode
  DEFINE (aborts under vms.sh).

```sh
tools/prepare.sh
tools/build.sh x86 [ALL|CLEAN]
tools/test.sh x86
```

Don't push without the user asking; the GitHub repository does not exist yet.
