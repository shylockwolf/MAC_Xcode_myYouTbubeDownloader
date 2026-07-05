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
    static let startDownloadFromSubscriptions = Notification.Name("startDownloadFromSubscriptions")
    static let scheduledAutoDownload = Notification.Name("scheduledAutoDownload")
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
    @ObservedObject private var scheduler = SubscriptionScheduler.shared
    @State private var now = Date()
    private let clockTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    @State private var isAutoDownloading = false
    
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
        .onChange(of: scheduler.isScheduled) { _ in scheduler.saveAndRefresh() }
        .onChange(of: scheduler.scheduledTime) { _ in scheduler.saveAndRefresh() }
        .onReceive(clockTimer) { _ in now = Date() }
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
            cancellables.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduledAutoDownload)) { _ in
            scheduledAutoDownload()
        }
        .onAppear {
            if scheduler.lastTriggered.hasPrefix("触发中") && !isAutoDownloading {
                scheduler.lastTriggered = "获取中..."
                scheduledAutoDownload()
            }
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
                
                // 一键下载按钮
                Button(action: oneClickDownload) {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoDownloading ? "arrow.clockwise" : "bolt.fill")
                            .font(.system(size: 10))
                        Text(isAutoDownloading ? "一键下载中..." : "一键下载")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isAutoDownloading)
                
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
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: scheduler.isScheduled ? "clock.badge.checkmark" : "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(scheduler.isScheduled ? .green : .secondary)
                    Toggle("定时自动下载", isOn: $scheduler.isScheduled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Spacer()
                }
                
                if scheduler.isScheduled {
                    HStack(spacing: 8) {
                        DatePicker("时间", selection: $scheduler.scheduledTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .controlSize(.small)
                        
                        Spacer()
                        
                        Text("时间范围: \(selectedHours)h")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("每天 \(nextExecutionText()) 自动获取并下载")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                        Text("系统时间: \(currentTimeString)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(scheduler.lastTriggered.hasPrefix("失败") ? .red : scheduler.lastTriggered.hasPrefix("下载") ? .green : scheduler.lastTriggered.hasPrefix("获取中") ? .orange : .secondary)
                        Text(scheduler.lastTriggered)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(scheduler.lastTriggered.hasPrefix("失败") ? .red : scheduler.lastTriggered.hasPrefix("下载") ? .green : scheduler.lastTriggered.hasPrefix("获取中") ? .orange : .secondary)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(scheduler.isScheduled ? Color.green.opacity(0.05) : Color.clear)
            )
            
            Button(action: startDownloadFromSubscriptions) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                    Text("开始下载")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(videos.isEmpty || isLoading || isAutoDownloading)
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
    
    // MARK: - 从订阅页面开始下载
    private func startDownloadFromSubscriptions() {
        NotificationCenter.default.post(name: .startDownloadFromSubscriptions, object: nil)
    }
    
    // MARK: - 定时自动下载完整流程
    private func scheduledAutoDownload() {
        guard !isAutoDownloading else { return }
        isAutoDownloading = true
        
        isLoading = true
        errorMessage = nil
        logs.removeAll()
        cancellables.removeAll()
        
        logs.append("[定时下载] ⏰ 定时任务触发，开始自动获取订阅视频...")
        logs.append("[定时下载] 时间范围: \(selectedHours)小时")
        
        YouTubeSubscriptionsFetcher.shared.$logs
            .receive(on: DispatchQueue.main)
            .sink { newLogs in
                self.logs = newLogs
            }
            .store(in: &cancellables)
        
        YouTubeSubscriptionsFetcher.shared.fetchVideos(hours: selectedHours)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                switch completion {
                case .finished:
                    self.lastUpdated = Date()
                    self.logs.append("[定时下载] ✅ 获取完成，共 \(self.videos.count) 个视频")
                    self.autoAddAllAndDownload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.logs.append("[定时下载] ❌ 获取失败: \(error.localizedDescription)")
                    self.isAutoDownloading = false
                }
            }, receiveValue: { fetchedVideos in
                self.videos = fetchedVideos
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 自动添加所有URL并开始下载
    private func autoAddAllAndDownload() {
        guard !videos.isEmpty else {
            logs.append("[一键下载] 没有新视频，跳过下载")
            isAutoDownloading = false
            return
        }
        
        logs.append("[一键下载] 正在添加 \(videos.count) 个视频到下载列表...")
        
        for (index, video) in videos.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                NotificationCenter.default.post(
                    name: .addURLToDownload,
                    object: nil,
                    userInfo: ["url": video.url, "publishDate": video.publishDate.timeIntervalSince1970]
                )
            }
        }
        
        let delay = Double(videos.count) * 0.15 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.logs.append("[一键下载] 🚀 开始下载 \(self.videos.count) 个视频")
            self.isAutoDownloading = false
            NotificationCenter.default.post(name: .startDownloadFromSubscriptions, object: nil)
        }
    }
    
    // MARK: - 一键下载：收集-选择-下载-转码
    private func oneClickDownload() {
        guard !isAutoDownloading else { return }
        
        // 如果已有视频，直接添加并下载
        if !videos.isEmpty {
            isAutoDownloading = true
            logs.append("[一键下载] 🚀 使用已获取的 \(videos.count) 个视频")
            autoAddAllAndDownload()
            return
        }
        
        // 没有视频，先获取再下载
        isAutoDownloading = true
        isLoading = true
        errorMessage = nil
        logs.removeAll()
        cancellables.removeAll()
        
        logs.append("[一键下载] 🚀 开始一键下载流程...")
        logs.append("[一键下载] 时间范围: \(selectedHours)小时")
        
        YouTubeSubscriptionsFetcher.shared.$logs
            .receive(on: DispatchQueue.main)
            .sink { newLogs in
                self.logs = newLogs
            }
            .store(in: &cancellables)
        
        YouTubeSubscriptionsFetcher.shared.fetchVideos(hours: selectedHours, enrichDetails: true)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                switch completion {
                case .finished:
                    self.lastUpdated = Date()
                    self.logs.append("[一键下载] ✅ 获取完成，共 \(self.videos.count) 个视频")
                    self.autoAddAllAndDownload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.logs.append("[一键下载] ❌ 获取失败: \(error.localizedDescription)")
                    self.isAutoDownloading = false
                }
            }, receiveValue: { fetchedVideos in
                self.videos = fetchedVideos
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 当前时间字符串
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: now)
    }
    
    // MARK: - 定时执行时间显示
    private func nextExecutionText() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: scheduler.scheduledTime)
        
        guard let hour = components.hour, let minute = components.minute else { return "06:00" }
        
        var nextDateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        nextDateComponents.hour = hour
        nextDateComponents.minute = minute
        nextDateComponents.second = 0
        
        guard var nextDate = calendar.date(from: nextDateComponents) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        
        if nextDate <= now {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: nextDate)
        
        let isToday = calendar.isDateInToday(nextDate)
        return "\(isToday ? "今天" : "明天") \(timeString)"
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
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(video.duration)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
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
                        userInfo: ["url": video.url, "publishDate": video.publishDate.timeIntervalSince1970]
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
            
            // 视频时长
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(video.duration)
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
                    userInfo: ["url": video.url, "publishDate": video.publishDate.timeIntervalSince1970]
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
    let duration: String
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
    
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
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
    
    func fetchVideos(hours: Int = 48, enrichDetails: Bool = true) -> AnyPublisher<[VideoItem], Error> {
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
                    
                    // 检查yt-dlp是否存在并获取可执行路径
                    let ytDlpPath = try self.checkYtDlpExists()
                    
                    // 检查是否已取消
                    if self.cancellationToken { return }
                    
                    // 使用yt-dlp获取cookie并访问订阅页面
                    let subscriptionsPage = try self.fetchSubscriptionsPage(ytDlpPath: ytDlpPath)
                    
                    // 检查是否已取消
                    if self.cancellationToken { return }
                    
                    // 解析页面内容，提取视频信息
                    let videos = try self.parseVideos(from: subscriptionsPage, enrichDetails: enrichDetails, ytDlpPath: ytDlpPath)
                    
                    // 过滤出指定时间内的视频
                    let timeAgo = Date().addingTimeInterval(-Double(hours) * 60 * 60)
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    self.appendLog("过滤时间范围: \(formatter.string(from: timeAgo)) 之后")
                    
                    for video in videos {
                        let isInTimeRange = video.publishDate >= timeAgo
                        self.appendLog("视频: \(video.title.prefix(20))... - 发布时间: \(formatter.string(from: video.publishDate)) - \(isInTimeRange ? "✓符合" : "✗超时")")
                    }
                    
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
    private func checkYtDlpExists() throws -> String {
        appendLog("检查yt-dlp是否存在...")
        
        do {
            let path = try YtDlpLocator.shared.locate()
            appendLog("yt-dlp 已找到: \(path)")
            return path
        } catch {
            appendLog("yt-dlp 未找到")
            throw error
        }
    }
    
    // MARK: - 获取订阅页面内容
    private func fetchSubscriptionsPage(ytDlpPath: String) throws -> String {
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
        
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        // 设置环境变量，确保两种 Homebrew 路径都在 PATH 中
        var environment = ProcessInfo.processInfo.environment
        let originalPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + originalPath
        environment["HOME"] = NSHomeDirectory()
        process.environment = environment
        
        process.arguments = [
            "--cookies-from-browser", "chrome",
            "--flat-playlist",
            "--dump-json",
            "--skip-download",
            "--no-warnings",
            "--ignore-errors",
            "--playlist-items", "1:21",
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
            
            // 设置超时时间为300秒（5分钟）
            let timeoutResult = semaphore.wait(timeout: .now() + 300)
            
            if timeoutResult == .timedOut {
                if process.isRunning {
                    self.appendLog("命令执行超时（300秒），强制终止...")
                    process.terminate()
                }
                self.currentProcess = nil
                throw NSError(domain: "YouTubeSubscriptionsFetcher", code: 3, userInfo: [NSLocalizedDescriptionKey: "命令执行超时（超过5分钟），可能原因：\n1. 网络连接较慢\n2. YouTube服务器响应慢\n3. Cookie已失效\n\n建议：\n- 检查网络连接\n- 重新登录YouTube\n- 关闭所有Chrome窗口后重试"])
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
    private func parseVideos(from jsonOutput: String, enrichDetails: Bool = true, ytDlpPath: String) throws -> [VideoItem] {
        var videos: [VideoItem] = []
        
        // 分割JSON输出，每行一个视频
        let lines = jsonOutput.components(separatedBy: .newlines)
        
        self.appendLog("开始解析 \(lines.count) 行数据...")
        
        // 使用Set去重，避免同一视频的多个格式被重复添加
        var processedIDs = Set<String>()
        
        for (_, line) in lines.enumerated() where !line.isEmpty {
            if self.cancellationToken { break }
            
            do {
                let data = line.data(using: .utf8)!
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                guard let videoJSON = json else { continue }
                
                // 获取视频ID用于去重
                guard let videoID = videoJSON["id"] as? String else { continue }
                
                // 如果已经处理过这个视频，跳过
                if processedIDs.contains(videoID) { continue }
                
                // 提取视频信息 - 适应flat-playlist格式
                if let title = videoJSON["title"] as? String,
                   let url = videoJSON["webpage_url"] as? String ?? videoJSON["url"] as? String {
                    
                    // 标记为已处理
                    processedIDs.insert(videoID)
                    
                    // 获取频道名称（flat-playlist格式可能没有uploader字段）
                    let channel = videoJSON["uploader"] as? String ?? videoJSON["channel"] as? String ?? "未知频道"
                    
                    // 获取时间戳（flat-playlist格式通常没有timestamp）
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
                        publishDate = Date(timeIntervalSince1970: 0)
                        publishTime = "获取中..."
                    }
                    
                    // 获取视频时长（秒）
                    let duration: String
                    if let durationSeconds = videoJSON["duration"] as? Int {
                        duration = formatDuration(durationSeconds)
                    } else if let durationSeconds = videoJSON["duration"] as? Double {
                        duration = formatDuration(Int(durationSeconds))
                    } else {
                        duration = "未知时长"
                    }
                    
                    videos.append(VideoItem(
                        title: title,
                        channel: channel,
                        url: url,
                        publishTime: publishTime,
                        publishDate: publishDate,
                        duration: duration
                    ))
                }
            } catch {
                continue
            }
        }
        
        self.appendLog("成功解析出 \(videos.count) 个视频")
        
        // 批量获取所有视频的详细信息（一次调用 yt-dlp）
        if enrichDetails {
            let enrichedVideos = self.batchFetchVideoDetails(videos: videos, ytDlpPath: ytDlpPath)
            return enrichedVideos
        }
        
        return videos
    }
    
    // MARK: - 批量获取视频详情
    private func batchFetchVideoDetails(videos: [VideoItem], ytDlpPath: String) -> [VideoItem] {
        if videos.isEmpty { return videos }
        
        self.appendLog("批量获取 \(videos.count) 个视频的详细信息...")
        
        let semaphore = DispatchSemaphore(value: 0)
        var output: String = ""
        var errorOutput: String = ""
        var terminationStatus: Int32 = -1
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        var environment = ProcessInfo.processInfo.environment
        let originalPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + originalPath
        environment["HOME"] = NSHomeDirectory()
        process.environment = environment
        
        // 构建参数：所有视频 URL 一次性传入
        var arguments = [
            "--extractor-args", "youtube:player_client=web",
            "--dump-json",
            "--skip-download",
            "--no-warnings",
            "--ignore-errors",
            "--playlist-items", "1",
            "--socket-timeout", "15",
            "--retries", "1",
            "--fragment-retries", "1"
        ]
        for video in videos {
            arguments.append(video.url)
        }
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 保存引用以便取消
        self.currentProcess = process
        
        let outputHandle = outputPipe.fileHandleForReading
        self.outputHandle = outputHandle
        outputHandle.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, !self.cancellationToken else { return }
            let data = fileHandle.availableData
            if data.isEmpty { return }
            if let string = String(data: data, encoding: .utf8) {
                output += string
            }
        }
        
        let errorHandle = errorPipe.fileHandleForReading
        self.errorHandle = errorHandle
        errorHandle.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, !self.cancellationToken else { return }
            let data = fileHandle.availableData
            if data.isEmpty { return }
            if let string = String(data: data, encoding: .utf8) {
                errorOutput += string
                self.appendLog("[详情] \(string.prefix(200))\(string.count > 200 ? "..." : "")")
            }
        }
        
        process.terminationHandler = { proc in
            terminationStatus = proc.terminationStatus
            semaphore.signal()
        }
        
        do {
            try process.run()
            
            // 批量获取超时：每个视频15秒 + 基础15秒
            let timeout = Double(videos.count * 15 + 15)
            let timeoutResult = semaphore.wait(timeout: .now() + timeout)
            
            if timeoutResult == .timedOut {
                if process.isRunning {
                    self.appendLog("批量获取详情超时，强制终止...")
                    process.terminate()
                }
                self.currentProcess = nil
            } else {
                self.currentProcess = nil
                self.appendLog("批量详情获取完成，退出状态: \(terminationStatus)")
            }
        } catch {
            self.currentProcess = nil
            self.appendLog("批量获取详情失败: \(error.localizedDescription)")
        }
        
        // 清理文件句柄
        DispatchQueue.main.async { [weak self] in
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            self?.outputHandle = nil
            self?.errorHandle = nil
        }
        
        if self.cancellationToken { return videos }
        
        // 解析批量输出：每行一个视频的 JSON
        var detailMap: [String: [String: Any]] = [:]
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let videoID = json["id"] as? String else { continue }
            detailMap[videoID] = json
        }
        
        self.appendLog("成功解析 \(detailMap.count)/\(videos.count) 个视频详情")
        
        // 合并详情到视频列表
        var enrichedVideos: [VideoItem] = []
        var enrichedCount = 0
        var defaultDateCount = 0
        for video in videos {
            var enriched = false
            if let json = detailMap[video.url.contains("watch") ? 
                (video.url.components(separatedBy: "v=").last ?? video.url) : video.url] {
                enrichedVideos.append(applyVideoDetails(video: video, json: json))
                enriched = true
            } else {
                // 尝试通过 URL 中的 ID 匹配
                let matched = detailMap.values.first { detailJson in
                    if let detailUrl = detailJson["webpage_url"] as? String {
                        return detailUrl == video.url
                    }
                    if let detailId = detailJson["id"] as? String {
                        return video.url.contains(detailId)
                    }
                    return false
                }
                if let matched = matched {
                    enrichedVideos.append(applyVideoDetails(video: video, json: matched))
                    enriched = true
                } else {
                    enrichedVideos.append(video)
                }
            }
            if enriched {
                enrichedCount += 1
            } else if enrichedVideos.last?.publishDate.timeIntervalSince1970 == 0 {
                defaultDateCount += 1
            }
        }
        
        self.appendLog("日期解析统计: 成功丰富 \(enrichedCount) 个, 默认日期 \(defaultDateCount) 个")
        
        return enrichedVideos
    }
    
    // MARK: - 将 JSON 详情应用到 VideoItem
    private func applyVideoDetails(video: VideoItem, json: [String: Any]) -> VideoItem {
        let channel = json["uploader"] as? String ?? json["channel"] as? String ?? video.channel
        
        // 时间解析（与原逻辑一致）
        var publishDate: Date
        let publishTime: String
        
        if let ts = json["timestamp"] as? TimeInterval {
            publishDate = Date(timeIntervalSince1970: ts)
        } else if let ts = json["release_timestamp"] as? TimeInterval {
            publishDate = Date(timeIntervalSince1970: ts)
        } else if let epoch = json["epoch"] as? TimeInterval {
            publishDate = epoch > 1000000000000
                ? Date(timeIntervalSince1970: epoch / 1000)
                : Date(timeIntervalSince1970: epoch)
        } else if let published = json["published"] as? String {
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: published) {
                publishDate = date
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                publishDate = dateFormatter.date(from: published) ?? video.publishDate
            }
        } else if let uploadDateStr = json["upload_date"] as? String, uploadDateStr.count == 8 {
            let year = Int(uploadDateStr[..<uploadDateStr.index(uploadDateStr.startIndex, offsetBy: 4)])!
            let month = Int(uploadDateStr[uploadDateStr.index(uploadDateStr.startIndex, offsetBy: 4)..<uploadDateStr.index(uploadDateStr.startIndex, offsetBy: 6)])!
            let day = Int(uploadDateStr[uploadDateStr.index(uploadDateStr.startIndex, offsetBy: 6)..<uploadDateStr.index(uploadDateStr.startIndex, offsetBy: 8)])!
            var components = DateComponents()
            components.year = year; components.month = month; components.day = day
            components.hour = 12; components.minute = 0; components.second = 0
            publishDate = Calendar.current.date(from: components) ?? video.publishDate
        } else if let releaseDateStr = json["release_date"] as? String, releaseDateStr.count == 8 {
            let year = Int(releaseDateStr[..<releaseDateStr.index(releaseDateStr.startIndex, offsetBy: 4)])!
            let month = Int(releaseDateStr[releaseDateStr.index(releaseDateStr.startIndex, offsetBy: 4)..<releaseDateStr.index(releaseDateStr.startIndex, offsetBy: 6)])!
            let day = Int(releaseDateStr[releaseDateStr.index(releaseDateStr.startIndex, offsetBy: 6)..<releaseDateStr.index(releaseDateStr.startIndex, offsetBy: 8)])!
            var components = DateComponents()
            components.year = year; components.month = month; components.day = day
            components.hour = 12; components.minute = 0; components.second = 0
            publishDate = Calendar.current.date(from: components) ?? video.publishDate
        } else {
            publishDate = video.publishDate
        }
        
        // 安全检查：未来日期修正
        if publishDate > Date() {
            publishDate = Date(timeIntervalSince1970: 0)
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        publishTime = formatter.string(from: publishDate)
        
        // 时长
        let duration: String
        if let durationSeconds = json["duration"] as? Int {
            duration = formatDuration(durationSeconds)
        } else if let durationSeconds = json["duration"] as? Double {
            duration = formatDuration(Int(durationSeconds))
        } else {
            duration = video.duration
        }
        
        return VideoItem(
            title: video.title,
            channel: channel,
            url: video.url,
            publishTime: publishTime,
            publishDate: publishDate,
            duration: duration
        )
    }
}

