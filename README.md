# sdcv Windows Build

MinGW64 native build of [sdcv](https://github.com/Dushistov/sdcv) — StarDict CLI. Runtime DLLs bundled in zip.

## Build

Requires MSYS2 with `mingw-w64-x86_64-{gcc,cmake,glib2,zlib,pcre2,gettext}`, `git`, `make`, `zip`.

```bash
make dist
```

Output: `dist/sdcv-windows-x64-vX.Y.Z.zip`

## Install

Extract zip, add folder to PATH, run:

```cmd
sdcv --data-dir=C:\stardict\dic word
```

DLLs must stay next to `sdcv.exe`.

## Patches

- Disable `mmap` on Windows
- `unistd.h` → `io.h` for MinGW
- Add `locale.h` for `setlocale()`
- `struct stat` → `GStatBuf` (GLib on Windows)
- `g_utf8_next_char` const fix (GLib 2.80+)
- Force `utf8_output` + `_setmode` for CJK display

## License

sdcv: GPLv2 | Build system: MIT
