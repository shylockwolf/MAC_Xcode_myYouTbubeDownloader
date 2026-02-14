//
//  SubscriptionsView.swift
//  myYouTbubeDownloader
//
//  Created by Shylock Wolf on 2026/2/14.
//

import SwiftUI
import Foundation
import Combine

struct SubscriptionsView: View {
    @State private var videos: [VideoItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var logs: [String] = []
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        HSplitView {
            // 左侧：视频列表
            videoListView
            
            VStack(spacing: 0) {
                // 右侧：视频详情和日志
                HSplitView {
                    // 上半部分：视频详情
                    if let selectedVideo = videos.first(where: { $0.isSelected }) {
                        VideoDetailView(video: selectedVideo)
                    } else {
                        EmptyDetailView()
                    }
                    
                    // 下半部分：日志面板
                    logsPanelView
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 700)
        .background(.windowBackground)
        .onAppear {
            fetchSubscriptions()
        }
    }
    
    // MARK: - 视频列表视图
    private var videoListView: some View {
        VStack(spacing: 0) {
            // 标题区域
            listHeader
            
            Divider()
            
            // 视频列表
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error: error)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($videos) { $video in
                            VideoListItem(video: $video)
                                .onTapGesture {
                                    // 取消其他视频的选择状态
                                    for index in videos.indices {
                                        videos[index].isSelected = false
                                    }
                                    // 选中当前视频
                                    video.isSelected = true
                                }
                        }
                    }
                    .padding(16)
                }
            }
            
            Divider()
            
