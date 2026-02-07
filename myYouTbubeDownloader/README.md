# MyYouTubeDownloader

A powerful and user-friendly macOS application built with SwiftUI that serves as a GUI wrapper for `yt-dlp`. It allows users to download YouTube videos and convert them to MP3 by simply pasting the URL.

![Version](https://img.shields.io/badge/version-1.6-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

## ✨ Features

- **Batch Downloading**: Support for inputting up to 5 video URLs simultaneously.
- **Smart Status Indicators**: 
  - Real-time progress monitoring.
  - **Green Checkmark (✓)**: Visual confirmation for successfully completed downloads.
- **Format Conversion**: 
  - **Video**: Download best quality video.
  - **MP3**: One-click toggle to convert videos to MP3 format with embedded thumbnails.
- **Live Logs**: Real-time command execution logs with auto-scrolling terminal-like interface.
- **Modern UI**: Clean sidebar layout with native macOS look and feel.
- **Auto-setup**: Automatically detects and uses `yt-dlp` from Homebrew.

## 🛠 Prerequisites

Ensure you have the following installed on your Mac:

1. **macOS 12.0+**
2. **Homebrew** (Package Manager)
3. **yt-dlp** (Core downloader engine)
   ```bash
   brew install yt-dlp
   ```
4. **ffmpeg** (Required for format merging and audio conversion)
   ```bash
   brew install ffmpeg
   ```

## 🚀 Installation & Usage

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/myYouTbubeDownloader.git
   ```

2. **Open in Xcode**:
   Double-click `myYouTbubeDownloader.xcodeproj`.

3. **Build and Run**:
   Press `Command + R` to launch the application.

4. **How to Use**:
   - Paste YouTube video URLs into the input fields (Video 1 to Video 5).
   - Toggle "转换成 mp3" if you want audio only.
   - Click "**开始下载**" (Start Download).
   - Watch the logs for progress.
   - Once finished, a **Green Checkmark (✓)** will appear next to the completed video.
   - Files are saved to your `Downloads` folder.

## 📝 Version History

### v1.6 (Current)
- Implemented parallel downloading (up to 3 concurrent tasks).
- Redesigned log interface with 3 independent slot windows.
- Enhanced UI with custom blue borders and improved layout.
- Added visual success indicator (Green Checkmark).

### v1.5

### v1.2
- Initial release with batch download support.
- Added MP3 conversion toggle.
- Implemented real-time log viewer.

## ⚠️ Troubleshooting

- **Download Fails?** 
  Check the "运行日志" (Run Log) on the right side.
- **"Command not found"?** 
  Ensure `yt-dlp` is installed at `/opt/homebrew/bin/yt-dlp`. If you use an Intel Mac, you might need to adjust the path in the source code (`ContentView.swift`).

## 📄 License

[MIT License](LICENSE)
