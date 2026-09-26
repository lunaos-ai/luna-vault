# Resolve CLI_BIN and MCP_BIN after a Linux release build.
# Source from packaging scripts. Requires ROOT. Leaves env vars set if already executable.
if [[ -n "${CLI_BIN:-}" && -x "$CLI_BIN" && -n "${MCP_BIN:-}" && -x "$MCP_BIN" ]]; then
  :
else
  _VV_BIN="$(cd "${ROOT:?}" && swift build -c release --show-bin-path)"
  CLI_BIN="${CLI_BIN:-$_VV_BIN/vibevault}"
  MCP_BIN="${MCP_BIN:-$_VV_BIN/vibevault-mcp}"
  unset _VV_BIN
fi
