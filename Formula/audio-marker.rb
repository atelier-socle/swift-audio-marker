# Homebrew formula for audio-marker
#
# Tap: atelier-socle/homebrew-tools
# Install: brew install atelier-socle/tools/audio-marker

class AudioMarker < Formula
  desc "CLI tool for reading, writing, and converting audio metadata and chapter markers"
  homepage "https://github.com/atelier-socle/swift-audio-marker"
  url "https://github.com/atelier-socle/swift-audio-marker/archive/refs/tags/0.1.0.tar.gz"
  sha256 "UPDATE_SHA256_AFTER_RELEASE"
  license "MIT"

  depends_on xcode: ["26.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/audio-marker"
  end

  test do
    system "#{bin}/audio-marker", "info", "--help"
  end
end
