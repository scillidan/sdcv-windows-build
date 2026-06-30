# sdcv-windows-build

Native MinGW64 build of [sdcv](https://github.com/Dushistov/sdcv), with runtime DLLs bundled.

Authors: DeepSeek-V4🧙‍♂️, scillidan🤡

## Patches

- Disable `mmap` on Windows
- `unistd.h` → `io.h` for MinGW
- Add `locale.h` for `setlocale()`
- `struct stat` → `GStatBuf` (GLib on Windows)
- `g_utf8_next_char` const fix (GLib 2.80+)
- Sync console output CP + `_O_BINARY` stdout (fix CJK mojibake)

## Build

```cmd
scoop install msys2
git clone https://github.com/scillidan/sdcv-windows-build
cd sdcv-windows-build
"%SCOOP%\apps\msys2\current\msys2_shell.cmd" -mingw64 -defterm -here -no-start
```

```bash
pacman -S --needed \
  mingw-w64-x86_64-{gcc,cmake,glib2,zlib,pcre2,gettext} \
  git make zip
make dist
```

## Dictionary Search Path Resolution

`sdcv` looks for dictionaries in the following locations, in order of precedence:

| Source                      | Path                                                                         |
| :-                          | :-                                                                           |
| `--only-data-dir` (`-x`)    | Use **only** this directory; skip all defaults                               |
| `--data-dir`                | Append a custom directory to the search list                                 |
| `STARDICT_DATA_DIR`         | Override the system directory                                                |
| User directory              | Linux: `~/.stardict/dic` · Windows: `%USERPROFILE%\.stardict\dic`            |
| System directory (fallback) | Linux: `/usr/share/stardict/dic` · Windows: same (hardcoded, usually absent) |

> **Note:** If `STARDICT_DATA_DIR` points to the same path as your user directory, every dictionary will be loaded twice and lookup results will appear duplicated. Unset the environment variable to resolve this.