$! TEST_SMOKE.COM - check the clang build of libxml2 with upstream's own
$! unit-test programs and xmllint
$!
$! Usage:  @[.VMSPORT]TEST_SMOKE
$!   TESTCHAR, TESTDICT, TESTPARSER   upstream's self-contained unit tests
$!                                    (no test data files); each must exit
$!                                    successfully
$!   XMLLINT                          on [.VMSPORT.TESTDATA] (made on the host,
$!                                    Stream_LF): DTD validation, XPath, a
$!                                    validity error, HTML, namespaces, UTF-8
$!                                    and ISO-8859-1 input, writing back out
$! Prints PASS/FAIL per check and "SMOKE: n passed, m failed".
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ set default 'f$parse(proc,,,"DEVICE")''f$parse(proc,,,"DIRECTORY")'
$ set default [-]
$ top = f$environment("DEFAULT")
$ bin = top - "]" + ".OBJ_X86_64_CLANG]"
$ pass == 0
$ fail == 0
$ if f$search("SMOKE_TMP.DIR") .eqs. "" then create/directory [.SMOKE_TMP]
$ set default [.SMOKE_TMP]
$ if f$search("*.*;*") .nes. "" then delete/nolog *.*;*
$ copy/nolog [-.VMSPORT.TESTDATA]*.* []
$! keep the case of arguments ("--xpath" and XPath expressions)
$ define/process decc$argv_parse_style enable
$ set process/parse_style=extended
$!
$! 1. upstream's unit tests
$ i = 0
$unit_loop:
$ t = f$element(i, ",", "TESTCHAR,TESTDICT,TESTPARSER")
$ if t .eqs. "," then goto unit_done
$ i = i + 1
$ prog = "$" + bin + t + ".EXE"
$! PIPE redirects just this command (a /USER logical name would outlive an
$! image that fails to activate and swallow our own output)
$ pipe prog > 't'.out 2> 't'.err
$ st = $status
$ if st
$ then
$   write sys$output "PASS ''t'"
$   pass == pass + 1
$ else
$   write sys$output "FAIL ''t': status ''st'"
$   type 't'.out,'t'.err
$   fail == fail + 1
$ endif
$ goto unit_loop
$unit_done:
$!
$! 2. xmllint
$ xmllint :== $'bin'XMLLINT.EXE
$ call check "parse and DTD-validate (UTF-8)" "xmllint ""--noout"" ""--valid"" doc.xml" "" 1
$ call check "XPath count" "xmllint ""--xpath"" ""count(//topic)"" doc.xml" "2" 1
$ call check "XPath attribute" "xmllint ""--xpath"" ""string(//topic[2]/@id)"" doc.xml" "t2" 1
$ call check "validity error reported" "xmllint ""--noout"" ""--valid"" bad.xml" "" 0
$ call check "HTML parser" "xmllint ""--html"" ""--xpath"" ""count(//p)"" page.html" "2" 1
$ call check "namespaces + XPath sum" "xmllint ""--xpath"" ""sum(//*[local-name()='a'])"" ns.xml" "3" 1
$ call check "ISO-8859-1 input (no iconv)" "xmllint ""--encode"" ""UTF-8"" latin.xml" "caf" 1
$ call check "write back out (--format)" "xmllint ""--format"" ns.xml" "<x:a>2</x:a>" 1
$!
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ set default 'saved_default'
$ if fail .eq. 0 then exit 1
$ exit 44
$!
$! check name command want-substring want-success(1/0)
$check: subroutine
$ if f$search("chk.*") .nes. "" then delete/nolog chk.*;*
$ pipe 'p2' > chk.out 2> chk.err
$ st = $status
$! the C RTL passes exit(n) through as status n, so success is exactly 1
$! (exit 0) and xmllint's error codes (3 = validity error) are odd too
$ ok = (st .eq. 1) .eq. f$integer(p4)
$ if ok .and. p3 .nes. ""
$ then
$   files = "chk.out"
$   if f$search("chk.err") .nes. "" then files = files + ",chk.err"
$   search/nooutput 'files' "''p3'"
$   ok = $severity .eq. 1
$ endif
$ if ok
$ then
$   write sys$output "PASS ''p1'"
$   pass == pass + 1
$ else
$   write sys$output "FAIL ''p1': status ''st'"
$   if f$search("chk.*") .nes. "" then type chk.out,chk.err
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
