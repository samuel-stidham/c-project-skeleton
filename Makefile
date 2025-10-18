###############################################################################
# c-project-skeleton-v2 Makefile
#
# This Makefile supports Linux and macOS. It supports gcc and clang, and
# defines debug and release builds along with targets for formatting,
# static analysis, sanitizers, profiling, and testing.
#
# For parallel builds, use:
#   make -j$(shell nproc) debug
###############################################################################

# Phony targets
.PHONY: all debug release clean format debugger \
        clang-analyze clang-tidy cppcheck flawfinder splint dependency-check \
        asan fuzz lsan tsan ubsan llvm-coverage \
        valgrind-memcheck valgrind-cachegrind valgrind-callgrind valgrind-massif \
        test quality

###############################################################################
# Project Configuration
###############################################################################
PROJECT = c-project-skeleton-v2

###############################################################################
# OS and Compiler Settings
###############################################################################
OS := $(shell uname)

# Default compiler (override with "make CC=clang" if desired)
ifndef CC
  ifeq ($(OS), Darwin)
    CC = clang
  else
    CC = gcc
  endif
endif

# Basic C flags (applied to all builds)
COMMON_CFLAGS = -std=c17 -Wall -Werror -Wextra -Wpedantic -Wconversion \
                -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable \
                -Wshadow -Wformat=2 -Wmissing-include-dirs -Wswitch-enum \
                -Wfloat-equal -Wredundant-decls -Wnull-dereference \
                -Wold-style-definition -Wdouble-promotion -Wshift-overflow \
                -Wstrict-aliasing=2 -Wformat-nonliteral

# Optionally add these if not enabled by -Wall:
# COMMON_CFLAGS += -Wpointer-arith -Winit-self

# Debug and Production flags (in addition to COMMON_CFLAGS)
DEBUG_CFLAGS = -fno-strict-aliasing -gdwarf-4 -g3 -O0 \
               -Wstack-protector -fstack-protector-all -Wformat-security \
               -Wswitch-default

PROD_CFLAGS  = -O2

# Compiler-specific additional flags
COMMON_GCC_CFLAGS   = -Wlogical-op -Wstrict-overflow=5 -Wformat-overflow=2 \
                      -Wformat-truncation=2 -Wstack-usage=1024
COMMON_CLANG_CFLAGS = -Wlogical-not-parentheses -Wlogical-op-parentheses
DEBUG_CFLAGS_GCC    = -fmax-errors=1
DEBUG_CFLAGS_CLANG  = -ferror-limit=1 -Wno-gnu-folding-constant

ifeq ($(CC),gcc)
  COMMON_CFLAGS += $(COMMON_GCC_CFLAGS)
  DEBUG_CFLAGS  += $(DEBUG_CFLAGS_GCC)
else ifeq ($(CC),clang)
  COMMON_CFLAGS += $(COMMON_CLANG_CFLAGS)
  DEBUG_CFLAGS  += $(DEBUG_CFLAGS_CLANG)
endif

# Add include directory flag
COMMON_CFLAGS += -Iinclude

# Final flag sets for each build type
DEBUG_CFLAGS := $(COMMON_CFLAGS) $(DEBUG_CFLAGS)
PROD_CFLAGS  := $(COMMON_CFLAGS) $(PROD_CFLAGS)

# Linker flags (applied to all builds)
LINKER_FLAGS = -lm -lpthread

###############################################################################
# Directories and Files
###############################################################################
SRC_DIR      = src
INCLUDE_DIR  = include
BUILD_DIR    = build
BIN_DIR      = bin
TEST_DIR     = tests

# Final executable name
EXEC         = $(BIN_DIR)/main

