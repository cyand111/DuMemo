//
//  DuWindowViewModel.swift
//  DuMemo
//
//  Created by 嗷嘟嘟 on 2026/1/8.
//

import Foundation
import SwiftUI
import Combine

class DuWindowViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var hoverTimer: Timer?
    
    func handleHover(_ hovering: Bool) {
        if hovering {
            cancelHoverTimer()
            isExpanded = true
        }
        else {
            startHoverTimer()
        }
    }
    
    private func startHoverTimer() {
        cancelHoverTimer()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.isExpanded = false
        }
    }
    
    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }
}
