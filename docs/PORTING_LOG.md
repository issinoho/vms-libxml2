# Porting log

One entry per build or run failure: command, error, root cause, fix.
Triage codes: T toolchain/flags, H header, L libc function, D dependency, X test harness.

| # | Date | Command | Error | Code | Root cause | Fix |
|---|---|---|---|---|---|---|
| 1 | 2026-10-08 | `build.sh x86` | `'codegen/ranges.inc' file not found` (chvalid, encoding, xmlIO, HTMLparser, xmlregexp) | T | push.sh uploaded top-level sources and include/ only; 2.15 includes generated tables from `codegen/*.inc` | push.sh uploads `codegen/*.inc`; the other 31 library sources and the programs compiled with clang unchanged |
| 2 | 2026-10-08 | `test.sh x86` | every check's PASS/FAIL line missing, then `%SYSTEM-F-ABORT` | X | `DEFINE/USER SYS$OUTPUT` outlives an image that fails to activate and swallowed the procedure's own output; a process-mode DEFINE instead aborted the vms.sh session | `PIPE cmd > out 2> err` |
| 3 | 2026-10-08 | `test.sh x86` | "validity error reported": xmllint's status `%X00000003` counted as success | X | the C RTL passes `exit(3)` through as status 3, which is odd ("success" to DCL) | the check compares with status 1 (exit 0) exactly |
