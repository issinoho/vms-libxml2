# vms-libxml2

[libxml2](https://gitlab.gnome.org/GNOME/libxml2) for OpenVMS x86-64, built natively with
VSI's clang (LP64), for programs compiled with clang. Its first user is
[PHP for OpenVMS](https://github.com/issinoho/vms-php) (dom, xml, SimpleXML, XMLReader,
XMLWriter). Part of the same family as [MariaDB](https://github.com/issinoho/vms-mariadb),
[lighttpd](https://github.com/issinoho/vms-lighttpd), [zlib](https://github.com/issinoho/vms-zlib),
[PCRE2](https://github.com/issinoho/vms-pcre2) and the other
[ports for OpenVMS](https://openvms.issinoho.com).

## Status

| | x86-64 (OpenVMS E9.2-4, VSI clang 10.0.1) |
|---|---|
| libxml2 **2.15.4**, library (36 sources) and `xmllint` build with clang | yes |
| Smoke test: upstream's `testchar`, `testdict`, `testparser`; `xmllint` (DTD validation, XPath, HTML, namespaces, UTF-8 and ISO-8859-1 input, `--format`) | 11/11 |

No PCSI kit yet: the install tree is what other ports link statically.

## What gets built

- **`[.OBJ_X86_64_CLANG]LIBXML2.OLB`**, the library, and `XMLLINT.EXE`, `TESTCHAR.EXE`,
  `TESTDICT.EXE`, `TESTPARSER.EXE`.
- **An install tree** `[.INSTALL_X86_64_CLANG]` with `[.INCLUDE.LIBXML]*.H` and
  `[.LIB]LIBXML2.OLB`. Define the rooted logical name `LIBXML2$ROOT` for it, compile with
  `-I/LIBXML2$ROOT/INCLUDE` and link with `LIBXML2$ROOT:[LIB]LIBXML2.OLB/LIBRARY`.

**Why clang only:** VSI C is ILP32 (`long` and pointers 32-bit) and VSI's clang is LP64,
so objects from the two cannot be mixed. PHP for OpenVMS is a clang build. The compile
flags are the family's (vms-mariadb, vms-pcre2): `__GNUC__` defined, 64-bit `argv`,
`-names2=shortened`, and `vms_lp64.h` for the C RTL's 32-bit `long` interfaces.

**Features:** everything PHP's XML extensions use (tree, SAX1/2, push parser, reader,
writer, output, HTML, XPath, XPointer, XInclude, C14N, catalog, DTD validation, regexps,
RELAX NG, Schemas). Off: threads, iconv (libxml2's built-in UTF-8/16 and ISO-8859-x tables
are used), ICU, zlib, HTTP, dynamic modules. The switches are `XML_OPTIONS` in
`upstream.conf`.

## How this repository works

It stores only the VMS delta over the upstream release, like its siblings:

- `upstream.conf`: the pinned release and its SHA-256 (GNOME publishes no signature for
  libxml2), and `XML_OPTIONS`
- `overlay/vmsport/`: `config.h` (hand-written: libxml2 tests only `mmap`, `glob`,
  `getentropy`, `dlopen`, threads), `BUILD.COM`, `TEST_SMOKE.COM` and its test documents
- `tools/`: `prepare.sh` (also generates `include/libxml/xmlversion.h` by running
  upstream's configure on the host with `XML_OPTIONS`), `build.sh`, `test.sh`, `vms.sh`

```sh
tools/prepare.sh
tools/build.sh x86 [ALL|CLEAN]
tools/test.sh x86
```

## Licence

libxml2 is distributed under the MIT licence (`Copyright` in the release).
