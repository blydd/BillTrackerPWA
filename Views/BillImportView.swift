import SwiftUI
import UniformTypeIdentifiers

/// 账单导入视图
/// 支持从CSV和Excel文件导入账单数据，包含去重校验
struct BillImportView: View {
    let repository: DataRepository
    @StateObject private var exportViewModel: ExportViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var showingFilePicker = false
    @State private var showingUpgradePrompt = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    @State private var showingError = false
    @State private var errorMessage: String?
    
    init(repository: DataRepository) {
        self.repository = repository
        _exportViewModel = StateObject(wrappedValue: ExportViewModel(repository: repository))
    }
    
    var body: some View {
        List {
            // 功能介绍
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("导入账单数据")
                                .font(.headline)
                            Text("从CSV或Excel文件导入账单记录")
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
            
            // 导入操作
            Section {
                if subscriptionManager.canExportData {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            if exportViewModel.isImporting {
                                ProgressView()
                            } else {
                                Image(systemName: "doc.badge.plus")
                            }
                            Text("选择文件导入")
                        }
                    }
                    .disabled(exportViewModel.isImporting)
                    
                    if exportViewModel.isImporting {
                        ProgressView(value: exportViewModel.importProgress) {
                            Text("导入进度: \(Int(exportViewModel.importProgress * 100))%")
                                .font(.caption)
                        }
                    }
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
            
            // 支持格式
            Section("支持的文件格式") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("CSV 文件 (.csv)")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "doc.richtext.fill")
                            .foregroundColor(.green)
                        Text("Excel 文件 (.xlsx, .xls)")
                            .font(.subheadline)
                    }
                }
            }
            
            // 文件格式说明
            Section("文件格式要求") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CSV文件必须包含以下列（按顺序）：")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. 日期 (yyyy-MM-dd HH:mm:ss)")
                        Text("2. 金额 (数字，正数为收入，负数为支出)")
                        Text("3. 账单类型 (多个类型用 \"; \" 分隔)")
                        Text("4. 归属人")
                        Text("5. 支付方式")
                        Text("6. 备注 (可选)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // 导入规则
            Section("导入规则") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("自动去重")
                        Spacer()
                    }
                    Text("相同时间、金额、支付方式的记录将被跳过")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("自动创建")
                        Spacer()
                    }
                    Text("不存在的类别、归属人、支付方式将自动创建")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("错误跳过")
                        Spacer()
                    }
                    Text("格式错误的行将被跳过并在结果中报告")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 示例格式
            Section("示例格式") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CSV文件示例：")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("""
                    日期,金额,账单类型,归属人,支付方式,备注
                    2024-01-15 12:30:00,-25.50,食,张三,微信支付,午餐
                    2024-01-15 18:00:00,-35.00,食; 娱乐,李四,支付宝,晚餐聚会
                    2024-01-16 09:00:00,5000.00,工资,张三,银行卡,月薪
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
        }
        .navigationTitle("导入账单")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .spreadsheet, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("导入完成", isPresented: $showingImportResult) {
            Button("确定") { }
        } message: {
            if let result = importResult {
                Text(formatImportResult(result))
            }
        }
        .alert("导入失败", isPresented: $showingError) {
            Button("确定") { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .upgradePrompt(
            isPresented: $showingUpgradePrompt,
            title: "Pro 功能",
            message: "账单导入功能仅限 Pro 用户使用\n升级解锁完整的数据导入导出",
            feature: "data_import"
        )
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            Task {
                do {
                    let result = try await exportViewModel.importFromCSV(fileURL: fileURL)
                    await MainActor.run {
                        importResult = result
                        showingImportResult = true
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            
        case .failure(let error):
            errorMessage = "文件选择失败: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func formatImportResult(_ result: ImportResult) -> String {
        var message = "导入统计：\n"
        message += "• 总行数: \(result.totalLines)\n"
        message += "• 成功导入: \(result.importedCount) 条\n"
        
        if result.duplicateCount > 0 {
            message += "• 重复跳过: \(result.duplicateCount) 条\n"
        }
        
        if result.errorCount > 0 {
            message += "• 错误跳过: \(result.errorCount) 条\n"
        }
        
        if result.createdCategoriesCount > 0 {
            message += "• 新建类别: \(result.createdCategoriesCount) 个\n"
        }
        
        if result.createdOwnersCount > 0 {
            message += "• 新建归属人: \(result.createdOwnersCount) 个\n"
        }
        
        if result.createdPaymentMethodsCount > 0 {
            message += "• 新建支付方式: \(result.createdPaymentMethodsCount) 个"
        }
        
        return message
    }
}

// MARK: - Preview

struct BillImportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BillImportView(repository: UserDefaultsRepository())
        }
    }
}