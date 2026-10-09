/* kit_test.c - build against the installed kit (tools/installcheck.sh):
   parse a document from memory, count nodes with XPath, serialise it.
   Prints "KIT_TEST: PASS" if all three work. */
#include <stdio.h>
#include <string.h>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xpath.h>
#include <libxml/xmlversion.h>

int main(void)
{
  static const char doc_text[] = "<forum><topic id='1'>Welcome</topic><topic id='2'>VMS</topic></forum>";
  xmlDocPtr doc;
  xmlXPathContextPtr ctx;
  xmlXPathObjectPtr obj;
  xmlChar *out = NULL;
  int len = 0, count = -1;

  LIBXML_TEST_VERSION
  doc = xmlReadMemory(doc_text, (int) strlen(doc_text), "kit_test.xml", NULL, 0);
  if (!doc) { printf("KIT_TEST: FAIL (parse)\n"); return 0; }
  ctx = xmlXPathNewContext(doc);
  obj = ctx ? xmlXPathEvalExpression((const xmlChar *) "//topic", ctx) : NULL;
  if (obj && obj->nodesetval) count = obj->nodesetval->nodeNr;
  xmlDocDumpMemory(doc, &out, &len);
  printf("KIT_TEST: libxml2 %s, %d topics, serialised %d bytes\n", LIBXML_DOTTED_VERSION, count, len);
  printf("KIT_TEST: %s\n", (count == 2 && out && strstr((char *) out, "<topic id=\"2\">VMS</topic>")) ? "PASS" : "FAIL");
  xmlFree(out);
  xmlXPathFreeObject(obj);
  xmlXPathFreeContext(ctx);
  xmlFreeDoc(doc);
  xmlCleanupParser();
  return 0;
}
