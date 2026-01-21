//
//  DuWindowViewModel.swift
//  DuMemo
//
//  Created by 嗷嘟嘟 on 2026/1/8.
//

import Foundation
import SwiftUI
import Combine
import PythonKit

class DuWindowViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var hoverTimer: Timer?
    @Published var isTargeted = false
    
    //MARK: Hover
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
    
    //MARK: Drop File
    // 保存用户授权的目标目录书签，用于下次启动时恢复权限
    @AppStorage("AuthorizedAppLogDirectoryBookmark") private var directoryBookmark: Data?
    
    func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                DispatchQueue.main.async {
                    guard let self = self, let sourceURL = url else { return }
                    self.prepareAndMoveFile(sourceURL)
                }
            }
        }
        return true
    }
    
    private func prepareAndMoveFile(_ sourceURL: URL) {
        // 1. 首先尝试用之前保存的“书签”恢复访问权限
        if let bookmarkData = directoryBookmark,
           let targetDirectory = restoreDirectoryAccess(with: bookmarkData) {
            // 已有权限，直接移动
            moveFile(from: sourceURL, to: targetDirectory)
            return
        }
        
        // 2. 如果没有保存的权限，则弹出系统对话框让用户选择目录
        let openPanel = NSOpenPanel()
        openPanel.title = "请选择或创建 appLog 目录以授权"
        openPanel.message = "此操作将授权应用向该目录移动文件。\n请导航至 /Users/aodudu/appLog 并点击“打开”。"
        openPanel.prompt = "授权" // 按钮文字
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true // 允许用户创建目录
        
        // 默认定位到我们想要的目录路径
        let defaultURL = URL(fileURLWithPath: "/Users/aodudu/appLog")
        openPanel.directoryURL = defaultURL
        
        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK, let selectedURL = openPanel.url else {
                print("用户取消或未选择目录")
                return
            }
            
            // 3. 保存用户选择的目录访问权限（书签）
            self.saveDirectoryAccess(for: selectedURL)
            
            // 4. 移动文件
            self.moveFile(from: sourceURL, to: selectedURL)
        }
    }
    
    private func moveFile(from sourceURL: URL, to targetDirectory: URL) {
        let destinationURL = resolveDestinationURL(sourceURL: sourceURL, targetDirectory: targetDirectory)
        
        do {
            // 确保目标目录存在
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            // 移动文件
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("✅ 文件已移动：\(sourceURL.lastPathComponent) → \(destinationURL.path)")
            executePythonScript()
        } catch {
            print("❌ 移动文件失败：\(error.localizedDescription)")
        }
    }
    
    // 以下两个辅助方法保持不变
    private func resolveDestinationURL(sourceURL: URL, targetDirectory: URL) -> URL {
        let originalName = sourceURL.lastPathComponent
        var destinationURL = targetDirectory.appendingPathComponent(originalName)
        
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let nameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
            let fileExtension = sourceURL.pathExtension
            let newName = fileExtension.isEmpty ?
                "\(nameWithoutExtension)_\(counter)" :
                "\(nameWithoutExtension)_\(counter).\(fileExtension)"
            destinationURL = targetDirectory.appendingPathComponent(newName)
            counter += 1
        }
        return destinationURL
    }
    
    // 保存目录访问权限书签
    private func saveDirectoryAccess(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil)
            directoryBookmark = bookmarkData
            print("已保存目录访问权限：\(url.path)")
        } catch {
            print("保存目录书签失败：\(error)")
        }
    }
    
    // 恢复目录访问权限
    private func restoreDirectoryAccess(with bookmarkData: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                             options: .withSecurityScope,
                             relativeTo: nil,
                             bookmarkDataIsStale: &isStale)
            if isStale {
                // 书签已过期，重新保存
                saveDirectoryAccess(for: url)
            }
            // 开始安全作用域访问
            if url.startAccessingSecurityScopedResource() {
                return url
            }
        } catch {
            print("恢复目录访问失败：\(error)")
        }
        return nil
    }
    
    //MARK: 执行脚本
    func executePythonScript() {
        let scriptPath = DuFilePath.decryptAppLogScript
        let workingDirectory = "/Users/aodudu/appLog"
        
        // 1. 检查脚本文件是否存在
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            print("❌ Python 脚本不存在: \(scriptPath)")
            return
        }
        
        // 2. 检查工作目录是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workingDirectory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("❌ 工作目录不存在或不是目录: \(workingDirectory)")
            return
        }
        
        // 3. 使用确定的 Python 路径
        let pythonPath = "/Users/aodudu/miniconda3/envs/myenv/bin/python3.9"
        
        // 4. 检查 Python 可执行文件是否存在
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            print("❌ Python 可执行文件不存在: \(pythonPath)")
            return
        }
        
        print("✅ 工作目录: \(workingDirectory)")
        print("✅ 使用 Python: \(pythonPath)")
        print("✅ 执行脚本: \(scriptPath)")
        
        // 5. 创建 Process
        let process = Process()
        
        // 6. 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        // 添加 conda 环境的路径
        environment["PATH"] = "/Users/aodudu/miniconda3/envs/myenv/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        
        // 7. 设置当前工作目录
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        // 8. 设置可执行文件路径
        process.executableURL = URL(fileURLWithPath: pythonPath)
        
        // 9. 设置参数（脚本路径）
        process.arguments = [scriptPath]
        
        // 10. 设置输出管道
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 11. 执行并处理结果
        do {
            print("🚀 开始执行 Python 脚本...")
            try process.run()
            
            // 异步读取输出
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            if !output.isEmpty {
                print("📝 脚本输出:\n\(output)")
            }
            
            if !errorOutput.isEmpty {
                print("⚠️ 脚本错误输出:\n\(errorOutput)")
            }
            
            print("✅ Python 脚本执行完成，退出代码: \(process.terminationStatus)")
            
            openAllTextFilesWithVSCodeCommand(at: DuFilePath.appLog)
            
        } catch {
            print("❌ 执行失败: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("错误域: \(nsError.domain)")
                print("错误代码: \(nsError.code)")
                print("错误信息: \(nsError.userInfo)")
            }
        }
    }
    
    //MARK: open file
    func openAllTextFilesWithVSCodeCommand(at directoryPath: String) {
        // 1. 检查目录是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("❌ 目录不存在或不是目录: \(directoryPath)")
            return
        }
        
        // 2. 查找所有 .txt 文件
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: directoryPath)
            
            // 过滤 .txt 文件
            let txtFiles = items.filter { $0.lowercased().hasSuffix(".txt") }
            
            guard !txtFiles.isEmpty else {
                print("ℹ️ 目录中没有找到 .txt 文件: \(directoryPath)")
                return
            }
            
            print("📁 找到 \(txtFiles.count) 个 .txt 文件:")
            
            // 3. 构建完整路径
            let fullPaths = txtFiles.map { (directoryPath as NSString).appendingPathComponent($0) }
            
            // 4. 使用 code 命令打开所有文件
            openFilesWithCodeCommand(fullPaths, inDirectory: directoryPath)
            
        } catch {
            print("❌ 读取目录内容失败: \(error)")
        }
    }

    // 使用 code 命令打开多个文件
    func openFilesWithCodeCommand(_ filePaths: [String], inDirectory directoryPath: String) {
        guard !filePaths.isEmpty else { return }
        
        let process = Process()
        
        // 构建 code 命令参数
        var arguments = filePaths
        
        // 如果文件太多，可以限制数量（VSCode 可以处理很多文件，但为了性能考虑）
        if filePaths.count > 20 {
            print("⚠️ 文件数量较多 (\(filePaths.count) 个)，将只打开前 20 个")
            arguments = Array(filePaths.prefix(20))
        }
        
        // 查找 code 命令路径
        if let codePath = findCodeCommandPath() {
            process.executableURL = URL(fileURLWithPath: codePath)
            process.arguments = arguments
        } else {
            // 尝试通过 bash 执行
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            
            // 将所有文件路径用引号包裹，用空格连接
            let pathsString = arguments.map { "\"\($0)\"" }.joined(separator: " ")
            process.arguments = ["-c", "code \(pathsString)"]
        }
        
        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        
        // 设置输出管道
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            print("🚀 尝试使用 VSCode 打开 \(arguments.count) 个文件...")
            try process.run()
            
            // 异步读取输出
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            // 检查执行结果
            if process.terminationStatus == 0 {
                print("✅ 所有文件已发送到 VSCode")
            } else {
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                if errorOutput.contains("command not found") || errorOutput.contains("No such file or directory") {
                    print("⚠️ code 命令未找到，请确保 VSCode 已安装并添加到 PATH")
                    print("   安装方法：在 VSCode 中按 Cmd+Shift+P，搜索 'Shell Command'，安装 'code' 命令")
                    // 使用默认编辑器打开
                    openFilesWithDefaultEditor(arguments)
                } else if errorOutput.contains("too many open files") {
                    print("⚠️ 文件太多，尝试分批打开...")
                    openFilesInBatches(arguments, batchSize: 10)
                } else {
                    print("⚠️ VSCode 打开失败: \(errorOutput)")
                }
            }
            
        } catch {
            print("❌ 执行失败: \(error)")
            // 使用默认编辑器打开
            openFilesWithDefaultEditor(arguments)
        }
    }

    // 查找 code 命令路径
    func findCodeCommandPath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/code",
            "/usr/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/Applications/VSCode.app/Contents/Resources/app/bin/code"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        return nil
    }

    // 分批打开文件（避免太多文件导致问题）
    func openFilesInBatches(_ filePaths: [String], batchSize: Int) {
        let batches = stride(from: 0, to: filePaths.count, by: batchSize).map {
            Array(filePaths[$0..<min($0 + batchSize, filePaths.count)])
        }
        
        for (index, batch) in batches.enumerated() {
            print("📦 打开第 \(index + 1)/\(batches.count) 批 (\(batch.count) 个文件)...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                openFilesWithCodeCommand(batch, inDirectory: "")
            }
        }
    }

    // 使用默认编辑器打开文件
    func openFilesWithDefaultEditor(_ filePaths: [String]) {
        print("📝 使用默认编辑器打开文件...")
        let workspace = NSWorkspace.shared
        
        for filePath in filePaths {
            let fileURL = URL(fileURLWithPath: filePath)
            workspace.open(fileURL)
        }
    }
}
