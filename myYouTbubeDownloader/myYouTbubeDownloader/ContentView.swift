//
//  ContentView.swift
//  myYouTbubeDownloader
//
//  Created by Shylock Wolf on 2026/1/29.
//

import SwiftUI
import Foundation
import AppKit

struct ContentView: View {
    @State private var urlInputs = ["", "", "", "", "", "", "", "", ""]
    @State private var downloadRecords: [String] = []
    
    // 多通道并发支持
    @State private var slotLogs: [[String]] = [[], [], []]
    @State private var activeSlots: [Int?] = [nil, nil, nil]
    @State private var downloadTasks: [Process?] = [nil, nil, nil]
    
    @State private var isProcessing = false
    @State private var convertToMp3 = true
    @State private var completedTasks: Set<Int> = []
    
    @State private var pendingTasks: [(index: Int, url: String)] = []
    
    // 动画状态
    @State private var buttonScale: CGFloat = 1.0
    @State private var showCompletionAnimation = false
    
    // 订阅窗口控制器
    @State private var subscriptionsController: SubscriptionsWindowController?
    
    // 添加URL结果消息
    @State private var addURLMessage: String?
    @State private var showAddURLMessage: Bool = false

    var body: some View {
        HSplitView {
            // 左侧：现代化侧边栏
            sidebarView
            
            // 右侧：现代化日志面板
            logsPanelView
        }
        .frame(minWidth: 1100, minHeight: 600)
        .background(.windowBackground)
        .onReceive(NotificationCenter.default.publisher(for: .addURLToDownload)) { notification in
            if let url = notification.userInfo?["url"] as? String {
                addURLToFirstEmptySlot(url: url)
            }
        }
        .overlay(
            Group {
                if showAddURLMessage, let message = addURLMessage {
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
                        .padding(.bottom, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showAddURLMessage = false
                            }
                        }
                    }
                }
            }
        )
    }
    
    // MARK: - 添加URL到第一个空位
    private func addURLToFirstEmptySlot(url: String) {
        // 查找第一个空的输入框
        for index in 0..<urlInputs.count {
            if urlInputs[index].isEmpty {
                urlInputs[index] = url
                addURLMessage = "已添加到下载位置 \(index + 1)"
                withAnimation {
                    showAddURLMessage = true
                }
                // 发送结果通知到订阅窗口
                NotificationCenter.default.post(
                    name: .addURLResult,
                    object: nil,
                    userInfo: ["result": "已添加到下载位置 \(index + 1)", "url": url]
                )
                return
            }
        }
        // 没有空位
        addURLMessage = "添加失败：下载列表已满"
        withAnimation {
            showAddURLMessage = true
        }
        // 发送结果通知到订阅窗口
        NotificationCenter.default.post(
            name: .addURLResult,
            object: nil,
            userInfo: ["result": "添加失败：下载列表已满", "url": url]
        )
    }
    
    // MARK: - 侧边栏视图
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 标题区域
            sidebarHeader
            
            Divider()
            
            // 任务列表
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(0..<9, id: \.self) { index in
                        TaskInputCard(
                            index: index,
                            url: $urlInputs[index],
                            isCompleted: completedTasks.contains(index),
                            activeSlot: activeSlots.firstIndex(of: index)
                        )
                    }
                }
                .padding(16)
            }
            
            Divider()
            
            // 控制区域
            controlSection
        }
        .frame(minWidth: 560, maxWidth: 640, maxHeight: .infinity, alignment: .top)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 侧边栏标题
    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("YouTube 下载器")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("支持批量下载与 MP3 转换")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
    
    // MARK: - 控制区域
    private var controlSection: some View {
        VStack(spacing: 16) {
            // 格式选择
            HStack {
                Image(systemName: convertToMp3 ? "music.note" : "film")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                
                Toggle("转换为 MP3 格式", isOn: $convertToMp3)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            
            // 操作按钮
            HStack(spacing: 12) {
                // 订阅按钮
                Button(action: openSubscriptionsWindow) {
                    Text("查看订阅")
                        .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("查看订阅")
                
                // 取消按钮
                Button(action: cancelDownload) {
                    Text("取消下载")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isProcessing)
                
                // 主按钮
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            buttonScale = 1.0
                        }
                    }
                    startDownload()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isProcessing ? "arrow.clockwise" : "arrow.down")
                            .font(.system(size: 12, weight: .medium))
                        
                        Text(isProcessing ? "下载中..." : "开始下载")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isProcessing || urlInputs.allSatisfy { $0.isEmpty })
                .scaleEffect(buttonScale)
                
                // 退出按钮
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("退出应用")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)

            DownloadRecordsCard(records: downloadRecords)
                .padding(.horizontal, 12)
            
            Spacer()
            
            // 状态信息
            HStack {
                Text(getStatusText())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("v2.4.2")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }
    
    // MARK: - 日志面板
    private var logsPanelView: some View {
        VStack(spacing: 0) {
            // 面板标题
            logsHeader
            
            Divider()
            
            // 日志内容 - 三个通道平分高度
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    LogSlotCard(
                        slotNumber: index + 1,
                        logs: slotLogs[index],
                        isActive: activeSlots[index] != nil,
                        taskIndex: activeSlots[index]
                    )
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 500, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - 日志标题
    private var logsHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 13))
                Text("下载日志")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 16) {
                // 并发指示器
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(activeSlots[index] != nil ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    // MARK: - 状态文本
    private func getStatusText() -> String {
        let activeCount = activeSlots.compactMap { $0 }.count
        let completedCount = completedTasks.count
        let totalCount = urlInputs.filter { !$0.isEmpty }.count
        
        if isProcessing {
            return "并发: \(activeCount) | 完成: \(completedCount)/\(totalCount)"
        } else if completedCount > 0 {
            return "已完成: \(completedCount) 个任务"
        } else {
            return "准备就绪"
        }
    }

    private func extractFinalFilename(from logs: [String]) -> String? {
        let exts = [".mp3", ".m4a", ".wav", ".flac", ".aac", ".mp4", ".webm", ".mkv"]
        for line in logs.reversed() {
            if let range = line.range(of: "Destination: ") {
                let name = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let ext = exts.first(where: { trimmed.lowercased().hasSuffix($0) }) {
                return trimmed.components(separatedBy: " ").last(where: { $0.lowercased().hasSuffix(ext) })
            }
        }
        return nil
    }
    
    // MARK: - 解析 yt-dlp 路径
    private func resolveYtDlpPath() -> String {
        let fileManager = FileManager.default
        let candidatePaths = [
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp",
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp"
        ]
        
        for path in candidatePaths {
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        return "yt-dlp"
    }
    
    // MARK: - 处理 URL（解决微博短链接问题）
    private func processURL(_ url: String) -> String {
        var processedURL = url
        
        if url.contains("weibo.com") || url.contains("t.cn") {
            if url.contains("passport.weibo.com/visitor") {
                if let range = url.range(of: "url=", options: .caseInsensitive) {
                    let encodedURL = String(url[range.upperBound...])
                    if let decodedURL = encodedURL.removingPercentEncoding {
                        processedURL = decodedURL
                    }
                }
            }
        }
        
        return processedURL
    }

    private func startDownload() {
        isProcessing = true
        completedTasks.removeAll()
        // 重置日志和状态
        for i in 0..<3 {
            slotLogs[i] = []
            activeSlots[i] = nil
            downloadTasks[i] = nil
        }
        
        // 收集任务
        pendingTasks = []
        for index in 0..<9 {
            if !urlInputs[index].isEmpty {
                let url = urlInputs[index]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                pendingTasks.append((index, url))
            }
        }
        
        if pendingTasks.isEmpty {
            isProcessing = false
            return
        }
        
        // 触发调度
        scheduleTasks()
    }
    
    private func scheduleTasks() {
        // 检查是否有空闲 Slot 且有待处理任务
        for i in 0..<3 {
            if downloadTasks[i] == nil {
                if !pendingTasks.isEmpty {
                    let task = pendingTasks.removeFirst()
                    processTask(task: task, slotIndex: i)
                }
            }
        }
        
        // 检查是否所有任务都完成
        checkAllFinished()
    }
    
    private func checkAllFinished() {
        // 如果没有待处理任务，且所有 Slot 都是空闲的
        let allSlotsIdle = downloadTasks.allSatisfy { $0 == nil }
        if pendingTasks.isEmpty && allSlotsIdle {
            isProcessing = false
        }
    }
    
    private func processTask(task: (index: Int, url: String), slotIndex: Int) {
        let index = task.index
        let url = processURL(task.url)
        
        activeSlots[slotIndex] = index
        slotLogs[slotIndex] = [] // 清空该 Slot 的日志
        
        // 获取下载目录
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory() + "/Downloads"
        // yt-dlp 的可执行路径（兼容 Intel 与 Apple Silicon）
        let ytDlpPath = resolveYtDlpPath()
        
        var command = "\"\(ytDlpPath)\" --extractor-args \"youtube:player_client=android\""
        if convertToMp3 {
            command += " -x --audio-format mp3 --embed-thumbnail"
        }
        command += " \"\(url)\""
        
        appendLog(slotIndex: slotIndex, message: "=== 开始下载视频 \(index + 1) ===")
        appendLog(slotIndex: slotIndex, message: "执行命令: \(command)")
        appendLog(slotIndex: slotIndex, message: "工作目录: \(downloadsPath)")
        appendLog(slotIndex: slotIndex, message: "")
        
        executeCommand(command: command, workingDirectory: downloadsPath, slotIndex: slotIndex) { success in
            DispatchQueue.main.async {
                if success {
                    self.appendLog(slotIndex: slotIndex, message: "✓ 视频 \(index + 1) 下载完成")
                    self.urlInputs[index] = ""
                    self.completedTasks.remove(index)
                    if let name = self.extractFinalFilename(from: self.slotLogs[slotIndex]) {
                        self.downloadRecords.append(name)
                    }
                } else {
                    self.appendLog(slotIndex: slotIndex, message: "✗ 视频 \(index + 1) 下载失败")
                }
                
                // 任务结束，释放 Slot
                self.downloadTasks[slotIndex] = nil
                self.activeSlots[slotIndex] = nil
                
                // 调度下一个任务
                self.scheduleTasks()
            }
        }
    }
    
    private func appendLog(slotIndex: Int, message: String) {
        slotLogs[slotIndex].append(message)
        // 限制日志长度
        if slotLogs[slotIndex].count > 500 {
            slotLogs[slotIndex].removeFirst(slotLogs[slotIndex].count - 500)
        }
    }

    private func executeCommand(command: String, workingDirectory: String, slotIndex: Int, completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()
        
        let semaphore = DispatchSemaphore(value: 0)
        var hasCompleted = false

        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = env
        
        task.arguments = ["-c", "cd \"\(workingDirectory)\" && exec \(command)"]
        task.standardOutput = pipe
        task.standardError = pipe

        // 保存 Process 引用
        downloadTasks[slotIndex] = task

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        self.appendLog(slotIndex: slotIndex, message: line)
                    }
                }
            }
        }

        task.terminationHandler = { process in
            DispatchQueue.main.async {
                // 关闭文件句柄，防止内存泄漏或资源占用
                handle.readabilityHandler = nil
                if !hasCompleted {
                    hasCompleted = true
                    semaphore.signal()
                    completion(process.terminationStatus == 0)
                }
            }
        }

        do {
            try task.run()
            
            // 设置超时时间为600秒（10分钟）
            DispatchQueue.global(qos: .userInitiated).async {
                let timeoutResult = semaphore.wait(timeout: .now() + 600)
                
                if timeoutResult == .timedOut && !hasCompleted {
                    DispatchQueue.main.async {
                        if task.isRunning {
                            self.appendLog(slotIndex: slotIndex, message: "下载超时（10分钟），强制终止...")
                            task.terminate()
                        }
                        if !hasCompleted {
                            hasCompleted = true
                            self.downloadTasks[slotIndex] = nil
                            self.activeSlots[slotIndex] = nil
                            completion(false)
                        }
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.appendLog(slotIndex: slotIndex, message: "错误: \(error.localizedDescription)")
                if !hasCompleted {
                    hasCompleted = true
                    completion(false)
                }
            }
        }
    }

    private func cancelDownload() {
        isProcessing = false
        pendingTasks.removeAll() // 清空等待队列
        
        for i in 0..<3 {
            if let task = downloadTasks[i] {
                if task.isRunning {
                    task.terminate()
                }
                downloadTasks[i] = nil
                activeSlots[i] = nil
                appendLog(slotIndex: i, message: "--- 已取消 ---")
            }
        }
    }
    
    private func openSubscriptionsWindow() {
        if subscriptionsController == nil {
            subscriptionsController = SubscriptionsWindowController {
                self.subscriptionsController = nil
            }
        }
        subscriptionsController?.showWindow()
    }
}

// MARK: - 订阅窗口控制器
class SubscriptionsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 840, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "YouTube 订阅"
        newWindow.isReleasedWhenClosed = false // 重要：手动管理生命周期
        newWindow.delegate = self
        
        let subscriptionsView = SubscriptionsView()
        newWindow.contentView = NSHostingView(rootView: subscriptionsView)
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.center()
    }
    
    func windowWillClose(_ notification: Notification) {
        // 先取消正在进行的fetch操作
        // 注意：由于 YouTubeSubscriptionsFetcher 定义在 SubscriptionsView.swift 中且为 internal，
        // 在同一个模块下应该是可见的。如果编译器报错，可能是因为 SubscriptionsView.swift 编译失败。
        YouTubeSubscriptionsFetcher.shared.cancel()
        // 发送通知清理订阅
        NotificationCenter.default.post(name: NSNotification.Name("cleanupSubscriptions"), object: nil)
        
        // 清理窗口资源
        window?.delegate = nil
        window = nil
        
        // 延迟通知外部控制器已关闭，确保窗口生命周期完全结束
        DispatchQueue.main.async {
            self.onClose()
        }
    }
}

