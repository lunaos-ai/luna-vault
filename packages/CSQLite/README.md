# CSQLite (Windows)

Native Windows builds compile SQLite from the official amalgamation.

Run before `swift build` on Windows:

```powershell
powershell -File scripts/ensure-sqlite-windows.ps1
```

`scripts/build-windows.ps1` does this automatically.

Linux continues to use system `libsqlite3-dev`. macOS uses the SDK sqlite3.
