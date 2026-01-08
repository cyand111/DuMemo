//
//  DuMemoApp.swift
//  DuMemo
//
//  Created by 嗷嘟嘟 on 2026/1/7.
//

// DuMemoApp.swift

import SwiftUI

@main
struct DuMemoApp: App {
    @StateObject private var windowViewModel = DuWindowViewModel()
    var body: some Scene {
        WindowGroup {
            DuContentView()
                .environmentObject(windowViewModel)
        }
        .windowResizability(.contentSize)
    }
}
