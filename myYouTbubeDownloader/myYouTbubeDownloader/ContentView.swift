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
    @State private var commandLogs: [String] = []
    @State private var isProcessing = false
    @State private var downloadTask: Process?

    var body: some View {
        NavigationView {
            // 左侧：侧边栏风格输入区
            List {
                Section(header: Text("YouTube 下载任务").font(.headline)) {
                    ForEach(0..<5, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Label("视频 \(index + 1)", systemImage: "video.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.gray)
                                TextField("粘贴 YouTube 网址", text: $urlInputs[index])
                                    .textFieldStyle(.plain)
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
                    }
                    .padding(.top, 10)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250)

            // 右侧：控制台输出
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 控制台标题栏
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(.secondary)
                        Text("运行日志")
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

                    // 命令行显示区域
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 5) {
                                if commandLogs.isEmpty {
                                    Text("等待任务开始...")
                                        .foregroundStyle(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.top, 40)
                                } else {
                                    Text(commandLogs.joined(separator: "\n"))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("logText")
                                }
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(4)
                        }
                        .background(Color.black)
                        .onChange(of: commandLogs) { _ in
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    Spacer()
                        .frame(height: geometry.size.height * 0.2)
                }
            }
            .frame(width: 600) // 固定宽度 600
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private func startDownload() {
        isProcessing = true
        commandLogs = []

        // 获取下载目录
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory() + "/Downloads"

        // yt-dlp 的完整路径
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"

        for index in 0..<5 {
            if !urlInputs[index].isEmpty {
                let url = urlInputs[index]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                let command = "\(ytDlpPath) --cookies-from-browser chrome \"\(url)\""

                commandLogs.append("=== 视频 \(index + 1) ===")
                commandLogs.append("执行命令: \(command)")
                commandLogs.append("工作目录: \(downloadsPath)")
                commandLogs.append("")

                executeCommand(command: command, workingDirectory: downloadsPath) { success in
                    if success {
                        DispatchQueue.main.async {
                            commandLogs.append("✓ 视频 \(index + 1) 下载完成")
                            commandLogs.append("")
                        }
                    } else {
                        DispatchQueue.main.async {
                            commandLogs.append("✗ 视频 \(index + 1) 下载失败")
                            commandLogs.append("")
                        }
                    }
                }
            }
        }
    }

    private func executeCommand(command: String, workingDirectory: String, completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        // 设置环境变量，确保包含 homebrew 的 bin 目录，以便 yt-dlp 能找到 python3, node, ffmpeg 等依赖
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = env
        
        task.arguments = ["-c", "cd \"\(workingDirectory)\" && \(command)"]
        task.standardOutput = pipe
        task.standardError = pipe

        downloadTask = task

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        commandLogs.append(line)
                        // 保持最新的日志在顶部，但不超过50条
                        if commandLogs.count > 50 {
                            commandLogs.removeFirst(commandLogs.count - 50)
                        }
                    }
                }
            }
        }

        task.terminationHandler = { process in
            DispatchQueue.main.async {
                completion(process.terminationStatus == 0)
                if process.terminationStatus == 0 {
                    isProcessing = false
                }
            }
        }

        do {
            try task.run()
        } catch {
            DispatchQueue.main.async {
                commandLogs.append("错误: \(error.localizedDescription)")
                completion(false)
                isProcessing = false
            }
        }
    }

    private func cancelDownload() {
        downloadTask?.terminate()
        isProcessing = false
        commandLogs.append("--- 已取消 ---")
    }
}

#Preview {
    ContentView()
}
