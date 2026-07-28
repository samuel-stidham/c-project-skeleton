# Development Workflow for c-project-skeleton

This document outlines the recommended workflow for developing, testing, and releasing a project built on this skeleton. The Makefile provides the verbs, and CMake with Ninja does the building.

## 1. Setup and Environment

- **Clone the Repository:**
  Begin by cloning the repository onto your local machine.
- **Development Environment:**
  - Use your preferred editor. Formatting and style come from `.editorconfig`, `.clang-format`, and `.clang-tidy`. clangd reads compile flags from the build directory (see `.clangd`), and `make compile-db` symlinks `compile_commands.json` to the repo root.
  - Ensure the required tools are installed: cmake (3.28+), ninja, clang or gcc with C23 support, Check, clang-format, clang-tidy. Optional: cppcheck, flawfinder, Valgrind (Linux).
- **Directory Structure:**
  - `src/`: C sources. The `core` static library holds domain code, and `main.c` stays thin.
  - `include/`: public headers.
  - `tests/`: Check suites.
  - `docs/`: documentation, including this workflow.
  - Build output lands in `build-<compiler>-<type>/` directories, never in the source tree.

## 2. Code Development

- **Writing Code:**
  - Put domain logic in the `core` library and keep `main.c` a thin entry point. Tests link `core` directly, so everything in it is testable.
  - Add new translation units to the `core` target in `CMakeLists.txt`.
  - Follow the 1TBS style enforced by `.clang-format` and the clang-tidy naming rules: attached braces, braces on every control statement, two-space indent, 120-column lines, snake_case names.
- **Code Formatting:**
  - Run `make format` frequently, or configure your editor to format on save with clang-format.

## 3. Building and Testing

- **Debug Build:** `make debug` (the default). Debug builds carry `-g3`, no optimization, and stack protectors. Asserts stay live.
- **Release Build:** `make release`, optimized with assertions compiled out.
- **Run:** `make run`, or `make run BUILD_TYPE=release`.
- **Tests:** `make test` builds and runs the Check suite through ctest with failure output shown. One suite per file: copy `tests/test_sample.c`, rename its creator, declare it in `tests/suites.h`, and register it in `tests/runner.c`.
- **Compiler switch:** any verb accepts `CC=`, for example `make debug CC=gcc`. Each compiler gets its own build directory.

## 4. Static Analysis

- `make tidy` (alias `make lint`) runs clang-tidy with the repo configuration, including the clang-analyzer checks.
- `make analyze` runs the Clang static analyzer through scan-build with an HTML report.
- `make gcc-analyze` runs GCC's `-fanalyzer`, a different engine, in its own build directory. It needs a real GCC: native on Linux, or `make gcc-analyze GCC=gcc-16` after `brew install gcc` on macOS.
- `make cppcheck` and `make flawfinder` provide additional checkers. `make quality` runs the sequence.

## 5. Sanitizers and Dynamic Analysis

- `make asan`, `make ubsan`, `make tsan`, and `make lsan` each build instrumented binaries in their own directory, run the tests, then run the app. `make sanitizers` runs all four.
- Apple clang lacks `-fsanitize=leak`. On macOS run `brew install llvm`, then `make lsan CC="$(brew --prefix llvm)/bin/clang"`.
- `make lsan` runs the test suite in one process (`CK_FORK=no`). Fork-dependent signal and exit tests belong in suites you exclude from leak runs.
- On Linux, `make valgrind-memcheck` runs the test binary under memcheck, and the cachegrind, callgrind, and massif targets profile the app.
- `make llvm-coverage` produces an HTML coverage report in `coverage/html/`.

## 6. Continuous Integration and Branching

- The repository does not ship CI configuration yet. When you add it, GitHub Actions workflows belong under `.github/workflows/` and should run the build, test, tidy, and sanitizer targets on every commit or pull request.
- Development happens on feature branches cut from `main` and lands through pull requests.
