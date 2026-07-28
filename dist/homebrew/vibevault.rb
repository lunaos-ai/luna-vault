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
  version "0.1.1"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/lunaos-ai/luna-vault/releases/download/v0.1.1/vibevault_0.1.1_darwin_arm64.tar.gz"
    sha256 "e22e7b2141fc99a7cfd94b285e1e06a8475782b7da19ac044ef3217290af619e"
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
    assert_match "0.1.1", shell_output("#{bin}/vibevault --version")
  end
end
