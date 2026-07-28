# c-project-skeleton verb layer over CMake + Ninja. The build itself lives
# in CMakeLists.txt; this Makefile only provides the daily verbs.

# Default compiler (override: make debug CC=gcc).
# Make predefines CC (to cc), so `?=` would never take effect. Only override
# that built-in default — respect an explicit command-line or environment CC.
ifeq ($(origin CC),default)
  ifeq ($(shell uname),Darwin)
    CC := clang
  else
    CC := gcc
  endif
endif

COMPILER_NAME := $(shell basename $(CC))

# Build configuration: debug (default) or release, each in its own dir so the
# two never clobber each other. Per-config flags live in CMakeLists.txt
# (CMAKE_C_FLAGS_DEBUG / _RELEASE).
BUILD_TYPE ?= debug
ifeq ($(BUILD_TYPE),debug)
CMAKE_BUILD_TYPE := Debug
else ifeq ($(BUILD_TYPE),release)
CMAKE_BUILD_TYPE := Release
else
$(error BUILD_TYPE must be 'debug' or 'release', got '$(BUILD_TYPE)')
endif

BUILD_DIR := build-$(COMPILER_NAME)-$(BUILD_TYPE)
BIN       := $(BUILD_DIR)/c-project-skeleton
TESTBIN   := $(BUILD_DIR)/tests_runner

.PHONY: all setup build rebuild run debug release prod test compile-db \
        format lint tidy analyze gcc-analyze cppcheck flawfinder dependency-check \
        asan ubsan tsan lsan sanitizers llvm-coverage \
        valgrind-memcheck valgrind-cachegrind valgrind-callgrind valgrind-massif \
        quality clean distclean

all: debug

setup:
	@echo "Configuring CMake in $(BUILD_DIR) (CC=$(CC), $(CMAKE_BUILD_TYPE))"
	cmake -S . -B $(BUILD_DIR) -G Ninja \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)

# build configures first, so every verb works on a fresh clone.
build: setup
	cmake --build $(BUILD_DIR)

rebuild: setup build

# Config shortcuts. `debug` / `release` build the respective configuration
# into its own dir (build-<compiler>-<type>). Everything else keys off
# BUILD_TYPE, e.g. `make run BUILD_TYPE=release`. `prod` aliases `release`.
debug:
	@$(MAKE) --no-print-directory BUILD_TYPE=debug rebuild
release prod:
	@$(MAKE) --no-print-directory BUILD_TYPE=release rebuild

run: rebuild
	"$(BIN)"

# Build and run the test suite via ctest.
test: rebuild
	ctest --test-dir $(BUILD_DIR) --output-on-failure

# Generate compile_commands.json and symlink it to the repo root for clangd.
# CMake emits it at configure time, so `setup` is enough — no build required.
compile-db: setup
	@ln -sf $(BUILD_DIR)/compile_commands.json compile_commands.json
	@echo "compile_commands.json -> $(BUILD_DIR)/compile_commands.json"

###############################################################################
# Formatting and static analysis
#
# Homebrew LLVM is keg-only and deliberately NOT on PATH, so it never
# shadows Apple clang. These variables reach into the keg explicitly when it
# exists and fall back to PATH lookups elsewhere (Linux, CI). The compiler
# default stays Apple clang; only the tooling comes from Homebrew LLVM.
# clang-format ships as its own Homebrew formula and lives on PATH.
# Environment overrides win (exported from ~/fish/env.fish on macOS), then
# the Homebrew LLVM keg, then PATH.
###############################################################################
LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null)
ifneq ($(wildcard $(LLVM_PREFIX)/bin/clang-tidy),)
  CLANG_TIDY    ?= $(LLVM_PREFIX)/bin/clang-tidy
  SCAN_BUILD    ?= $(LLVM_PREFIX)/bin/scan-build
  LLVM_COV      ?= $(LLVM_PREFIX)/bin/llvm-cov
  LLVM_PROFDATA ?= $(LLVM_PREFIX)/bin/llvm-profdata
  COVERAGE_CC   ?= $(LLVM_PREFIX)/bin/clang
else
  CLANG_TIDY    ?= clang-tidy
  SCAN_BUILD    ?= scan-build
  LLVM_COV      ?= llvm-cov
  LLVM_PROFDATA ?= llvm-profdata
  COVERAGE_CC   ?= clang
endif
CLANG_FORMAT ?= clang-format

