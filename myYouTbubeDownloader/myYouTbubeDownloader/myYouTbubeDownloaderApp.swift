//
//  myYouTbubeDownloaderApp.swift
//  myYouTbubeDownloader
//
//  Created by Shylock Wolf on 2026/1/29.
//

import SwiftUI

@main
struct myYouTbubeDownloaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 600)
        }
        .defaultSize(width: 1100, height: 650)
        .windowResizability(.contentMinSize)
        .windowStyle(.automatic)
    }
}
