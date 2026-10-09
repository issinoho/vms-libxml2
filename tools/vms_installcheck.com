$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the LIBXML2 kit, verify it,
$! compile (clang) and link a program against the installed library, run
$! xmllint from it, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[LIBXML2], system logical LIBXML2$ROOT); leaves it as
$! it was.
$ set noon
$ set process/parse_style=extended
$ define/process decc$argv_parse_style enable
$ here = f$environment("DEFAULT")
$ tree = here - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_X86_64]"
$! A LIBXML2$ROOT left in the process table (from a build) would hide the system one.
$ if f$trnlnm("LIBXML2$ROOT", "LNM$PROCESS_TABLE") .nes. "" then deassign/process LIBXML2$ROOT
$ write sys$output "=== INSTALL from ", kitdir
$ product install LIBXML2 /producer=ISSINOHO /base_system=X86VMS /source='kitdir' /options=noconfirm /log
$ write sys$output "=== install status ", $status
$ product show product LIBXML2 /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:LIBXML2$STARTUP.COM"), "]"
$ show logical LIBXML2$ROOT
$ directory/nohead/notrail/total LIBXML2$ROOT:[000000...]*.*
$ write sys$output "=== BUILD A PROGRAM AGAINST THE INSTALLED KIT"
$ clang :== $sys$system:clang.exe
$ test_src = tree - "]" + ".VMSPORT.KIT]KIT_TEST.C"
$ define/user sys$error sys$output
$ clang -O2 -fno-builtin-memset -fno-builtin-bzero -names2=shortened -I/libxml2$root/include -c 'test_src' -o kit_test.obj
$ link /executable=kit_test.exe kit_test.obj, LIBXML2$ROOT:[LIB]LIBXML2.OLB/library
$ run kit_test.exe
$ delete/nolog kit_test.obj;*, kit_test.exe;*
$ write sys$output "=== XMLLINT FROM THE INSTALLED KIT"
$ xmllint = "$LIBXML2$ROOT:[BIN]XMLLINT.EXE"
$ create/fdl="RECORD; FORMAT STREAM_LF;" xl_test.xml
$ open/append f xl_test.xml
$ write f "<r><a>1</a><a>2</a><a>3</a></r>"
$ close f
$ pipe xmllint "--xpath" "sum(//a)" xl_test.xml > xl_out.txt
$ search/nooutput xl_out.txt "6"
$ if $severity .eq. 1 then write sys$output "XMLLINT: PASS"
$ if $severity .ne. 1 then write sys$output "XMLLINT: FAIL"
$ delete/nolog xl_test.xml;*, xl_out.txt;*
$ write sys$output "=== REMOVE"
$ product remove LIBXML2 /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "LIBXML2$ROOT after removal: [", f$trnlnm("LIBXML2$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[LIBXML2...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:LIBXML2$STARTUP.COM"), "]"
$ product show product LIBXML2 /producer=ISSINOHO
