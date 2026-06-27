# Makefile for building sdcv Windows native binary (MinGW64)
# Works both locally (MSYS2 MinGW64) and in GitHub Actions

SHELL := /bin/bash
UPSTREAM_REPO := https://github.com/Dushistov/sdcv.git
BUILD_DIR := build
DIST_DIR := dist
SCRIPTS_DIR := scripts
PATCHES_DIR := patches

# MSYS2 root (for cmake compiler path and DLLs)
# Auto-detect: GitHub Actions runner first, then common local paths
MSYS2_ROOT ?= $(shell \
	if [ -n "$$CI" ] && [ -d "C:/msys64" ]; then \
		echo "C:/msys64"; \
	elif [ -d "C:/msys64" ]; then \
		echo "C:/msys64"; \
	elif [ -d "C:/tools/msys64" ]; then \
		echo "C:/tools/msys64"; \
	elif [ -d "C:/msys32" ]; then \
		echo "C:/msys32"; \
	else \
		echo "C:/msys64"; \
	fi)

# Default values (can be overridden on command line)
CMAKE_BUILD_TYPE ?= Release
ENABLE_NLS ?= OFF
WITH_READLINE ?= OFF

# Derived values
SDCV_VERSION := $(shell git -C upstream-src describe --tags 2>/dev/null || echo "unknown")
DIST_NAME := sdcv-windows-x64-$(SDCV_VERSION)
DIST_ZIP := $(DIST_DIR)/$(DIST_NAME).zip

.PHONY: all build dist clean info clone patch

all: dist

# Step 1: Clone upstream source
clone:
	@if [ ! -d upstream-src ]; then \
		echo "==> Cloning upstream sdcv..."; \
		git clone $(UPSTREAM_REPO) upstream-src; \
	else \
		echo "==> Updating upstream sdcv..."; \
		git -C upstream-src fetch --tags; \
		git -C upstream-src checkout $$(git -C upstream-src tag --sort=-v:refname | head -1); \
	fi
	@echo "==> Upstream version: $(SDCV_VERSION)"

# Step 2: Apply Windows compatibility patches
patch: clone
	@if [ ! -f .patch-applied ]; then \
		echo "==> Applying Windows compatibility patches..."; \
		bash $(SCRIPTS_DIR)/fix-win32.sh; \
		touch .patch-applied; \
	else \
		echo "==> Patches already applied, skipping."; \
	fi

# Step 3: Configure with CMake
configure: patch
	@echo "==> Configuring with CMake..."
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake ../upstream-src \
		-G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DENABLE_NLS=$(ENABLE_NLS) \
		-DWITH_READLINE=$(WITH_READLINE) \
		-DCMAKE_C_COMPILER=$(MSYS2_ROOT)/mingw64/bin/gcc.exe \
		-DCMAKE_CXX_COMPILER=$(MSYS2_ROOT)/mingw64/bin/g++.exe \
		-DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++"

# Step 4: Build
build: configure
	@echo "==> Building sdcv..."
	$(MAKE) -C $(BUILD_DIR) -j$(nproc)

# Step 5: Package exe + DLLs into a zip
dist: build
	@echo "==> Packaging..."
	@mkdir -p $(DIST_DIR)/$(DIST_NAME)
	@cp $(BUILD_DIR)/sdcv.exe $(DIST_DIR)/$(DIST_NAME)/
	@echo "==> Copying MinGW runtime DLLs..."
	@DLL_LIST="libglib-2.0-0.dll libintl-8.dll libiconv-2.dll zlib1.dll libpcre2-8-0.dll libwinpthread-1.dll libgcc_s_seh-1.dll libstdc++-6.dll"; \
	for dll in $$DLL_LIST; do \
		found=$$(find "$(MSYS2_ROOT)/mingw64/bin" -name "$$dll" 2>/dev/null | head -1); \
		if [ -n "$$found" ]; then \
			cp "$$found" $(DIST_DIR)/$(DIST_NAME)/; \
			echo "  -> $$dll"; \
		else \
			echo "  -> WARN: $$dll not found"; \
		fi; \
	done
	@echo "==> Creating zip archive..."
	@cd $(DIST_DIR) && zip -r $(DIST_NAME).zip $(DIST_NAME)/
	@echo "==> Done: $(DIST_ZIP)"
	@echo ""
	@echo "==> Package contents:"
	@ls -la $(DIST_DIR)/$(DIST_NAME)/

info:
	@echo "sdcv Windows Build System"
	@echo "=========================="
	@echo "Upstream repo:  $(UPSTREAM_REPO)"
	@echo "Build type:     $(CMAKE_BUILD_TYPE)"
	@echo "ENABLE_NLS:     $(ENABLE_NLS)"
	@echo "WITH_READLINE:  $(WITH_READLINE)"
	@if [ -d upstream-src ]; then \
		echo "Upstream tag:   $(SDCV_VERSION)"; \
	fi
	@echo ""
	@echo "Available targets:"
	@echo "  make       - Full build (same as 'make dist')"
	@echo "  make build - Build only (no packaging)"
	@echo "  make dist  - Build + create zip distribution"
	@echo "  make clean   - Remove build artifacts"
	@echo "  make info    - Show this information"

clean:
	@echo "==> Cleaning..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR) upstream-src .patch-applied
	@echo "==> Done."