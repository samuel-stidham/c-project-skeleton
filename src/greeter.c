#include "greeter.h"

#include <stdio.h>

char *greeting(char *buf, size_t buf_len, const char *name) {
  (void) snprintf(buf, buf_len, "Hello from %s!", name);
  return buf;
}