# Source and object files
SRCS         = $(wildcard $(SRC_DIR)/*.c)
OBJS         = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS))

###############################################################################
# Debugger Settings
###############################################################################
# Use lldb on macOS, gdb on Linux (can override with DEBUGGER=...)
ifeq ($(OS), Darwin)
  DEBUGGER ?= lldb
else
  DEBUGGER ?= gdb
endif

###############################################################################
# Build Targets
###############################################################################
all: debug

debug: CFLAGS := $(DEBUG_CFLAGS)
debug: $(EXEC)

release: CFLAGS := $(PROD_CFLAGS)
release: $(EXEC)

$(EXEC): $(OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $^ $(LINKER_FLAGS) -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	# Automatic dependency generation added via -MMD -MP
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

###############################################################################
# Test Targets
###############################################################################
# Define test sources and objects
TEST_SRCS  = $(wildcard $(TEST_DIR)/*.c)
TEST_OBJS  = $(patsubst $(TEST_DIR)/%.c, $(BUILD_DIR)/%.test.o, $(TEST_SRCS))
TEST_EXEC  = $(BIN_DIR)/tests_runner

# Target to compile and run tests
test: $(TEST_EXEC)
	@echo "Running tests..."
	./$(TEST_EXEC)

$(TEST_EXEC): $(TEST_OBJS) $(filter-out $(BUILD_DIR)/main.o, $(OBJS))
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $^ $(LINKER_FLAGS) -o $@

$(BUILD_DIR)/%.test.o: $(TEST_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

###############################################################################
# Format code using clang-format
###############################################################################
format:
	clang-format -i $(SRC_DIR)/*.c $(INCLUDE_DIR)/*.h

###############################################################################
# Launch debugger (gdb or lldb) on the executable
###############################################################################
debugger:
	$(DEBUGGER) $(EXEC)

###############################################################################
# Additional Targets for Static Analysis, Sanitizers, and Profiling
###############################################################################

# --- Clang-Based Tools ---
# (Static Analysis, Sanitizers, and Coverage with clang/LLVM)

# Tools and flags
CLANG_ANALYZER  = clang --analyze
CLANG_TIDY      = clang-tidy
ASAN_FLAGS      = -fsanitize=address -fno-omit-frame-pointer
FUZZER_FLAGS    = -fsanitize=fuzzer
LSAN_FLAGS      = -fsanitize=leak
TSAN_FLAGS      = -fsanitize=thread
UBSAN_FLAGS     = -fsanitize=undefined
COVERAGE_FLAGS  = -fprofile-arcs -ftest-coverage
LLVM_COV        = llvm-cov
LLVM_PROFDATA   = llvm-profdata

# Targets using clang-based tools
clang-analyze:
	$(CLANG_ANALYZER) $(SRCS) -Iinclude

clang-tidy:
	$(CLANG_TIDY) $(SRCS) -- -std=c17 -Iinclude

# Sanitizer targets
asan: CFLAGS += $(ASAN_FLAGS)
asan: clean debug
	./$(EXEC)

fuzz: CFLAGS += $(FUZZER_FLAGS)
fuzz: clean debug
	./$(EXEC)

lsan: CFLAGS += $(LSAN_FLAGS)
lsan: clean debug
	./$(EXEC)

tsan: CFLAGS += $(TSAN_FLAGS)
tsan: clean debug
	./$(EXEC)

ubsan: CFLAGS += $(UBSAN_FLAGS)
ubsan: clean debug
	./$(EXEC)

# LLVM code coverage target
llvm-coverage: clean
	@echo "Building with coverage instrumentation..."
	@mkdir -p coverage/html

	$(MAKE) CC=clang CFLAGS="$(DEBUG_CFLAGS) -fprofile-instr-generate -fcoverage-mapping" debug
	$(MAKE) CC=clang CFLAGS="$(DEBUG_CFLAGS) -fprofile-instr-generate -fcoverage-mapping" test

	LLVM_PROFILE_FILE="coverage/main.profraw" ./bin/main
	LLVM_PROFILE_FILE="coverage/tests.profraw" ./bin/tests_runner

	$(LLVM_PROFDATA) merge -sparse coverage/*.profraw -o coverage/combined.profdata

	$(LLVM_COV) show \
		./bin/main \
		./bin/tests_runner \
		--instr-profile=coverage/combined.profdata \
		--format=html \
		--output-dir=coverage/html \
		src/ \
		tests/

	@echo "Coverage report generated at coverage/html. Open coverage/html/index.html in a browser."

# --- Valgrind-Based Tools (Linux Only) ---
VALGRIND_MEMCHECK   = valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes
VALGRIND_CACHEGRIND = valgrind --tool=cachegrind
VALGRIND_CALLGRIND  = valgrind --tool=callgrind
VALGRIND_MASSIF     = valgrind --tool=massif
VALGRIND_SGCHECK    = valgrind --tool=exp-sgcheck

valgrind-memcheck: $(EXEC)
	$(VALGRIND_MEMCHECK) ./$(EXEC)

valgrind-cachegrind: $(EXEC)
	$(VALGRIND_CACHEGRIND) ./$(EXEC)

valgrind-callgrind: $(EXEC)
	$(VALGRIND_CALLGRIND) ./$(EXEC)

valgrind-massif: $(EXEC)
	$(VALGRIND_MASSIF) ./$(EXEC)

# --- Other Analysis Tools ---
CPPCHECK         = cppcheck
DEPENDENCYCHECK  = $(HOME)/dependency-check/bin/dependency-check.sh
FLAWFINDER       = flawfinder
SPLINT           = splint

cppcheck:
	@mkdir -p coverage
	$(CPPCHECK) --enable=all --inconclusive -Iinclude --std=c17 --suppress=missingIncludeSystem --quiet $(SRCS) 2> coverage/cppcheck-report.txt

dependency-check:
	@echo "Running OWASP Dependency Check..."
	$(DEPENDENCYCHECK) --project $(PROJECT) --scan . --format HTML --out dependency-check-report.html
	@echo "Dependency Check report generated: dependency-check-report.html"

flawfinder:
	$(FLAWFINDER) $(SRCS)

splint:
	$(SPLINT) $(SRCS) -Iinclude

###############################################################################
# Quality Target
###############################################################################
# Runs all static analysis tools in sequence.
quality: clang-analyze clang-tidy cppcheck flawfinder splint
	@echo "Quality checks complete."

###############################################################################
# Clean Targets
###############################################################################
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)

###############################################################################
# Dependency File Inclusion
###############################################################################
-include $(OBJS:.o=.d)
-include $(TEST_OBJS:.test.o=.d)