            // 底部控制栏
            bottomControlBar
        }
        .frame(minWidth: 400, maxWidth: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 列表标题
    private var listHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("YouTube 订阅")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if let updated = lastUpdated {
                        Text("最后更新: \(formattedDate(updated))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("48小时内的视频")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: fetchSubscriptions) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("正在获取订阅内容...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - 错误视图
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title)
                .foregroundStyle(.red)
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: fetchSubscriptions) {
                Text("重试")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 80, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - 底部控制栏
    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("共 \(videos.count) 个视频")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: {
                    // 复制所有链接到剪贴板
                    let links = videos.map { $0.url }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(links, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                    Text("复制所有链接")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(videos.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
    
    // MARK: - 获取订阅内容
    private func fetchSubscriptions() {
        isLoading = true
        errorMessage = nil
        logs.removeAll()
        
        // 订阅日志更新
        YouTubeSubscriptionsFetcher.shared.$logs
            .receive(on: DispatchQueue.main)
            .sink { newLogs in
                self.logs = newLogs
            }
            .store(in: &cancellables)
        
        YouTubeSubscriptionsFetcher.shared.fetchVideos()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoading = false
                switch completion {
                case .finished:
                    lastUpdated = Date()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    logs.append("错误: \(error.localizedDescription)")
                }
            }, receiveValue: { fetchedVideos in
                videos = fetchedVideos
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 日期格式化
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - 日志面板视图
    private var logsPanelView: some View {
        VStack(spacing: 0) {
            // 面板标题
            HStack(spacing: 10) {
                Image(systemName: "terminal")
                    .font(.system(size: 13))
                Text("执行日志")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                
                // 复制按钮
                Button(action: {
                    let logText = logs.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logText, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                    Text("复制日志")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(logs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            
            Divider()
            
            // 日志内容
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if logs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 16))
                                .foregroundStyle(.tertiary)
                            Text("无日志信息")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding(.vertical, 20)
                    } else {
                        // 使用文本视图支持选择和复制
                        TextEditor(text: .constant(logs.joined(separator: "\n")))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .frame(minHeight: 200)
                            .disabled(true) // 只读
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 视频列表项
struct VideoListItem: View {
    @Binding var video: VideoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 视频标题
            Text(video.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(video.isSelected ? Color.accentColor : .primary)
                .lineLimit(2)
            
            // 视频信息
            HStack(spacing: 12) {
                Text(video.channel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text(video.publishTime)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            // 视频链接
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(video.url)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(video.isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(video.isSelected ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - 视频详情视图
struct VideoDetailView: View {
    let video: VideoItem
    
    var body: some View {
        VStack(spacing: 0) {
            // 详情标题
            detailHeader
            
            Divider()
            
            // 详情内容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 视频信息卡片
                    infoCard
                    
                    // 操作按钮
                    actionButtons
                }
                .padding(24)
            }
        }
        .frame(minWidth: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var detailHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "video.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
            Text("视频详情")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text(video.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            
            // 频道信息
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(video.channel)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            // 发布时间
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(video.publishTime)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            // 视频链接
            VStack(alignment: .leading, spacing: 4) {
                Text("视频链接:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack {
                    Text(video.url)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(video.url, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                // 打开视频链接
                if let url = URL(string: video.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 14))
                    Text("在浏览器中打开")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: {
                // 复制链接到剪贴板
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(video.url, forType: .string)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                    Text("复制链接")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - 空详情视图
struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("请选择一个视频查看详情")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 视频项模型
struct VideoItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let channel: String
    let url: String
    let publishTime: String
    let publishDate: Date
    var isSelected: Bool = false
    
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - YouTube订阅获取器
class YouTubeSubscriptionsFetcher {
    static let shared = YouTubeSubscriptionsFetcher()
    
    // 日志信息
    @Published var logs: [String] = []
    
    private init() {}
    
    func fetchVideos() -> AnyPublisher<[VideoItem], Error> {
        return Future<[VideoItem], Error> { [weak self] promise in
            guard let self = self else { return }
            
            // 清空之前的日志
            self.logs.removeAll()
            self.logs.append("开始获取YouTube订阅内容...")
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 检查yt-dlp是否存在
                    try self.checkYtDlpExists()
                    
                    // 使用yt-dlp获取cookie并访问订阅页面
                    let subscriptionsPage = try self.fetchSubscriptionsPage()
                    
                    // 解析页面内容，提取视频信息
                    let videos = try self.parseVideos(from: subscriptionsPage)
                    
                    // 过滤出48小时内的视频
                    let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 60 * 60)
                    let recentVideos = videos.filter { $0.publishDate >= fortyEightHoursAgo }
                    
                    // 按发布时间排序（最新的在前）
                    let sortedVideos = recentVideos.sorted(by: { $0.publishDate > $1.publishDate })
                    
                    self.logs.append("成功获取到 \(sortedVideos.count) 个48小时内的视频")
                    promise(.success(sortedVideos))
                } catch {
                    self.logs.append("错误: \(error.localizedDescription)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 检查yt-dlp是否存在
    private func checkYtDlpExists() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var exists = false
        var output: String = ""
        var errorOutput: String = ""
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // 直接使用绝对路径检查
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "echo $PATH && which yt-dlp && ls -la \(ytDlpPath)"]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 读取标准输出
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let string = String(data: data, encoding: .utf8) {
                output += string
            }
        }
        
        // 读取错误输出
        let errorHandle = errorPipe.fileHandleForReading
        errorHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let string = String(data: data, encoding: .utf8) {
                errorOutput += string
            }
        }
        
        process.terminationHandler = { _ in
            semaphore.signal()
        }
        
        logs.append("检查yt-dlp是否存在...")
        
        do {
            try process.run()
            semaphore.wait()
        } catch {
            logs.append("检查过程出错: \(error.localizedDescription)")
            throw error
        }
        
        // 记录输出信息
        if !output.isEmpty {
            logs.append("检查输出: \(output)")
        }
        if !errorOutput.isEmpty {
            logs.append("检查错误: \(errorOutput)")
        }
        
        // 直接检查文件是否存在
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: ytDlpPath) {
            exists = true
            logs.append("yt-dlp 已找到: \(ytDlpPath)")
        } else {
            logs.append("yt-dlp 未找到: \(ytDlpPath)")
        }
        
        guard exists else {
            throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 2, userInfo: [NSLocalizedDescriptionKey: "yt-dlp 未找到，请先安装: brew install yt-dlp"])
        }
    }
    
    // MARK: - 获取订阅页面内容
    private func fetchSubscriptionsPage() throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var output: String = ""
        var errorOutput: String = ""
        var processError: Error?
        var terminationStatus: Int32 = -1
        
        // 使用yt-dlp获取订阅页面内容，通过cookie绕过登录
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // 直接使用绝对路径
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOME"] = NSHomeDirectory()
        process.environment = environment
        
        process.arguments = [
            "--cookies-from-browser", "chrome",
            "--dump-json",
            "--skip-download",
            "--no-warnings",
            "--ignore-errors",
            "--format", "worst",
            "--playlist-items", "1:20",
            "https://www.youtube.com/feed/subscriptions"
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 读取标准输出
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                return
            }
            if let string = String(data: data, encoding: .utf8) {
                output += string
                self.logs.append("[输出] \(string.prefix(200))\(string.count > 200 ? "..." : "")")
            } else {
                self.logs.append("[输出] 收到 \(data.count) 字节数据（无法解码为UTF-8）")
            }
        }
        
        // 读取错误输出
        let errorHandle = errorPipe.fileHandleForReading
        errorHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                return
            }
            if let string = String(data: data, encoding: .utf8) {
                errorOutput += string
                self.logs.append("[错误] \(string)")
            } else {
                self.logs.append("[错误] 收到 \(data.count) 字节数据（无法解码为UTF-8）")
            }
        }
        
        process.terminationHandler = { process in
            terminationStatus = process.terminationStatus
            self.logs.append("命令执行完成，退出状态: \(process.terminationStatus)")
            semaphore.signal()
        }
        
        self.logs.append("执行命令: \(ytDlpPath) --cookies-from-browser chrome --dump-json --skip-download --no-warnings --ignore-errors --format worst --playlist-items 1:20 https://www.youtube.com/feed/subscriptions")
        self.logs.append("命令开始执行...")
        
        do {
            try process.run()
            self.logs.append("命令已启动，PID: \(process.processIdentifier)")
            
            // 设置超时时间为180秒（3分钟）
            let timeoutResult = semaphore.wait(timeout: .now() + 180)
            
            if timeoutResult == .timedOut {
                self.logs.append("命令执行超时（180秒），强制终止...")
                process.terminate()
                throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 3, userInfo: [NSLocalizedDescriptionKey: "命令执行超时，请检查网络连接或cookie是否有效"])
            }
            
            self.logs.append("命令执行完成，退出状态: \(terminationStatus)")
        } catch let runError {
            processError = runError
            self.logs.append("命令执行失败: \(runError.localizedDescription)")
        }
        
        // 关闭文件句柄
        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil
        
        // 记录输出和错误信息
        self.logs.append("命令标准输出总长度: \(output.count) 字符")
        self.logs.append("命令错误输出总长度: \(errorOutput.count) 字符")
        
        if !errorOutput.isEmpty {
            // 只显示前500个字符，避免日志过长
            let truncatedError = errorOutput.prefix(500) + (errorOutput.count > 500 ? "..." : "")
            self.logs.append("命令错误输出: \(truncatedError)")
        }
        
        if let error = processError {
            throw error
        }
        
        guard !output.isEmpty else {
            throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch subscriptions page, no output received"])
        }
        
        self.logs.append("成功获取订阅页面内容，开始解析...")
        return output
    }
    
    // MARK: - 解析视频信息
    private func parseVideos(from jsonOutput: String) throws -> [VideoItem] {
        var videos: [VideoItem] = []
        
        // 分割JSON输出，每行一个视频
        let lines = jsonOutput.components(separatedBy: .newlines)
        
        self.logs.append("开始解析 \(lines.count) 行JSON数据...")
        
        for (index, line) in lines.enumerated() where !line.isEmpty {
            do {
                let data = line.data(using: .utf8)!
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                guard let videoJSON = json else {
                    self.logs.append("第 \(index + 1) 行: 无法解析为JSON")
                    continue
                }
                
                // 提取视频信息 - 适应flat-playlist格式
                if let title = videoJSON["title"] as? String,
                   let url = videoJSON["webpage_url"] as? String ?? videoJSON["url"] as? String,
                   let videoId = videoJSON["id"] as? String {
                    
                    // 获取频道名称（可能不存在）
                    let channel = videoJSON["uploader"] as? String ?? videoJSON["channel"] as? String ?? "未知频道"
                    
                    // 获取时间戳（flat-playlist模式下可能为null）
                    let timestamp = videoJSON["timestamp"] as? TimeInterval
                    let publishDate: Date
                    let publishTime: String
                    
                    if let ts = timestamp {
                        publishDate = Date(timeIntervalSince1970: ts)
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        publishTime = formatter.string(from: publishDate)
                    } else {
                        // 如果没有时间戳，使用当前时间
                        publishDate = Date()
                        publishTime = "刚刚"
                    }
                    
                    videos.append(VideoItem(
                        title: title,
                        channel: channel,
                        url: url,
                        publishTime: publishTime,
                        publishDate: publishDate
                    ))
                    
                    self.logs.append("成功解析: \(title.prefix(50))...")
                } else {
                    self.logs.append("第 \(index + 1) 行: 缺少必要字段 (title, url, id)")
                }
            } catch {
                self.logs.append("第 \(index + 1) 行: 解析错误 - \(error.localizedDescription)")
                continue
            }
        }
        
        self.logs.append("成功解析出 \(videos.count) 个视频")
        return videos
    }
}

#Preview {
    SubscriptionsView()
        .frame(width: 1000, height: 600)
}
