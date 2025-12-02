import SwiftUI

/// 初始化视图
struct InitializationView: View {
    @StateObject private var viewModel: InitializationViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var showingError = false
    
    init(repository: DataRepository) {
        _viewModel = StateObject(wrappedValue: InitializationViewModel(repository: repository))
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("初始化功能说明")
                        .font(.headline)
                    
                    Text("此功能将：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("清除所有现有数据", systemImage: "trash")
                        Label("创建预设的账单类型", systemImage: "tag")
                        Label("创建预设的归属人", systemImage: "person.2")
                        Label("创建预设的支付方式", systemImage: "creditcard")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
                .padding(.vertical, 8)
            }
            
            Section("预设数据") {
                DisclosureGroup("账单类型") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("支出:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("衣、食、住、行、教育、医疗、娱乐、保险、购物、燃气、水费、话费、电费、人情、其他")
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("收入:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("工资、其他")
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("不计入:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("还信用卡")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                DisclosureGroup("归属人") {
                    Text("男主、女主、公主、少主")
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                DisclosureGroup("支付方式") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("信贷:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("花呗、白条、招商信用卡、广发信用卡、兴业信用卡、农行信用卡、光大信用卡")
                                .font(.caption)
                        }
                        Text("(初始额度: 10000, 无欠费)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("储蓄:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("微信零钱、余额宝")
                                .font(.caption)
                        }
                        Text("(初始余额: 0)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button(action: {
                    showingConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        if viewModel.isInitializing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("开始初始化")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isInitializing)
                .foregroundColor(.red)
            }
        }
        .navigationTitle("初始化")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认初始化", isPresented: $showingConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认", role: .destructive) {
                Task {
                    await performInitialization()
                }
            }
        } message: {
            Text("此操作将删除所有现有数据，包括账单、账单类型、归属人和支付方式。此操作不可撤销，确定要继续吗？")
        }
        .alert("初始化成功", isPresented: $showingSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("系统已成功初始化，所有基础数据已创建完成。")
        }
        .alert("初始化失败", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private func performInitialization() async {
        do {
            try await viewModel.initializeData()
            showingSuccess = true
        } catch {
            showingError = true
        }
    }
}
