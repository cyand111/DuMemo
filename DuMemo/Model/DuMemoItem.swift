//
//  DuMemoItem.swift
//  DuMemo
//
//  Created by 嗷嘟嘟 on 2026/1/8.
//

import Foundation

struct DuMemoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var content: String
    var createdAt: Date
    
    init(content: String, createdAt: Date = Date()) {
        self.content = content
        self.createdAt = createdAt
    }
    
    // 预览文本，超过20字符显示"..."
    var previewText: String {
        if content.count > 20 {
            return String(content.prefix(20)) + "..."
        }
        return content
    }
}