SRCS := $(wildcard src/*.c) $(wildcard tests/*.c)

format:
	find src include tests \( -name '*.c' -o -name '*.h' \) -exec $(CLANG_FORMAT) -i {} +

# clang-tidy, driven by .clang-tidy + compile_commands.json. The
# clang-analyzer-* checks run as part of this. Homebrew clang-tidy does not
# know the macOS SDK location, so pass the sysroot explicitly on Darwin.
ifeq ($(shell uname),Darwin)
  TIDY_EXTRA := --extra-arg=-isysroot --extra-arg=$(shell xcrun --show-sdk-path)
endif

tidy: rebuild
	$(CLANG_TIDY) $(TIDY_EXTRA) -p $(BUILD_DIR) $(SRCS)

# Friendly alias.
lint: tidy

# Clang static analyzer via scan-build over a fresh build: path-sensitive,
# cross-statement analysis with an HTML report. Deeper and slower than
# `tidy`; complements it.
analyze:
	rm -rf build-scan
	$(SCAN_BUILD) --use-cc=clang \
		cmake -S . -B build-scan -G Ninja -DCMAKE_C_COMPILER=clang
	$(SCAN_BUILD) --use-cc=clang -o build-scan/report \
		cmake --build build-scan

# GCC's built-in static analyzer (-fanalyzer): a different engine from
# Clang's, actively developed. `-k 0` keeps ninja going so every finding is
# reported before -Werror fails the build. Needs a real GCC: native on
# Linux, or "brew install gcc" on macOS, then: make gcc-analyze GCC=gcc-16
GCC ?= gcc

gcc-analyze:
	cmake -S . -B build-gcc-analyze -G Ninja -DCMAKE_C_COMPILER=$(GCC) \
		-DCMAKE_C_FLAGS="-fanalyzer"
	cmake --build build-gcc-analyze -- -k 0

# cppcheck understands c23 directly.
cppcheck:
	cppcheck --enable=all --inconclusive --std=c23 -Iinclude \
		--suppress=missingIncludeSystem src tests

flawfinder:
	flawfinder src tests

dependency-check:
	@echo "Running OWASP Dependency Check..."
	$(HOME)/dependency-check/bin/dependency-check.sh --project c-project-skeleton \
		--scan . --format HTML --out dependency-check-report.html
	@echo "Dependency Check report generated: dependency-check-report.html"

# Runs the static analysis tools in sequence. gcc-analyze is separate
# because it needs a real GCC.
quality: tidy cppcheck flawfinder
	@echo "Quality checks complete."

###############################################################################
# Sanitizers. Each builds instrumented binaries in its own build-<name>/ via
# a fresh CMake configure, then runs the test runner and the app under it.
#
# No fuzz target: -fsanitize=fuzzer needs an LLVMFuzzerTestOneInput harness,
# not a regular main.
#
# Note: Apple clang does not support -fsanitize=leak. On macOS, install LLVM
# with "brew install llvm" and run:
#   make lsan CC="$(brew --prefix llvm)/bin/clang"
#
# lsan alone runs the tests with CK_FORK=no. Check's fork mode leaves the
# parent's live allocations visible in every child, and standalone
# LeakSanitizer reports them as leaks at child exit. The other sanitizers
# keep fork mode, which signal and exit tests require.
###############################################################################
asan:  SAN := address
ubsan: SAN := undefined
tsan:  SAN := thread
lsan:  SAN := leak
lsan:  SAN_TEST_ENV := CK_FORK=no

asan ubsan tsan lsan:
	cmake -S . -B build-$@ -G Ninja -DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_C_FLAGS="-fsanitize=$(SAN) -fno-omit-frame-pointer" \
		-DCMAKE_EXE_LINKER_FLAGS="-fsanitize=$(SAN)"
	cmake --build build-$@
	$(SAN_TEST_ENV) ./build-$@/tests_runner
	./build-$@/c-project-skeleton

# Build and run every sanitizer in turn.
sanitizers: asan ubsan tsan lsan

###############################################################################
# LLVM code coverage
###############################################################################
# Compiles with the same LLVM the llvm-cov/llvm-profdata tools come from, so
# the profraw format always matches.
llvm-coverage:
	rm -rf build-coverage coverage
	@mkdir -p coverage/html
	cmake -S . -B build-coverage -G Ninja -DCMAKE_C_COMPILER=$(COVERAGE_CC) \
		-DCMAKE_C_FLAGS="-fprofile-instr-generate -fcoverage-mapping"
	cmake --build build-coverage
	LLVM_PROFILE_FILE="coverage/main.profraw" ./build-coverage/c-project-skeleton
	LLVM_PROFILE_FILE="coverage/tests.profraw" ./build-coverage/tests_runner
	$(LLVM_PROFDATA) merge -sparse coverage/*.profraw -o coverage/combined.profdata
	$(LLVM_COV) show ./build-coverage/c-project-skeleton ./build-coverage/tests_runner \
		--instr-profile=coverage/combined.profdata --format=html \
		--output-dir=coverage/html src/ tests/
	@echo "Coverage report generated at coverage/html. Open coverage/html/index.html in a browser."

###############################################################################
# Valgrind-Based Tools (Linux Only)
###############################################################################
valgrind-memcheck: rebuild
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes "$(TESTBIN)"

valgrind-cachegrind: rebuild
	valgrind --tool=cachegrind "$(BIN)"

valgrind-callgrind: rebuild
	valgrind --tool=callgrind "$(BIN)"

valgrind-massif: rebuild
	valgrind --tool=massif "$(BIN)"

###############################################################################
# Clean Targets
###############################################################################
clean:
	cmake --build $(BUILD_DIR) --target clean || true

distclean:
	rm -rf build-* coverage
	rm -f compile_commands.json
