import SwiftUI

/// 数据库导出视图
/// Pro 功能：导出完整的 SQLite 数据库文件
struct DatabaseExportView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingUpgradePrompt = false
    @State private var showingExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "externaldrive.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("导出数据库")
                                .font(.headline)
                            Text("备份完整的 SQLite 数据库文件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !subscriptionManager.canExportData {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Pro 功能")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section {
                if subscriptionManager.canExportData {
                    Button {
                        exportDatabase()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("导出数据库文件")
                        }
                    }
                    .disabled(isExporting)
                } else {
                    Button {
                        showingUpgradePrompt = true
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("升级到 Pro 解锁")
                        }
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("说明")
                        .font(.headline)
                    
                    Text("• 导出的数据库文件包含所有账单、分类、归属人和支付方式数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• 可用于数据备份和迁移")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• 文件格式：SQLite (.sqlite)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("数据库导出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            if let fileURL = exportedFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .upgradePrompt(
            isPresented: $showingUpgradePrompt,
            title: "Pro 功能",
            message: "数据库导出功能仅限 Pro 用户使用\n升级解锁完整数据备份和迁移",
            feature: "database_export"
        )
    }
    
    private func exportDatabase() {
        isExporting = true
        errorMessage = nil
        
        Task {
            do {
                let fileURL = try await exportDatabaseFile()
                exportedFileURL = fileURL
                showingExportSheet = true
            } catch {
                errorMessage = "导出失败: \(error.localizedDescription)"
                showingError = true
            }
            isExporting = false
        }
    }
    
    private func exportDatabaseFile() async throws -> URL {
        // 获取数据库文件路径
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DatabaseExportError.pathNotFound
        }
        
        let dbPath = documentsPath.appendingPathComponent("ExpenseTracker.sqlite")
        
        // 检查数据库文件是否存在
        guard fileManager.fileExists(atPath: dbPath.path) else {
            throw DatabaseExportError.databaseNotFound
        }
        
        // 创建临时导出文件
        let tempDir = fileManager.temporaryDirectory
        let timestamp = Int(Date().timeIntervalSince1970)
        let exportFileName = "ExpenseTracker_backup_\(timestamp).sqlite"
        let exportPath = tempDir.appendingPathComponent(exportFileName)
        
        // 复制数据库文件
        try fileManager.copyItem(at: dbPath, to: exportPath)
        
        return exportPath
    }
}

// MARK: - Database Export Errors

enum DatabaseExportError: Error, LocalizedError {
    case pathNotFound
    case databaseNotFound
    case copyFailed
    
    var errorDescription: String? {
        switch self {
        case .pathNotFound:
            return "无法获取文档目录路径"
        case .databaseNotFound:
            return "数据库文件不存在"
        case .copyFailed:
            return "复制数据库文件失败"
        }
    }
}

// MARK: - Preview

struct DatabaseExportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DatabaseExportView()
        }
    }
}
