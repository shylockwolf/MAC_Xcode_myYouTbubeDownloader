# MyYouTubeDownloader

A powerful and user-friendly macOS application built with SwiftUI that serves as a GUI wrapper for `yt-dlp`. It allows users to download YouTube videos and convert them to MP3 by simply pasting the URL.

![Version](https://img.shields.io/badge/version-2.4.2-blue.svg)
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
  - **Video Details**: View title, channel, publish time, duration, and direct links.
  - **Batch Copy**: Copy all subscription video URLs to clipboard at once.
- **Live Logs**: Real-time command execution logs with auto-scrolling terminal-like interface.
- **Download Records**: Track all completed downloads in a dedicated section.
- **Modern UI**: Clean sidebar layout with native macOS look and feel.
- **Auto-setup**: Automatically detects and uses `yt-dlp` from Homebrew or Python pip.
- **Cookie Support**: Uses Chrome cookies to access subscription feeds without manual login.
- **Weibo Support**: Handles Weibo short links (t.cn) and redirects automatically.
- **Log Management**: 
  - Text selection support for copying log content.
  - Retains up to 500 lines of download history.
  - Copy logs to clipboard with one click.

## 🛠 Prerequisites

Ensure you have the following installed on your Mac:

1. **macOS 15.6+**
2. **Homebrew** (Package Manager)
3. **yt-dlp** (Core downloader engine)
   ```bash
   brew install yt-dlp
   # Or via Python pip
   pip install yt-dlp
   ```
4. **ffmpeg** (Required for format merging and audio conversion)
   ```bash
   brew install ffmpeg
   ```
5. **Chrome Browser** (Required for YouTube subscription feature - must be logged into YouTube)

## 📦 Dependencies

| Dependency | Version | Purpose | Installation |
|------------|---------|---------|--------------|
| yt-dlp | Latest | YouTube video downloader engine | `brew install yt-dlp` or `pip install yt-dlp` |
| ffmpeg | Latest | Video/audio format conversion | `brew install ffmpeg` |
| Chrome | Any | Cookie extraction for YouTube subscriptions | [Download Chrome](https://www.google.com/chrome/) |

### Swift Frameworks (Built-in)
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for async operations
- **Foundation** - Core macOS APIs
- **AppKit** - macOS-specific UI and system integration

### Installation Paths
The application automatically searches for `yt-dlp` in the following locations:
- `/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp` (Python pip)
- `/opt/homebrew/bin/yt-dlp` (Homebrew on Apple Silicon)
- `/usr/local/bin/yt-dlp` (Homebrew on Intel Mac)
- System PATH (via `which yt-dlp`)

## 🏗️ Project Architecture

### File Structure
```
myYouTbubeDownloader/
├── myYouTbubeDownloader/
│   ├── myYouTbubeDownloader/
│   │   ├── myYouTbubeDownloaderApp.swift    # App entry point
│   │   ├── ContentView.swift                 # Main view with download UI
│   │   ├── SubscriptionsView.swift           # Subscription management UI
│   │   ├── Assets.xcassets/                  # App icons and assets
│   │   └── Info.plist                        # App configuration
│   └── myYouTbubeDownloader.xcodeproj/       # Xcode project file
└── README.md
```

### Key Components

#### 1. **myYouTbubeDownloaderApp.swift**
- Application entry point
- Configures window resizability
- Initializes ContentView as root view

#### 2. **ContentView.swift**
Main download interface featuring:
- **Task Management**: 9 video input slots with status tracking
- **Concurrent Downloads**: 3 parallel download channels with independent logs
- **Download Records**: Tracks completed downloads with filenames
- **Command Execution**: Handles yt-dlp process management
- **URL Processing**: Handles Weibo short links and redirects
- **Path Resolution**: Automatically detects yt-dlp installation

Key Features:
- Real-time log display with 500-line retention
- Status indicators for each download slot
- MP3 conversion toggle with thumbnail embedding
- Cancel and exit functionality
- Notification-based communication with subscription window

#### 3. **SubscriptionsView.swift**
YouTube subscription management featuring:
- **Video List**: Displays fetched subscription videos
- **Time Filtering**: Select videos from 12h/24h/36h/48h ranges
- **Video Details**: View title, channel, publish time, and URL
- **Batch Operations**: Copy all URLs or add to download queue
- **Execution Logs**: Real-time fetch progress with copy support

Key Components:
- `YouTubeSubscriptionsFetcher`: Fetches videos using yt-dlp with Chrome cookies
- `VideoItem`: Data model for video information
- `VideoListItem`: List item component with add button
- `VideoDetailView`: Detailed view with action buttons

### Data Flow

1. **Download Flow**:
   ```
   User Input URL → Add to Queue → Schedule Task → Execute yt-dlp → Monitor Progress → Complete → Update Records
   ```

2. **Subscription Flow**:
   ```
   Select Time → Click Start → Fetch via yt-dlp → Parse JSON → Display Videos → Add to Download Queue
   ```

3. **Notification System**:
   - `.addURLToDownload`: Send URL from subscription to main window
   - `.addURLResult`: Return add operation result
   - `.cleanupSubscriptions`: Clean up Combine subscriptions

### Threading Model
- **Main Thread**: UI updates, state management
- **Background Threads**: Process execution, log reading
- **Combine Publishers**: Reactive data flow for subscriptions
- **NotificationCenter**: Cross-window communication

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

### v2.4.2 (Current)
- **New Features**:
  - Added video duration display in subscription video list and details.
  - Duration is automatically extracted from YouTube API and formatted as MM:SS or HH:MM:SS.
- **Performance Improvements**:
  - Reduced subscription fetch video count from 20 to 10 for faster processing.
  - Increased subscription fetch timeout from 180s to 300s (5 minutes).
- **Bug Fixes**:
  - Fixed timeout issues in subscription fetching.
  - Added timeout protection for video downloads (10 minutes).
  - Improved timeout error messages with detailed troubleshooting suggestions.
  - Fixed potential duplicate completion callback issues.

### v2.4.1
- **Bug Fixes**:
  - Fixed YouTube download failures caused by JS challenge solving issues.
  - Added `--remote-components ejs:github` parameter to automatically download challenge solver scripts.
- **Improvements**:
  - Increased download log retention from 50 to 500 lines for better history tracking.
  - Users can now scroll back to view complete download process information.
  - Enhanced subscription window with batch copy functionality for all video URLs.
  - Added copy button for execution logs in subscription window.

### v2.4.0
- **New Features**:
  - Added text selection support for download logs - users can now select and copy log text.
  - Added Weibo short link support - automatically handles Weibo short links (t.cn) and redirects.
- **Improved Compatibility**:
  - Enhanced yt-dlp path detection - now supports both Python pip and Homebrew installations.
  - Checks multiple installation paths for better compatibility across different setups.
  - Added system PATH detection via `which yt-dlp` command.
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
  Check the "下载日志" (Download Log) on the right side for detailed error messages.

- **"Command not found"?** 
  The application automatically searches for `yt-dlp` in multiple locations:
  - `/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp` (Python pip)
  - `/opt/homebrew/bin/yt-dlp` (Homebrew on Apple Silicon)
  - `/usr/local/bin/yt-dlp` (Homebrew on Intel Mac)
  - System PATH (via `which yt-dlp`)
  
  If you still encounter issues, install yt-dlp using:
  ```bash
  # Via Homebrew
  brew install yt-dlp
  
  # Or via Python pip
  pip install yt-dlp
  ```

- **Subscription Fetch Fails?**
  - Make sure Chrome browser is installed and you're logged into YouTube.
  - Close all Chrome windows before fetching subscriptions.
  - Check that cookies are accessible.
  - Verify yt-dlp is properly installed and accessible.

- **Weibo Videos Not Downloading?**
  - The app automatically handles Weibo short links (t.cn) and redirects.
  - If issues persist, check the download logs for specific error messages.

- **JS Challenge Errors?**
  - The app uses `--remote-components ejs:github` to automatically download challenge solver scripts.
  - Ensure you have an active internet connection when downloading.

- **App Won't Start?**
  - Ensure you're running macOS 15.6 or later.
  - Check that all required permissions are granted in System Preferences.

- **Memory/Performance Issues?**
  - The app limits log retention to 500 lines per download channel.
  - Old logs are automatically removed when the limit is exceeded.

## 📄 License

[MIT License](LICENSE)
