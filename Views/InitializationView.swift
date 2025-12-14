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
                    Text("男主、女主")
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                DisclosureGroup("支付方式") {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("男主信贷方式:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Text("青岛信用卡(4万/15日)、广发信用卡(5.8万/9日)、浦发信用卡(5.1万/10日)、齐鲁信用卡(3万/15日)、兴业信用卡(2.4万/22日)、平安信用卡(7万/7日)、华夏信用卡(4.6万/8日)、交通信用卡(1.4万/11日)、招商信用卡(6万/9日)、光大信用卡(3.8万/1日)、中信信用卡(8.7万/20日)、农行信用卡(2.1万/28日)、白条(4.3万/1日)、花呗(5.86万/1日)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("女主信贷方式:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.pink)
                            Text("广发信用卡(3.4万/18日)、齐鲁信用卡(3.2万/15日)、平安信用卡(5.8万/3日)、建设信用卡(1万/26日)、招商信用卡(3.3万/17日)、光大信用卡(2万/15日)、中信信用卡(8.7万/2日)、交通信用卡(4.8万/11日)、白条(2万/1日)、花呗(2.13万/1日)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("储蓄方式:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("微信零钱、余额宝 (初始余额: 0)")
                                .font(.caption)
                        }
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
