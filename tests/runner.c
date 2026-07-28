/* Test runner. Register each suite here and declare it in suites.h. */
#include <stdlib.h>

#include "suites.h"

int main(void) {
  SRunner *sr = srunner_create(sample_suite());
  int failed = 0;

  /* Add further suites: srunner_add_suite(sr, another_suite()); */

  srunner_run_all(sr, CK_NORMAL);
  failed = srunner_ntests_failed(sr);
  srunner_free(sr);
  return (failed == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
