# typed: false
# frozen_string_literal: true

# Homebrew formula for vibe-vault CLI + MCP/browser helpers.
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

  if Hardware::CPU.arm?
    url "https://github.com/lunaos-ai/luna-vault/releases/download/v0.1.0/vibevault_0.1.0_darwin_arm64.tar.gz"
    sha256 "e1cb25342a6bef84680312fd058b69940ff14f7c7379bc6233202a2c63d8879b"
  end

  head "https://github.com/lunaos-ai/luna-vault.git", branch: "main"

  depends_on macos: :sonoma

  def install
    if build.head?
      system "swift", "build", "-c", "release", "--product", "vibevault"
      system "swift", "build", "-c", "release", "--product", "vibevault-mcp"
      system "swift", "build", "-c", "release", "--product", "vibevault-browser-host"
      bin.install ".build/release/vibevault"
      bin.install ".build/release/vibevault-mcp"
      bin.install ".build/release/vibevault-browser-host"
    else
      odie "Stable binary is currently available for Apple Silicon Macs only. Use --HEAD to build from source." unless Hardware::CPU.arm?
      bin.install "vibevault"
      bin.install "vibevault-mcp"
      bin.install "vibevault-browser-host"
    end
  end

  def caveats
    <<~EOS
      Install the menu-bar app (notarized DMG):
        open https://vibevault.lunaos.ai/download

      Wire Cursor / VS Code MCP:
        vibevault mcp install --client all
        vibevault skill install
        vibevault cursor prepare
        vibevault browser install --browser chrome --extension-id nfeigikipagiccmhlolgfbeienkckbpc
    EOS
  end

  test do
    assert_match "0.1.0", shell_output("#{bin}/vibevault --version")
  end
end
