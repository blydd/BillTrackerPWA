import SwiftUI

/// 数据库信息视图
struct DatabaseInfoView: View {
    @State private var databaseSize: String = "计算中..."
    @State private var databasePath: String = "未知"
    @State private var databaseType: String = "SQLite"
    @State private var showExportSheet = false
    
    var body: some View {
        List {
            Section("数据库信息") {
                HStack {
                    Text("类型")
                    Spacer()
                    Text(databaseType)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("大小")
                    Spacer()
                    Text(databaseSize)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("路径")
                    Text(databasePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            
            Section("操作") {
                Button {
                    exportDatabase()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出数据库")
                    }
                }
                
                Button {
                    copyPath()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("复制路径")
                    }
                }
            }
            
            Section {
                Text("数据库文件存储在应用的 Documents 目录中，可以通过 iTunes/Finder 文件共享功能访问。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("数据库信息")
        .onAppear {
            loadDatabaseInfo()
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = DatabaseManager.exportDatabase() {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func loadDatabaseInfo() {
        databaseSize = DatabaseManager.getDatabaseSize()
        databasePath = DatabaseManager.getDatabasePath() ?? "未知"
        databaseType = "SQLite"
    }
    
    private func exportDatabase() {
        showExportSheet = true
    }
    
    private func copyPath() {
        UIPasteboard.general.string = databasePath
    }
}


