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
    @State private var slotLogs: [[String]] = [[], [], []] // 3个通道的日志
    @State private var activeSlots: [Int?] = [nil, nil, nil] // 记录每个slot正在处理哪个任务index (0-4)
    @State private var downloadTasks: [Process?] = [nil, nil, nil] // 3个下载进程
    
    @State private var isProcessing = false
    @State private var convertToMp3 = true
    @State private var completedTasks: Set<Int> = []
    
    // 待处理任务队列
    @State private var pendingTasks: [(index: Int, url: String)] = []

    var body: some View {
        HSplitView {
            // 左侧：侧边栏风格输入区
            List {
                Section(header: Text("YouTube 下载任务").font(.headline)) {
                    ForEach(0..<5, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if completedTasks.contains(index) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "video.circle")
                                        .foregroundStyle(.secondary)
                                }
                                Text("视频 \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                // 显示该视频当前在哪一个通道运行
                                if let slotIndex = activeSlots.firstIndex(of: index) {
                                    Text("正在通道 \(slotIndex + 1) 下载...")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.gray)
                                ZStack(alignment: .leading) {
                                    if urlInputs[index].isEmpty {
                                        Text("粘贴 YouTube 网址")
                                            .foregroundStyle(.gray.opacity(0.5))
                                    }
                                    TextField("", text: $urlInputs[index])
                                        .textFieldStyle(.plain)
                                }
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                    }
                }
                
                Section {
                    Toggle("转换成 mp3", isOn: $convertToMp3)
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        Button(action: startDownload) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("开始下载")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isProcessing || urlInputs.allSatisfy { $0.isEmpty })

                        Button(action: cancelDownload) {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(!isProcessing)
                        .help("放弃下载")
                        
                        Button(action: {
                            NSApplication.shared.terminate(nil)
                        }) {
                            Image(systemName: "power")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .help("退出程序")
                    }
                    .padding(.top, 10)
                }
                
                Section {
                    VStack(spacing: 2) {
                        Text("Version 1.6")
                        Text("by Shylock Wolf")
                        Text("2026/02")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250, maxHeight: .infinity)

            // 右侧：控制台输出 (分为三个通道)
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 顶部标题栏
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(.secondary)
                        Text("并行下载日志 (最大并发: 3)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 8)
                        }
                    }
                    .padding()
                    .background(Material.bar)
                    
                    Divider()

                    // 三个独立的日志窗口
                    VStack(spacing: 8) {
                        LogSlotView(title: "通道 1", logs: slotLogs[0], isActive: activeSlots[0] != nil)
                        LogSlotView(title: "通道 2", logs: slotLogs[1], isActive: activeSlots[1] != nil)
                        LogSlotView(title: "通道 3", logs: slotLogs[2], isActive: activeSlots[2] != nil)
                    }
                    .padding(4)
                }
            }
            .frame(width: 600)
            .frame(maxHeight: .infinity) // 宽度修改为 600
        }
        .frame(minWidth: 900, minHeight: 150) // 高度修改为 150
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

// 独立的日志窗口组件
struct LogSlotView: View {
    let title: String
    let logs: [String]
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 小标题栏
            HStack {
                Circle()
                    .fill(isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            // .background(Color.black.opacity(0.8)) // 移除标题栏背景
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if logs.isEmpty {
                            Text(isActive ? "准备中..." : "空闲")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(8)
                        } else {
                            Text(logs.joined(separator: "\n"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary) // 文字颜色改为自适应
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                                .id("bottom")
                        }
                    }
                }
                // .background(Color.black) // 移除内容区背景
                .onChange(of: logs) {
                    // 自动滚动到底部
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding(6) // 增加内边距，防止文字被边框遮挡
        .frame(maxHeight: .infinity)
        .overlay(
            Rectangle()
                .strokeBorder(Color.blue, lineWidth: 8)
        )
    }
}

#Preview {
    ContentView()
}
