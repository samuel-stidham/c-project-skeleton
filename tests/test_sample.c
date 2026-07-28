/*
 * Sample Check suite. To add a suite for new code:
 *   1. Copy this file and rename the suite creator.
 *   2. Declare the creator in suites.h.
 *   3. Register it with srunner_add_suite in runner.c.
 * The CMake glob picks new .c files in tests/ up at the next build.
 *
 * Under this project's flags, use the *_eq_tol and *_ne_tol variants
 * for floating-point assertions. The exact eq/ne variants do not
 * compile because of -Wfloat-equal.
 */
#include <stdint.h>
#include <stdlib.h>

#include "greeter.h"
#include "suites.h"

static int *counter;

static void setup(void) {
  counter = malloc(sizeof *counter);
  ck_assert_ptr_nonnull(counter);
  *counter = 0;
}

static void teardown(void) {
  free(counter);
  counter = NULL;
}

START_TEST(test_sanity) {
  ck_assert_int_eq(1 + 1, 2);
}
END_TEST

START_TEST(test_greeting_names_caller) {
  char buf[32];
  ck_assert_str_eq(greeting(buf, sizeof buf, "tests"), "Hello from tests!");
}
END_TEST

START_TEST(test_fixture_starts_fresh) {
  *counter += 1;
  ck_assert_int_eq(*counter, 1);
}
END_TEST

static const int SQUARES[] = {0, 1, 4, 9};

START_TEST(test_loop_squares) {
  ck_assert_int_eq((intmax_t) _i * _i, SQUARES[_i]);
}
END_TEST

Suite *sample_suite(void) {
  Suite *s = suite_create("sample");
  TCase *tc_core = tcase_create("core");

  tcase_add_checked_fixture(tc_core, setup, teardown);
  tcase_add_test(tc_core, test_sanity);
  tcase_add_test(tc_core, test_greeting_names_caller);
  tcase_add_test(tc_core, test_fixture_starts_fresh);
  tcase_add_loop_test(tc_core, test_loop_squares, 0, 4);
  suite_add_tcase(s, tc_core);
  return s;
}
