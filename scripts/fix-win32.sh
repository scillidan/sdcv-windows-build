#!/bin/bash
# fix-win32.sh - Apply Windows compatibility fixes for sdcv
# This script is idempotent and safe to run multiple times

set -e

echo "==> Applying Windows compatibility fixes..."

# --- Fix 1: config.h.cmake - disable mmap on Windows ---
# Simply comment out #cmakedefine HAVE_MMAP so CMake generates /* #undef HAVE_MMAP */
# which means HAVE_MMAP won't be defined -> mapfile.hpp uses Win32 API path
CONFIG_CMAKE="upstream-src/config.h.cmake"
if [ -f "$CONFIG_CMAKE" ]; then
	if grep -q '^#cmakedefine HAVE_MMAP' "$CONFIG_CMAKE"; then
		echo "  -> Patching config.h.cmake (disable mmap)"
		sed -i 's|^#cmakedefine HAVE_MMAP|// #cmakedefine HAVE_MMAP (disabled for Win32)|' "$CONFIG_CMAKE"
	else
		echo "  -> config.h.cmake already patched (HAVE_MMAP disabled)"
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

# --- Fix 4: stardict_lib.cpp - replace struct ::stat with GStatBuf ---
if [ -f "$STAR_DICT_LIB" ]; then
	if grep -q "struct ::stat" "$STAR_DICT_LIB"; then
		echo "  -> Patching src/stardict_lib.cpp (struct ::stat -> GStatBuf)"
		sed -i 's|struct ::stat|GStatBuf|g' "$STAR_DICT_LIB"
	else
		echo "  -> src/stardict_lib.cpp already uses GStatBuf or no struct ::stat found"
	fi
fi

# --- Fix 5: stardict_lib.cpp - fix const correctness for GCC 16 ---
# g_utf8_next_char returns const gchar* in glib >= 2.84, cast to non-const
if [ -f "$STAR_DICT_LIB" ]; then
	if grep -q 'gchar \*nextchar = g_utf8_next_char' "$STAR_DICT_LIB"; then
		echo "  -> Patching src/stardict_lib.cpp (const-correct g_utf8_next_char)"
		sed -i 's|gchar \*nextchar = g_utf8_next_char|gchar *nextchar = (gchar *)g_utf8_next_char|' "$STAR_DICT_LIB"
	else
		echo "  -> src/stardict_lib.cpp already const-correct for g_utf8_next_char"
	fi
fi

echo "==> All patches applied successfully."