// MARK: - 定时下载调度器
class SubscriptionScheduler: ObservableObject {
    static let shared = SubscriptionScheduler()
    
    @Published var isScheduled: Bool = false
    @Published var lastTriggered: String = "未触发"
    @Published var scheduledTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    private var timer: Timer?
    private var lastExecutionDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let savedEnabled = UserDefaults.standard.bool(forKey: "sub_scheduler_enabled")
        let savedTimeInterval = UserDefaults.standard.double(forKey: "sub_scheduler_time")
        
        isScheduled = savedEnabled
        
        if savedTimeInterval != 0 {
            scheduledTime = Date(timeIntervalSinceReferenceDate: savedTimeInterval)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 6
            components.minute = 0
            scheduledTime = Calendar.current.date(from: components) ?? Date()
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[定时下载] 🔧 调度器初始化: isScheduled=\(isScheduled), 时间=\(formatter.string(from: scheduledTime)), 当前=\(formatter.string(from: Date()))")
        
        if isScheduled {
            ensureTimerRunning()
        }
    }
    
    func saveAndRefresh() {
        UserDefaults.standard.set(isScheduled, forKey: "sub_scheduler_enabled")
        UserDefaults.standard.set(scheduledTime.timeIntervalSinceReferenceDate, forKey: "sub_scheduler_time")
        
        if isScheduled {
            ensureTimerRunning()
        } else {
            cancelTimer()
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[定时下载] 💾 设置已保存: isScheduled=\(isScheduled), 目标=\(scheduledTime)")
    }
    
    private func ensureTimerRunning() {
        if timer == nil || !timer!.isValid {
            let t = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
                self?.checkSchedule()
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[定时下载] ⏱ 定时器运行中，每10秒检查，当前: \(formatter.string(from: Date())), 目标: \(scheduledTime)")
    }
    
    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        print("[定时下载] 🛑 定时器已停止")
    }
    
    private func checkSchedule() {
        guard isScheduled else { return }
        
        let now = Date()
        let calendar = Calendar.current
        let scheduledComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        guard let schedHour = scheduledComponents.hour,
              let schedMinute = scheduledComponents.minute,
              let nowHour = nowComponents.hour,
              let nowMinute = nowComponents.minute else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[定时下载] 🔍 \(formatter.string(from: now)) | 目标:\(schedHour):\(String(format: "%02d", schedMinute)) | 当前:\(nowHour):\(String(format: "%02d", nowMinute))")
        
        guard nowHour == schedHour && nowMinute == schedMinute else { return }
        
        let today = calendar.startOfDay(for: now)
        if lastExecutionDate == today {
            print("[定时下载] ⏭ 今天已执行过，跳过")
            return
        }
        lastExecutionDate = today
        print("[定时下载] ⏰ 时间匹配！开始执行")
        executeScheduledTask()
    }
    
    private func executeScheduledTask() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        lastTriggered = "触发中 \(formatter.string(from: Date()))"
        print("[定时下载] 🚀 定时任务触发，发送自动下载通知")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .scheduledAutoDownload, object: nil)
        }
    }
}

#Preview {
    SubscriptionsView()
        .frame(width: 1000, height: 600)
}
