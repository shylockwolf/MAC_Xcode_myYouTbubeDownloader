# MyYouTubeDownloader

A macOS application built with SwiftUI that serves as a GUI wrapper for `yt-dlp`. It allows users to download YouTube videos by simply pasting the URL.

## Features

- **Batch Downloading**: Support for up to 5 concurrent video downloads.
- **Auto-setup**: Automatically detects and uses `yt-dlp` from Homebrew.
- **Live Logs**: Real-time command execution logs with auto-scrolling.
- **Modern UI**: Sidebar navigation and native macOS look and feel.

## Prerequisites

- macOS 12.0+
- [Homebrew](https://brew.sh/)
- `yt-dlp` installed via Homebrew:
  ```bash
  brew install yt-dlp
  ```
- `ffmpeg` (optional but recommended for format merging):
  ```bash
  brew install ffmpeg
  ```

## Installation

1. Clone the repository.
2. Open `myYouTbubeDownloader.xcodeproj` in Xcode.
3. Build and Run (Command + R).

## Usage

1. Paste YouTube video URLs into the input fields.
2. Click "开始下载" (Start Download).
3. Monitor progress in the "运行日志" (Run Log) panel.
4. Downloaded videos will appear in your `Downloads` folder.

## License

[MIT License](LICENSE)
