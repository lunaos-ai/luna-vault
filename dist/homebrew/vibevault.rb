# typed: false
# frozen_string_literal: true

# Homebrew formula for vibe-vault CLI + MCP helper.
# Install (when published to the tap):
#   brew tap finsavvyai/tap
#   brew install vibevault
#
# Or from this repo during GTM:
#   brew install --formula ./dist/homebrew/vibevault.rb

class Vibevault < Formula
  desc "Local-first macOS secrets for AI coding — Keychain, MCP audit, provider sync"
  homepage "https://vibevault.lunaos.ai/"
  version "0.1.0"
  license "MIT"

  url "https://github.com/lunaos-ai/luna-vault/archive/v0.1.0.tar.gz"
  sha256 "8d1b78fc78f3e57268e39d162e7a3b42960face16d906df52a86dae843df1f43"

  head "https://github.com/lunaos-ai/luna-vault.git", branch: "main"

  on_macos do
    depends_on xcode: ["15.0", :build]
  end

  depends_on macos: :sonoma

  def install
    system "swift", "build", "-c", "release", "--product", "vibevault"
    system "swift", "build", "-c", "release", "--product", "vibevault-mcp"
    bin.install ".build/release/vibevault"
    bin.install ".build/release/vibevault-mcp"
  end

  def caveats
    <<~EOS
      Install the menu-bar app (notarized DMG):
        open https://vibevault.lunaos.ai/download

      Wire Cursor / VS Code MCP:
        vibevault mcp install --client all
        vibevault skill install
        vibevault cursor prepare
    EOS
  end

  test do
    assert_match "0.1.0", shell_output("#{bin}/vibevault --version")
  end
end
