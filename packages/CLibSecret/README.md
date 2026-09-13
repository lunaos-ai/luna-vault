# CLibSecret

Optional Linux Secret Service access for the vault master key.

The C shim `dlopen`s `libsecret-1.so.0` at runtime. If libsecret (or a
session keyring) is missing, VaultCore falls back to a mode-`0600` file.
Linux builds do not link libsecret, so the CLI still starts on headless hosts.
