//
//  ContentView.swift
//  DuMemo
//
//  Created by 嗷嘟嘟 on 2026/1/7.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct DuContentView: View {
    @EnvironmentObject var windowViewModel: DuWindowViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(windowViewModel.isExpanded ? Color.blue : Color.duCyan())
                .shadow(radius: 5)
            VStack {
                Text(windowViewModel.isExpanded ? "400×400" : "80×80")
                    .font(windowViewModel.isExpanded ? .title : .headline)
                    .foregroundColor(.white)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: windowViewModel.isExpanded)
        .onHover { hovering in
            windowViewModel.handleHover(hovering)
        }
        .onDrop(of: [.fileURL], isTargeted: $windowViewModel.isTargeted, perform: { providers in
            return windowViewModel.handleFileDrop(providers)            
        })
        .onChange(of: windowViewModel.isExpanded, { oldValue, newValue in
            adjustWindowSize(isExpanding: newValue)
        })
        .background(DuWindowHelper())
    }
    
    private func adjustWindowSize(isExpanding: Bool) {
        withAnimation(.spring(duration: 0.3)) {
            guard let window = NSApplication.shared.windows.first else { return }
            let currentFrame = window.frame
            let newSize = isExpanding ? CGSize(width: 400, height: 400) : CGSize(width: 80, height: 80)
            let newOrigin = CGPoint(
                x: currentFrame.midX - newSize.width / 2,
                y: currentFrame.midY - newSize.height / 2
            )
            window.setFrame(.init(origin: newOrigin, size: newSize), display: true)
        }
    }
}

struct DuWindowHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                setupWindow(window)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private func setupWindow(_ window: NSWindow) {
        window.styleMask = .borderless
        window.level = .floating
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
    }
}
