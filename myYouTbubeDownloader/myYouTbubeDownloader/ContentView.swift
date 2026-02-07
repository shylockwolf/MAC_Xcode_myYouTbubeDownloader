//
//  ContentView.swift
//  myYouTbubeDownloader
//
//  Created by Shylock Wolf on 2026/1/29.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @State private var urlInputs = ["", "", "", "", ""]
    
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

    var body: some View {
        HSplitView {
            // 左侧：现代化侧边栏
            sidebarView
            
            // 右侧：现代化日志面板
            logsPanelView
        }
        .frame(minWidth: 1000, minHeight: 600)
        .background(.windowBackground)
    }
    
    // MARK: - 侧边栏视图
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 标题区域
            sidebarHeader
            
            Divider()
            
            // 任务列表
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { index in
                        TaskInputCard(
                            index: index,
                            url: $urlInputs[index],
                            isCompleted: completedTasks.contains(index),
                            activeSlot: activeSlots.firstIndex(of: index)
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // 控制区域
            controlSection
        }
        .frame(minWidth: 320, maxWidth: 380)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            .padding(.horizontal, 16)
            
            // 操作按钮
            HStack(spacing: 12) {
                // 取消按钮
                Button(action: cancelDownload) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!isProcessing)
                .help("取消下载")
                
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
                    HStack(spacing: 8) {
                        Image(systemName: isProcessing ? "arrow.clockwise" : "arrow.down")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(isProcessing ? "下载中..." : "开始下载")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isProcessing || urlInputs.allSatisfy { $0.isEmpty })
                .scaleEffect(buttonScale)
            }
            .padding(.horizontal, 16)
            
            // 状态信息
            HStack {
                Text(getStatusText())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("v1.6.1")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(.bar)
    }
    
    // MARK: - 日志面板
    private var logsPanelView: some View {
        VStack(spacing: 0) {
            // 面板标题
            logsHeader
            
            Divider()
            
            // 日志内容
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        LogSlotCard(
                            slotNumber: index + 1,
                            logs: slotLogs[index],
                            isActive: activeSlots[index] != nil,
                            taskIndex: activeSlots[index]
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 500)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        for index in 0..<5 {
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
        let url = task.url
        
        activeSlots[slotIndex] = index
        slotLogs[slotIndex] = [] // 清空该 Slot 的日志
        
        // 获取下载目录
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory() + "/Downloads"
        // yt-dlp 的完整路径
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        
        var command = "\(ytDlpPath) --cookies-from-browser chrome"
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
                    self.completedTasks.insert(index)
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
        if slotLogs[slotIndex].count > 50 {
            slotLogs[slotIndex].removeFirst(slotLogs[slotIndex].count - 50)
        }
    }

    private func executeCommand(command: String, workingDirectory: String, slotIndex: Int, completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()

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
                completion(process.terminationStatus == 0)
            }
        }

        do {
            try task.run()
        } catch {
            DispatchQueue.main.async {
                self.appendLog(slotIndex: slotIndex, message: "错误: \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    private func cancelDownload() {
        isProcessing = false
        pendingTasks.removeAll() // 清空等待队列
        
        for i in 0..<3 {
            if let task = downloadTasks[i] {
                task.terminate()
                downloadTasks[i] = nil
                activeSlots[i] = nil
                appendLog(slotIndex: i, message: "--- 已取消 ---")
            }
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
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 8) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("视频 \(index + 1)")
                        .font(.system(size: 12, weight: .medium))
                    
                    if let slot = activeSlot {
                        Text("通道 \(slot + 1) 下载中")
                            .font(.system(size: 10))
                                .foregroundStyle(Color.accentColor)
                    } else if isCompleted {
                        Text("下载完成")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    } else if !url.isEmpty {
                        Text("等待中")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if !url.isEmpty && !isCompleted && activeSlot == nil {
                    Button(action: { url = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 输入框
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                
                TextField("粘贴 YouTube 链接", text: $url)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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
                                .id("bottom")
                        }
                    }
                }
                .frame(minHeight: 80, maxHeight: 140)
                .onChange(of: logs) { _ in
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

#Preview {
    ContentView()
        .frame(width: 1000, height: 600)
}
