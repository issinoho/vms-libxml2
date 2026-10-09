$! BUILD.COM - build libxml2 for OpenVMS x86-64 with VSI clang (LP64)
$!
$! Usage:  @[.VMSPORT]BUILD [ALL|CLEAN]
$!
$! libxml2 is built with clang for programs compiled with clang (PHP for
$! OpenVMS): clang is LP64 (long and pointers 64-bit) where VSI C is ILP32, so
$! the two kinds of object cannot be mixed.  Outputs:
$!     [.OBJ_X86_64_CLANG]LIBXML2.OLB        the library
$!     [.OBJ_X86_64_CLANG]XMLLINT.EXE, TESTCHAR.EXE, TESTDICT.EXE, TESTPARSER.EXE
$!     [.INSTALL_X86_64_CLANG.INCLUDE.LIBXML]*.H   install tree used by other
$!     [.INSTALL_X86_64_CLANG.LIB]LIBXML2.OLB      ports (LIBXML2$ROOT)
$! Compile errors do not stop the build: every failing source is reported,
$! and the status is then an error.  Headers and flags are not tracked, so
$! use CLEAN after changing either.
$!
$ status = 44
$ set noon
$ on control_y then goto done
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ set default 'f$parse(proc,,,"DEVICE")''f$parse(proc,,,"DIRECTORY")'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ if arch .nes. "X86_64"
$ then
$   write sys$error "BUILD: x86-64 only (clang)"
$   goto done
$ endif
$ target = f$edit(p1, "UPCASE")
$ if target .eqs. "" then target = "ALL"
$ obj = "[.OBJ_X86_64_CLANG]"
$ inst = "[.INSTALL_X86_64_CLANG"
$ write sys$output "BUILD: ''target' for ''arch' (clang) in ''f$environment("DEFAULT")'"
$ if target .eqs. "CLEAN"
$ then
$   if f$search("''obj'*.*;*") .nes. "" then delete/nolog 'obj'*.*;*
$   if f$search("''inst'...]*.*;*") .nes. "" then delete/nolog 'inst'...]*.*;*
$   status = 1
$   goto finish
$ endif
$ clang :== $sys$system:clang.exe
$! keep the case of clang's arguments (-D...), and show its diagnostics
$ set process/parse_style=extended
$ define/process decc$argv_parse_style enable
$! The family's clang flags (vms-mariadb clang_common.rsp, vms-pcre2
$! clangflags.txt): __GNUC__ (VSI's clang does not define it), 64-bit argv,
$! shortened names over 31 characters (as VSI C libraries export them), and
$! vms_lp64.h for the C RTL's 32-bit long interfaces.  -include and -I take
$! UNIX paths relative to the top of the tree.
$! -fno-builtin-memset/bzero: VSI clang lowers both to OTS$FILL but assumes
$! memset's return value, which miscompiles "memset(p, 0, n); return p;"
$! (vms-php PORTING_LOG #17).  libxml2 has no such code; the flags keep it so.
$ cflags = "-std=gnu99 -O2 -fno-builtin-memset -fno-builtin-bzero -names2=shortened -pointer-size=argv64" + -
    " -D__GNUC__=4 -D__GNUC_MINOR__=2 -D__GNUC_PATCHLEVEL__=1" + -
    " -D_LARGEFILE -D_USE_STD_STAT -D_POSIX_EXIT -DHAVE_CONFIG_H" + -
    " -include vmsport/include/vms_lp64.h -I./vmsport -I./include -I."
$ if f$search("OBJ_X86_64_CLANG.DIR") .eqs. "" then create/directory 'obj'
$!
$! the library: upstream's libxml2_la_SOURCES for the XML_OPTIONS features
$ lib = "buf,chvalid,dict,entities,encoding,error,globals,hash,list,parser," + -
    "parserInternals,SAX2,threads,tree,uri,valid,xmlIO,xmlmemory,xmlstring," + -
    "c14n,catalog,debugXML,HTMLparser,HTMLtree,xmlsave,pattern,xmlreader," + -
    "xmlregexp,relaxng,xmlschemas,xmlschemastypes,xmlwriter,xinclude,xpath," + -
    "xlink,xpointer"
$ progs = "xmllint,shell,lintmain,testchar,testdict,testparser"
$ failed = ""
$ list = lib
$ gosub compile_list
$ list = progs
$ gosub compile_list
$ if failed .nes. ""
$ then
$   write sys$error "BUILD: compile failed:''failed'"
$   goto done
$ endif
$ if f$search("''obj'LIBXML2.OLB") .nes. "" then delete/nolog 'obj'LIBXML2.OLB;*
$ library/create/object 'obj'LIBXML2.OLB
$ i = 0
$lib_loop:
$ s = f$element(i, ",", lib)
$ if s .eqs. "," then goto lib_done
$ library/insert/object 'obj'LIBXML2.OLB 'obj''s'.OBJ
$ i = i + 1
$ goto lib_loop
$lib_done:
$ define/user sys$error sys$output
$ link/executable='obj'XMLLINT.EXE 'obj'XMLLINT.OBJ,'obj'SHELL.OBJ,'obj'LINTMAIN.OBJ,'obj'LIBXML2.OLB/library
$ if .not. $status then failed = failed + " XMLLINT.EXE"
$ i = 0
$test_loop:
$ t = f$element(i, ",", "testchar,testdict,testparser")
$ if t .eqs. "," then goto test_done
$ define/user sys$error sys$output
$ link/executable='obj''t'.EXE 'obj''t'.OBJ,'obj'LIBXML2.OLB/library
$ if .not. $status then failed = failed + " ''t'.EXE"
$ i = i + 1
$ goto test_loop
$test_done:
$ if failed .nes. ""
$ then
$   write sys$error "BUILD: link failed:''failed'"
$   goto done
$ endif
$ if f$search("INSTALL_X86_64_CLANG.DIR") .eqs. "" then create/directory 'inst']
$ if f$search("''inst']INCLUDE.DIR") .eqs. "" then create/directory 'inst'.INCLUDE]
$ if f$search("''inst'.INCLUDE]LIBXML.DIR") .eqs. "" then create/directory 'inst'.INCLUDE.LIBXML]
$ if f$search("''inst']LIB.DIR") .eqs. "" then create/directory 'inst'.LIB]
$ copy/nolog [.INCLUDE.LIBXML]*.H 'inst'.INCLUDE.LIBXML]
$ copy/nolog 'obj'LIBXML2.OLB 'inst'.LIB]
$ purge/nolog 'inst'...],'obj'
$ write sys$output "BUILD: library ''obj'LIBXML2.OLB, install tree ''inst']"
$ status = 1
$finish:
$ write sys$output "BUILD: done"
$done:
$ set default 'saved_default'
$ exit status
$!
$! compile every name in 'list' that has no object newer than its source
$compile_list:
$ i = 0
$compile_loop:
$ s = f$element(i, ",", list)
$ if s .eqs. "," then return
$ i = i + 1
$ o = obj + s + ".OBJ"
$ if f$search(o) .nes. ""
$ then
$   if f$cvtime(f$file_attributes(o, "RDT")) .ges. f$cvtime(f$file_attributes(s + ".C", "RDT")) -
        then goto compile_loop
$ endif
$ define/user sys$error sys$output
$ clang 'cflags' -c 's'.c -o 'o'
$ if .not. $status .or. f$search(o) .eqs. "" then failed = failed + " ''s'.c"
$ goto compile_loop