// MARK: - 任务输入卡片
struct TaskInputCard: View {
    let index: Int
    @Binding var url: String
    let isCompleted: Bool
    let activeSlot: Int?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 18, height: 18)
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                Text("视频 \(index + 1)")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if !url.isEmpty && !isCompleted && activeSlot == nil {
                    Button(action: { url = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 11))
                    .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                TextField("粘贴 YouTube 链接", text: $url)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(isCompleted ? 0.7 : 1.0)
    }
    
    private var statusIcon: String {
        if isCompleted {
            return "checkmark"
        } else if activeSlot != nil {
            return "arrow.down"
        } else if !url.isEmpty {
            return "play.circle"
        } else {
            return "video"
        }
    }
    
    private var statusColor: Color {
        if isCompleted {
            return .green
        } else if activeSlot != nil {
            return .accentColor
        } else if !url.isEmpty {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - 日志槽卡片
struct LogSlotCard: View {
    let slotNumber: Int
    let logs: [String]
    let isActive: Bool
    let taskIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    // 状态指示器
                    ZStack {
                        if isActive {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("通道 \(slotNumber)")
                        .font(.system(size: 12, weight: .medium))
                    
                    if let taskIdx = taskIndex {
                        Text("• 视频 \(taskIdx + 1)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isActive {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 日志内容
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        if logs.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.tertiary)
                                Text(isActive ? "准备下载..." : "空闲")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .padding(.vertical, 20)
                        } else {
                            Text(logs.joined(separator: "\n"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(NSColor.textColor))
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .textSelection(.enabled)
                                .id("bottom")
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .onChange(of: logs) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

struct DownloadRecordsCard: View {
    let records: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 22, height: 22)
                        Image(systemName: "tray.full")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text("下载记录")
                        .font(.system(size: 12, weight: .medium))
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if records.isEmpty {
                        Text("暂无记录")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(records.enumerated()), id: \.offset) { idx, name in
                            Text("\(idx + 1). \(name)")
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(10)
            }
            .frame(minHeight: 80, maxHeight: 150)
        }
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 680)
}
