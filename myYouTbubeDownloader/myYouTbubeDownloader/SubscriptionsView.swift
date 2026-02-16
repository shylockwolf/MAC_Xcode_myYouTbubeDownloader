//
//  SubscriptionsView.swift
//  myYouTbubeDownloader
//
//  Created by Shylock Wolf on 2026/2/14.
//

import SwiftUI
import Foundation
import Combine

// 通知名称 - 用于传递URL到主窗口
extension Notification.Name {
    static let addURLToDownload = Notification.Name("addURLToDownload")
    static let addURLResult = Notification.Name("addURLResult")
}

struct SubscriptionsView: View {
    @State private var videos: [VideoItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var logs: [String] = []
    @State private var selectedHours: Int = 36
    @State private var addResultMessage: String?
    @State private var showAddResult: Bool = false
    @State private var addedURLSet: Set<String> = []
    
    @State private var cancellables = Set<AnyCancellable>()
    
    let hourOptions = [12, 24, 36, 48]
    
    var body: some View {
        HSplitView {
            // 左侧：视频列表
            videoListView
            
            // 右侧：视频详情和日志
            VStack(spacing: 0) {
                if let selectedVideo = videos.first(where: { $0.isSelected }) {
                    // 上半部分：视频详情
                    VideoDetailView(video: selectedVideo, isAdded: addedURLSet.contains(selectedVideo.url))
                    
                    Divider()
                }
                
                // 下半部分：日志面板
                logsPanelView
            }
        }
        .frame(minWidth: 840, minHeight: 700)
        .background(.windowBackground)
        .onReceive(NotificationCenter.default.publisher(for: .addURLResult)) { notification in
            if let result = notification.userInfo?["result"] as? String {
                addResultMessage = result
                withAnimation {
                    showAddResult = true
                }
            }
            if let url = notification.userInfo?["url"] as? String,
               let result = notification.userInfo?["result"] as? String,
               result.contains("已添加到下载位置") {
                addedURLSet.insert(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("cleanupSubscriptions"))) { _ in
            // 清理所有Combine订阅
            cancellables.removeAll()
        }
        .overlay(
            Group {
                if showAddResult, let message = addResultMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: message.contains("失败") ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(message.contains("失败") ? .red : .green)
                            Text(message)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showAddResult = false
                            }
                        }
                    }
                }
            }
        )
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
            } else if videos.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($videos) { $video in
                            VideoListItem(video: $video, isAdded: addedURLSet.contains(video.url))
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
        .frame(minWidth: 300, maxWidth: 375)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 列表标题
    private var listHeader: some View {
        VStack(spacing: 8) {
            // 第一行：标题
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
                        Text("\(selectedHours)小时内的视频")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 第二行：时间选择器和开始按钮
            HStack(spacing: 6) {
                ForEach(hourOptions, id: \.self) { hours in
                    Button(action: {
                        selectedHours = hours
                    }) {
                        Text("\(hours)h")
                            .font(.system(size: 11, weight: selectedHours == hours ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedHours == hours ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(selectedHours == hours ? .white : .secondary)
                            .cornerRadius(4)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
                
                // 开始获取按钮
                Button(action: fetchSubscriptions) {
                    Text("开始")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("准备就绪")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
            
            Text("选择时间范围后点击「开始」按钮获取订阅视频")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
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
        
        // 清理旧的订阅
        cancellables.removeAll()
        
        // 订阅日志更新
        YouTubeSubscriptionsFetcher.shared.$logs
            .receive(on: DispatchQueue.main)
            .sink { newLogs in
                self.logs = newLogs
            }
            .store(in: &cancellables)
        
        YouTubeSubscriptionsFetcher.shared.fetchVideos(hours: selectedHours)
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
            
            // 日志内容 - 自动滚屏
            ScrollViewReader { proxy in
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
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                }
                                Color.clear.frame(height: 1).id("logBottom")
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(minHeight: 200)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .onChange(of: logs.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 140, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 视频列表项
struct VideoListItem: View {
    @Binding var video: VideoItem
    let isAdded: Bool
    
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
            
            // 视频链接 + 添加按钮
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(video.url)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                
                Spacer()
                
                // 添加到下载列表按钮
                Button(action: {
                    NotificationCenter.default.post(
                        name: .addURLToDownload,
                        object: nil,
                        userInfo: ["url": video.url]
                    )
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text(isAdded ? "成功添加" : "添加")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isAdded ? Color.gray.opacity(0.15) : Color.accentColor.opacity(0.15)))
                    .foregroundColor(isAdded ? .secondary : .accentColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(isAdded)
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
    let isAdded: Bool
    
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
        .frame(minWidth: 250)
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
                // 发送通知，将URL添加到主窗口的下载列表
                NotificationCenter.default.post(
                    name: .addURLToDownload,
                    object: nil,
                    userInfo: ["url": video.url]
                )
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text(isAdded ? "成功添加" : "添加到下载列表")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(isAdded ? .gray : .accentColor)
            .disabled(isAdded)
            
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
            .buttonStyle(.bordered)
            
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
class YouTubeSubscriptionsFetcher: ObservableObject {
    static let shared = YouTubeSubscriptionsFetcher()
    
    // 日志信息
    @Published var logs: [String] = []
    
    // 取消令牌
    private var cancellationToken: Bool = false
    
    // 当前运行的Process
    private var currentProcess: Process?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    
    private init() {}
    
    func appendLog(_ message: String) {
        DispatchQueue.main.async {
            self.logs.append(message)
            // 限制日志数量，防止内存占用过大
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
        }
    }
    
    func cancel() {
        cancellationToken = true
        // 终止当前进程
        if let process = currentProcess {
            if process.isRunning {
                process.terminate()
            }
            currentProcess = nil
        }
        
        // 在主线程清理句柄，避免竞争
        DispatchQueue.main.async { [weak self] in
            self?.outputHandle?.readabilityHandler = nil
            self?.errorHandle?.readabilityHandler = nil
            self?.outputHandle = nil
            self?.errorHandle = nil
        }
    }
    
    func fetchVideos(hours: Int = 48) -> AnyPublisher<[VideoItem], Error> {
        return Future<[VideoItem], Error> { [weak self] promise in
            guard let self = self else { return }
            
            // 重置取消令牌
            self.cancellationToken = false
            
            // 清空之前的日志
            DispatchQueue.main.async {
                self.logs.removeAll()
                self.appendLog("开始获取YouTube订阅内容...")
                self.appendLog("时间范围: \(hours)小时")
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 检查是否已取消
                    if self.cancellationToken { return }
                    
                    // 检查yt-dlp是否存在
                    try self.checkYtDlpExists()
                    
                    // 检查是否已取消
                    if self.cancellationToken { return }
                    
                    // 使用yt-dlp获取cookie并访问订阅页面
                    let subscriptionsPage = try self.fetchSubscriptionsPage()
                    
                    // 检查是否已取消
                    if self.cancellationToken { return }
                    
                    // 解析页面内容，提取视频信息
                    let videos = try self.parseVideos(from: subscriptionsPage)
                    
                    // 过滤出指定时间内的视频
                    let timeAgo = Date().addingTimeInterval(-Double(hours) * 60 * 60)
                    let recentVideos = videos.filter { $0.publishDate >= timeAgo }
                    
                    // 按发布时间排序（最新的在前）
                    let sortedVideos = recentVideos.sorted(by: { $0.publishDate > $1.publishDate })
                    
                    // 检查是否已取消
                    if self.cancellationToken { return }
                    
                    self.appendLog("成功获取到 \(sortedVideos.count) 个\(hours)小时内的视频")
                    promise(.success(sortedVideos))
                } catch {
                    if !self.cancellationToken {
                        self.appendLog("错误: \(error.localizedDescription)")
                        promise(.failure(error))
                    }
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
        self.currentProcess = process
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
        outputHandle.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, !self.cancellationToken else { return }
            let data = fileHandle.availableData
            if let string = String(data: data, encoding: .utf8) {
                output += string
            }
        }
        
        // 读取错误输出
        let errorHandle = errorPipe.fileHandleForReading
        errorHandle.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, !self.cancellationToken else { return }
            let data = fileHandle.availableData
            if let string = String(data: data, encoding: .utf8) {
                errorOutput += string
            }
        }
        
        process.terminationHandler = { _ in
            semaphore.signal()
        }
        
        self.appendLog("检查yt-dlp是否存在...")
        
        do {
            try process.run()
            semaphore.wait()
            self.currentProcess = nil
        } catch {
            self.currentProcess = nil
            self.appendLog("检查过程出错: \(error.localizedDescription)")
            throw error
        }
        
        // 记录输出信息
        if !output.isEmpty {
            self.appendLog("检查输出: \(output)")
        }
        if !errorOutput.isEmpty {
            self.appendLog("检查错误: \(errorOutput)")
        }
        
        // 直接检查文件是否存在
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: ytDlpPath) {
            exists = true
            self.appendLog("yt-dlp 已找到: \(ytDlpPath)")
        } else {
            self.appendLog("yt-dlp 未找到: \(ytDlpPath)")
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
        
        // 保存引用以便取消时使用
        self.currentProcess = process
        
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
        self.outputHandle = outputHandle
        outputHandle.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, !self.cancellationToken else { return }
            let data = fileHandle.availableData
            if data.isEmpty { return }
            if let string = String(data: data, encoding: .utf8) {
                output += string
                self.appendLog("[输出] \(string.prefix(200))\(string.count > 200 ? "..." : "")")
            } else {
                self.appendLog("[输出] 收到 \(data.count) 字节数据（无法解码为UTF-8）")
            }
        }
        
        // 读取错误输出
        let errorHandle = errorPipe.fileHandleForReading
        self.errorHandle = errorHandle
        errorHandle.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, !self.cancellationToken else { return }
            let data = fileHandle.availableData
            if data.isEmpty { return }
            if let string = String(data: data, encoding: .utf8) {
                errorOutput += string
                self.appendLog("[错误] \(string)")
            } else {
                self.appendLog("[错误] 收到 \(data.count) 字节数据（无法解码为UTF-8）")
            }
        }
        
        process.terminationHandler = { [weak self] process in
            guard let self = self else {
                semaphore.signal()
                return
            }
            terminationStatus = process.terminationStatus
            if !self.cancellationToken {
                self.appendLog("命令执行完成，退出状态: \(process.terminationStatus)")
            }
            semaphore.signal()
        }
        
        self.appendLog("开始获取订阅页面内容...")
        
        do {
            try process.run()
            
            // 设置超时时间为180秒（3分钟）
            let timeoutResult = semaphore.wait(timeout: .now() + 180)
            
            if timeoutResult == .timedOut {
                if process.isRunning {
                    self.appendLog("命令执行超时（180秒），强制终止...")
                    process.terminate()
                }
                self.currentProcess = nil
                throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 3, userInfo: [NSLocalizedDescriptionKey: "命令执行超时，请检查网络连接或cookie是否有效"])
            }
            
            self.currentProcess = nil
            if !self.cancellationToken {
                self.appendLog("命令执行完成，退出状态: \(terminationStatus)")
            }
        } catch let runError {
            self.currentProcess = nil
            processError = runError
            if !self.cancellationToken {
                self.appendLog("命令执行失败: \(runError.localizedDescription)")
            }
        }
        
        // 清理文件句柄
        DispatchQueue.main.async { [weak self] in
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            self?.outputHandle = nil
            self?.errorHandle = nil
        }
        
        if self.cancellationToken {
            throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 99, userInfo: [NSLocalizedDescriptionKey: "操作已取消"])
        }
        
        if let error = processError {
            throw error
        }
        
        guard !output.isEmpty else {
            throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "未能获取到订阅内容，请检查Chrome浏览器是否已登录YouTube且已关闭所有相关窗口"])
        }
        
        self.appendLog("成功获取订阅内容，开始解析...")
        return output
    }
    
    // MARK: - 解析视频信息
    private func parseVideos(from jsonOutput: String) throws -> [VideoItem] {
        var videos: [VideoItem] = []
        
        // 分割JSON输出，每行一个视频
        let lines = jsonOutput.components(separatedBy: .newlines)
        
        self.appendLog("开始解析 \(lines.count) 行数据...")
        
        for (_, line) in lines.enumerated() where !line.isEmpty {
            if self.cancellationToken { break }
            
            do {
                let data = line.data(using: .utf8)!
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                guard let videoJSON = json else { continue }
                
                // 提取视频信息 - 适应flat-playlist格式
                if let title = videoJSON["title"] as? String,
                   let url = videoJSON["webpage_url"] as? String ?? videoJSON["url"] as? String {
                    
                    // 获取频道名称（可能不存在）
                    let channel = videoJSON["uploader"] as? String ?? videoJSON["channel"] as? String ?? "未知频道"
                    
                    // 获取时间戳
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
                        // 如果没有时间戳，尝试解析其他可能的日期字段
                        publishDate = Date()
                        publishTime = "未知时间"
                    }
                    
                    videos.append(VideoItem(
                        title: title,
                        channel: channel,
                        url: url,
                        publishTime: publishTime,
                        publishDate: publishDate
                    ))
                }
            } catch {
                continue
            }
        }
        
        self.appendLog("成功解析出 \(videos.count) 个视频")
        return videos
    }
}

#Preview {
    SubscriptionsView()
        .frame(width: 1000, height: 600)
}
