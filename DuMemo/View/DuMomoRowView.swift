//
//  DuMomoRowView.swift
//  DuMemo
//
//  Created by 嗷嘟嘟 on 2026/1/12.
//

import SwiftUI

struct DuMemoRowView: View {
    let memo: DuMemoItem
    let onDelete: () -> Void
    let onCopy: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 拖拽手柄
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray)
                .font(.system(size: 12))
                .padding(.leading, 4)
            
            // 备忘录内容
            Text(memo.content)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            
            Spacer()
            
            // 删除按钮（悬停时显示）
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contextMenu {
            Button(action: onCopy) {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
