#!/bin/bash
# fix-win32.sh - Apply Windows compatibility fixes for sdcv
# This script is idempotent and safe to run multiple times

set -e

echo "==> Applying Windows compatibility fixes..."

# --- Fix 1: config.h.cmake - disable mmap on Windows ---
CONFIG_CMAKE="upstream-src/cmake/config.h.cmake"
if [ -f "$CONFIG_CMAKE" ]; then
	if ! grep -q "HAVE_MMAP 0" "$CONFIG_CMAKE"; then
		echo "  -> Patching cmake/config.h.cmake (disable mmap on Windows)"
		sed -i 's|^#cmakedefine HAVE_MMAP|#cmakedefine HAVE_MMAP\n#ifdef _WIN32\n#undef HAVE_MMAP\n#define HAVE_MMAP 0\n#endif|' "$CONFIG_CMAKE"
	else
		echo "  -> cmake/config.h.cmake already patched (HAVE_MMAP 0)"
	fi
else
	echo "  -> WARN: $CONFIG_CMAKE not found, skipping"
fi

# --- Fix 2: stardict_lib.cpp - guard unistd.h ---
STAR_DICT_LIB="upstream-src/src/stardict_lib.cpp"
if [ -f "$STAR_DICT_LIB" ]; then
	if grep -q '#include <unistd.h>' "$STAR_DICT_LIB" && \
	   ! grep -q '#ifdef _WIN32' "$STAR_DICT_LIB" | head -5 | grep -q "unistd"; then
		echo "  -> Patching src/stardict_lib.cpp (guard unistd.h)"
		sed -i 's|^#include <unistd.h>|#ifdef _WIN32\n#include <io.h>\n#else\n#include <unistd.h>\n#endif|' "$STAR_DICT_LIB"
	else
		echo "  -> src/stardict_lib.cpp already patched or no unistd.h found"
	fi
else
	echo "  -> WARN: $STAR_DICT_LIB not found, skipping"
fi

# --- Fix 3: sdcv.cpp - add locale.h include for Windows ---
SDCV_CPP="upstream-src/src/sdcv.cpp"
if [ -f "$SDCV_CPP" ]; then
	if ! grep -q '#include <locale.h>' "$SDCV_CPP"; then
		echo "  -> Patching src/sdcv.cpp (add locale.h for setlocale)"
		sed -i '/^#include <.*>/a\
#ifdef _WIN32\
#include <locale.h>\
#endif' "$SDCV_CPP"
	else
		echo "  -> src/sdcv.cpp already has locale.h"
	fi
else
	echo "  -> WARN: $SDCV_CPP not found, skipping"
fi

echo "==> All patches applied successfully."