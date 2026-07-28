# c-project-skeleton

A modern C23 project skeleton for Linux and macOS.

CMake and Ninja drive the build. A thin Makefile provides the daily verbs, so `make build`, `make test`, and `make lint` work before you read a line of the CMake.

It all works on clone. Warnings are errors from the first compile. Sanitizers and static analysis are configured, not left as a TODO. The Check suite ships with real tests in it.

## Directory Structure

```bash
c-project-skeleton/
├── CMakeLists.txt   // The build: targets, flags, tests
├── Makefile         // Verb layer: make debug, make test, make asan, ...
├── docs/            // Documentation
│   └── DEVELOPMENT_WORKFLOW.md
├── include/         // Public headers (greeter.h is the sample)
├── lib/             // Third-party libraries
├── scripts/         // Helper scripts for setup and maintenance
├── src/             // C sources (core library + main.c)
└── tests/           // Check test suites
```

The build writes into `build-<compiler>-<type>/` directories (for example `build-clang-debug/`), one per compiler and configuration, so builds never clobber each other. Sanitizer and analysis builds get their own `build-asan/`-style directories.

## Prerequisites

- CMake 3.28 or newer and Ninja
- A C23-capable compiler (recent clang or gcc)
- [Check](https://libcheck.github.io/check/) for unit testing (`brew install check` on macOS, `apt install check` on Ubuntu)
- clang-format (its own Homebrew formula, lands on PATH) and clang-tidy (from `brew install llvm`)
- A real GCC for `make gcc-analyze` (native on Linux, `brew install gcc` on macOS)
- Optional: cppcheck, flawfinder, Valgrind (Linux), CBMC, Facebook Infer

### macOS tool locations

Homebrew LLVM is keg-only and stays off PATH on purpose, so it never shadows Apple clang. The Makefile resolves tools in this order: environment variables, then the keg through `brew --prefix llvm`, then PATH. Apple clang remains the default compiler throughout. To make the tools available everywhere, export them once in `~/fish/env.fish`:

```fish
if test (uname) = Darwin
    set -x LLVM_PREFIX /opt/homebrew/opt/llvm
    set -x CLANG_TIDY $LLVM_PREFIX/bin/clang-tidy
    set -x SCAN_BUILD $LLVM_PREFIX/bin/scan-build
    set -x LLVM_COV $LLVM_PREFIX/bin/llvm-cov
    set -x LLVM_PROFDATA $LLVM_PREFIX/bin/llvm-profdata
end
```

On Linux the LLVM tools install onto PATH normally, so no setup is needed.

## Build and Run

- **Debug build (default):** `make debug` or just `make`
- **Release build:** `make release`
- **Run the app:** `make run` (or `make run BUILD_TYPE=release`)
- **Switch compilers:** `make debug CC=gcc`

## Testing

Tests use the Check framework and run through ctest:

```bash
make test
```

The layout is one suite per file: each `test_*.c` exports a suite creator, `tests/suites.h` declares it, and `tests/runner.c` registers it. To add a suite for new code, copy `tests/test_sample.c`, rename its creator, and register it in both places. The CMake glob picks new files up at the next build. The sample suite shows assertions, checked fixtures, and loop tests.

One usage rule under our strict flags: for floating-point assertions use Check's `*_eq_tol` and `*_ne_tol` variants. The exact `ck_assert_double_eq` family will not compile because `-Wfloat-equal` rejects the comparison at the use site.

## Coding Style

This project uses `clang-format` configured for K&R-derived 1TBS: every opening brace attaches to its line, every control statement gets braces, two-space indent, 120-column lines. Names are snake_case, with UPPER_CASE macros and enum constants (enforced by clang-tidy). Run `make format` to format and `make tidy` (or `make lint`) to lint. `make compile-db` links `compile_commands.json` to the repo root for clangd.

## Static Analysis, Sanitizers, and Profiling

- **Lint:** `make tidy` (clang-tidy, includes clang-analyzer checks)
- **Deep static analysis:** `make analyze` (scan-build) and `make gcc-analyze` (GCC `-fanalyzer`, e.g. `make gcc-analyze GCC=gcc-16`)
- **Other checkers:** `make cppcheck`, `make flawfinder`, `make dependency-check`
- **All of the quality tools:** `make quality`
- **Sanitizers:** `make asan`, `make ubsan`, `make tsan`, `make lsan`, or all in turn with `make sanitizers`. Each builds into its own directory, runs the test runner under instrumentation, then runs the app. Apple clang lacks `-fsanitize=leak`. On macOS, install LLVM with `brew install llvm` and run `make lsan CC="$(brew --prefix llvm)/bin/clang"`.

  The `lsan` target runs the tests with `CK_FORK=no`, because Check's fork mode exposes the parent's live allocations to LeakSanitizer in every child. Signal and exit tests require fork mode, so keep them out of suites that must pass under `lsan`.
- **Coverage:** `make llvm-coverage` writes an HTML report to `coverage/html/`
- **Valgrind (Linux):** `make valgrind-memcheck` (test runner), `make valgrind-cachegrind`, `make valgrind-callgrind`, `make valgrind-massif`

## License

This project is licensed under the [MIT License](LICENSE).
