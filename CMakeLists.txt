# c-project-skeleton — modern C23 application skeleton.
#
# CMake >= 3.28 with the Ninja generator drives the build. The Makefile in
# the repo root provides the daily verbs over it.
cmake_minimum_required(VERSION 3.28)

project(c-project-skeleton VERSION 0.1 LANGUAGES C)

set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Emit compile_commands.json for clangd (see .clangd).
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ------------------------------------------------------------------------------
# Build configurations. Single-config generators (Ninja) pick one via
# CMAKE_BUILD_TYPE; default to Debug. Both flag sets are common to Clang
# and GCC.
# ------------------------------------------------------------------------------
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

# Debug: full DWARF-4 debug info (-g3 keeps macro definitions for the
# debugger), no optimization, no strict-aliasing reordering (keeps
# single-stepping honest), and hardening — stack canaries on every function
# plus a few debug-only warnings. Asserts stay live (no NDEBUG).
set(CMAKE_C_FLAGS_DEBUG
    "-O0 -g3 -gdwarf-4 -fno-strict-aliasing -fstack-protector-all \
-Wstack-protector -Wformat-security -Wswitch-default")

# Release / production: optimized, assertions compiled out.
set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")

# Project warning set: warnings-as-errors, common to Clang and GCC.
add_compile_options(
  -Wall -Wextra -Wpedantic -Werror
  -Wconversion -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable
  -Wshadow -Wformat=2 -Wmissing-include-dirs -Wswitch-enum
  -Wfloat-equal -Wredundant-decls -Wnull-dereference
  -Wold-style-definition -Wdouble-promotion -Wshift-overflow
  -Wstrict-aliasing=2 -Wformat-nonliteral
)

# Compiler-specific additions, applied via generator expressions. GCC has
# analysis warnings Clang lacks; Clang gets its parenthesization checks and
# a relaxation the Check framework's macros need.
add_compile_options(
  "$<$<C_COMPILER_ID:GNU>:-Wlogical-op;-Wstrict-overflow=5;-Wformat-overflow=2;-Wformat-truncation=2;-Wstack-usage=1024;-Wuse-after-free=3;-Wdangling-pointer=2>"
  "$<$<C_COMPILER_ID:Clang,AppleClang>:-Wlogical-not-parentheses;-Wlogical-op-parentheses;-Wno-gnu-folding-constant>"
)

# ------------------------------------------------------------------------------
# core: the domain library. The app and the test runner both link it, so
# tests exercise the same code the app ships. Add new translation units to
# this target as the project grows.
# ------------------------------------------------------------------------------
add_library(core STATIC
  src/greeter.c
)
target_include_directories(core PUBLIC include)

# ------------------------------------------------------------------------------
# The application: a thin main over core.
# ------------------------------------------------------------------------------
add_executable(${PROJECT_NAME} src/main.c)
target_link_libraries(${PROJECT_NAME} PRIVATE core)

# ------------------------------------------------------------------------------
# Tests: the Check framework through pkg-config. Its headers import as
# SYSTEM includes, so the GNU extensions inside them never trip
# -Wpedantic -Werror. New tests/*.c files are picked up by the
# CONFIGURE_DEPENDS glob at the next build. `make test` runs these via
# ctest.
# ------------------------------------------------------------------------------
include(CTest)
if(BUILD_TESTING)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(check REQUIRED check)
  file(GLOB TEST_SOURCES CONFIGURE_DEPENDS tests/*.c)
  add_executable(tests_runner ${TEST_SOURCES})
  target_link_libraries(tests_runner PRIVATE core ${check_LINK_LIBRARIES})
  target_include_directories(tests_runner SYSTEM PRIVATE ${check_INCLUDE_DIRS})
  add_test(NAME unit COMMAND tests_runner)
endif()

install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION bin)
