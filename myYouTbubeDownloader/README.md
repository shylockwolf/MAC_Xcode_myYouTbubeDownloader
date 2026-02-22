# MyYouTubeDownloader

A powerful and user-friendly macOS application built with SwiftUI that serves as a GUI wrapper for `yt-dlp`. It allows users to download YouTube videos and convert them to MP3 by simply pasting the URL.

![Version](https://img.shields.io/badge/version-2.4.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

## ✨ Features

- **Batch Downloading**: Support for inputting up to 9 video URLs simultaneously.
- **Concurrent Downloads**: 3 parallel download channels for faster processing.
- **Smart Status Indicators**: 
  - Real-time progress monitoring for each download channel.
  - Visual status icons for each video slot (ready, downloading, completed).
- **Format Conversion**: 
  - **Video**: Download best quality video.
  - **MP3**: One-click toggle to convert videos to MP3 format with embedded thumbnails.
- **YouTube Subscriptions**: 
  - **One-click Fetching**: Quickly fetch recent videos from your YouTube subscriptions.
  - **Flexible Time Ranges**: Filter videos from the last 12, 24, 36, or 48 hours.
  - **Direct Add**: Add subscription videos to the download queue with one click.
  - **Video Details**: View title, channel, publish time, and direct links.
- **Live Logs**: Real-time command execution logs with auto-scrolling terminal-like interface.
- **Download Records**: Track all completed downloads in a dedicated section.
- **Modern UI**: Clean sidebar layout with native macOS look and feel.
- **Auto-setup**: Automatically detects and uses `yt-dlp` from Homebrew.
- **Cookie Support**: Uses Chrome cookies to access subscription feeds without manual login.

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
5. **Chrome Browser** (Required for YouTube subscription feature - must be logged into YouTube)

## 📦 Dependencies

| Dependency | Version | Purpose | Installation |
|------------|---------|---------|--------------|
| yt-dlp | Latest | YouTube video downloader engine | `brew install yt-dlp` |
| ffmpeg | Latest | Video/audio format conversion | `brew install ffmpeg` |
| Chrome | Any | Cookie extraction for YouTube subscriptions | [Download Chrome](https://www.google.com/chrome/) |

### Swift Frameworks (Built-in)
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for async operations
- **Foundation** - Core macOS APIs

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
   - Paste YouTube video URLs into the input fields (Video 1 to Video 9).
   - Or click "**查看订阅**" (View Subscriptions) to fetch and add videos from your YouTube feed.
   - Toggle "转换为 MP3 格式" if you want audio only.
   - Click "**开始下载**" (Start Download).
   - Watch the logs for progress in the 3 download channels.
   - Files are saved to your `Downloads` folder.
   - Use "**取消下载**" (Cancel Download) to stop ongoing downloads.
   - Use "**退出应用**" (Exit App) to close the application.

## 📝 Version History

### v2.4.0 (Current)
- **New Features**:
  - Added text selection support for download logs - users can now select and copy log text.
  - Added Weibo short link support - automatically handles Weibo short links (t.cn) and redirects.
- **Improved Compatibility**:
  - Enhanced yt-dlp path detection - now supports both Python pip and Homebrew installations.
  - Checks multiple installation paths for better compatibility across different setups.
- **Bug Fixes**:
  - Fixed URL handling for Weibo videos that redirect through visitor pages.

### v2.2.1
- **New Features**:
  - Added text selection support for download logs - users can now select and copy log text.
  - Added Weibo short link support - automatically handles Weibo short links (t.cn) and redirects.
- **Improved Compatibility**:
  - Enhanced yt-dlp path detection - now supports both Python pip and Homebrew installations.
  - Checks multiple installation paths for better compatibility across different setups.
- **Bug Fixes**:
  - Fixed URL handling for Weibo videos that redirect through visitor pages.

### v2.2.0
- **UI Optimizations**:
  - Redesigned subscription window layout with two-row header.
  - Reduced window widths for better screen utilization.
  - Three download channels now equally share available height.
  - Added "开始" button for manual fetch control.
- **Improved UX**:
  - Time selection buttons (12h/24h/36h/48h) only change selection, not auto-fetch.
  - Added success notification when adding URL to download slot (auto-dismiss after 2s).
  - Removed empty state placeholder when no video selected.
- **Code Quality**:
  - Added .gitignore for Xcode user state files.
  - Fixed deprecated onChange syntax.

### v2.1.0
- **Expanded Capacity**: Increased from 5 to 9 video input slots.
- **Concurrent Downloads**: Added 3 parallel download channels with independent logs.
- **UI Improvements**:
  - Redesigned button layout with text labels ("查看订阅", "取消下载", "开始下载", "退出应用").
  - Added download records section to track completed downloads.
  - Improved log panel heights for better visibility.
  - Status bar now pushed to bottom of window.
- **Subscription Window**:
  - Fixed crash issues when closing the subscription window.
  - Improved auto-scrolling for execution logs.
  - Better resource cleanup and process management.
- **Stability**: Enhanced thread safety and memory management.

### v2.0.0
- **Major Update**: Rebranded and improved stability.
- **Subscription Management**: Fully implemented YouTube subscription fetching with Chrome cookie support.
- **UI/UX Enhancements**:
  - New subscription window with detailed video information.
  - Improved log display using high-performance `LazyVStack`.
  - Added smooth auto-scrolling for logs.
- **Stability Fixes**:
  - Fixed issues where closing the subscription window might cause the main app to crash.
  - Enhanced thread safety for background processes and UI updates.
  - Added robust process cleanup and resource management.

### v1.6.3
- Added quick exit button for convenient application closure.

### v1.6.1
- Unified versioning.
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
  Check the "下载日志" (Download Log) on the right side.
- **"Command not found"?** 
  Ensure `yt-dlp` is installed at `/opt/homebrew/bin/yt-dlp`. If you use an Intel Mac, you might need to adjust the path in the source code (`ContentView.swift`).
- **Subscription Fetch Fails?**
  - Make sure Chrome browser is installed and you're logged into YouTube.
  - Close all Chrome windows before fetching subscriptions.
  - Check that cookies are accessible.

## 📄 License

[MIT License](LICENSE)
