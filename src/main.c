#include "greeter.h"

#include <stdio.h>

int main(void) {
  char buf[64];
  printf("%s\n", greeting(buf, sizeof buf, "c-project-skeleton"));
  return 0;
}
