# sdcv-windows-build

Native MinGW64 build of [sdcv](https://github.com/Dushistov/sdcv), with runtime DLLs bundled.

Authors: DeepSeek-V4🧙‍♂️, scillidan🤡

## Patches

- Disable `mmap` on Windows
- `unistd.h` → `io.h` for MinGW
- Add `locale.h` for `setlocale()`
- `struct stat` → `GStatBuf` (GLib on Windows)
- `g_utf8_next_char` const fix (GLib 2.80+)
- Force `utf8_output` + `_setmode` for CJK display

## Build

```cmd
scoop install msys2
git clone https://github.com/scillidan/sdcv-windows-build
cd sdcv-windows-build
mingw64
```

```bash
pacman -S --needed \
  mingw-w64-x86_64-{gcc,cmake,glib2,zlib,pcre2,gettext} \
  git make zip
make dist
```