$! LIBXML2$STARTUP.COM - system startup for libxml2 on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! LIBXML2$ROOT, pointing at the installed [LIBXML2] directory, so that clang
$! programs compile with -I/libxml2$root/include and link with
$! LIBXML2$ROOT:[LIB]LIBXML2.OLB/LIBRARY.  To run it at every boot, add this
$! line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:LIBXML2$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign LIBXML2$ROOT instead (PCSI runs it so at removal).
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("LIBXML2$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode LIBXML2$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[LIBXML2].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.LIBXML2.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "LIBXML2.]"
$ if root .eqs. dir + "LIBXML2.]"
$ then
$   write sys$error "LIBXML2$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed LIBXML2$ROOT 'dev''root'
$ if f$search("LIBXML2$ROOT:[LIB]LIBXML2.OLB") .eqs. ""
$ then
$   write sys$error "LIBXML2$STARTUP: LIBXML2.OLB not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for libxml2"
$ say ""
$ say "    At system startup: to define LIBXML2$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:LIBXML2$STARTUP.COM"
$ say "    Building against libxml2 (clang only): compile with"
$ say "    -I/libxml2$root/include -names2=shortened"
$ say "    and link with LIBXML2$ROOT:[LIB]LIBXML2.OLB/LIBRARY."
$ say "    See LIBXML2$ROOT:[DOC]README.VMS."
$ say ""
$ say "    PRODUCT REMOVE LIBXML2 removes the product and deassigns LIBXML2$ROOT."
$ say ""
$ exit 1
