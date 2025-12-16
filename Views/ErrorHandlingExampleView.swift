import SwiftUI

/// 错误处理和用户反馈示例视图
/// Example view demonstrating error handling and user feedback components
/// 
/// 此视图展示了如何在实际应用中使用所有错误处理和用户反馈组件：
/// - ErrorAlert: 错误提示对话框
/// - Toast: 非阻塞式通知
/// - LoadingView: 加载状态指示器
/// - EmptyStateView: 空状态提示
/// - DeleteConfirmation: 删除确认对话框
struct ErrorHandlingExampleView: View {
    @State private var errorMessage: String?
    @State private var toastMessage: ToastMessage?
    @State private var isLoading = false
    @State private var deleteConfirmation: DeleteConfirmation?
    @State private var items: [String] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    LoadingView(message: "正在加载数据...")
                } else if items.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "暂无数据",
                        message: "点击下方按钮添加一些示例数据",
                        actionTitle: "添加数据",
                        action: addItems
                    )
                } else {
                    List {
                        ForEach(items, id: \.self) { item in
                            HStack {
                                Text(item)
                                Spacer()
                                Button(action: {
                                    showDeleteConfirmation(for: item)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("错误处理示例")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: showSuccessToast) {
                        Label("成功", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: showErrorAlert) {
                        Label("错误", systemImage: "exclamationmark.triangle")
                    }
                    
                    Button(action: simulateLoading) {
                        Label("加载", systemImage: "arrow.clockwise")
                    }
                }
            }
            .errorAlert(errorMessage: $errorMessage)
            .toast(message: $toastMessage)
            .deleteConfirmation(confirmation: $deleteConfirmation)
        }
    }
    
    // MARK: - Actions
    
    private func addItems() {
        items = ["项目 1", "项目 2", "项目 3", "项目 4", "项目 5"]
        toastMessage = ToastMessage(type: .success, message: "已添加 \(items.count) 个项目")
    }
    
    private func showSuccessToast() {
        toastMessage = ToastMessage(type: .success, message: "操作成功完成")
    }
    
    private func showErrorAlert() {
        errorMessage = "这是一个错误提示示例。点击确定关闭此对话框。"
    }
    
    private func simulateLoading() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            toastMessage = ToastMessage(type: .info, message: "数据加载完成")
        }
    }
    
    private func showDeleteConfirmation(for item: String) {
        deleteConfirmation = DeleteConfirmation(
            message: "确定要删除 \"\(item)\" 吗？此操作无法撤销。"
        ) {
            deleteItem(item)
        }
    }
    
    private func deleteItem(_ item: String) {
        items.removeAll { $0 == item }
        toastMessage = ToastMessage(type: .success, message: "已删除 \"\(item)\"")
        
        if items.isEmpty {
            toastMessage = ToastMessage(type: .info, message: "列表已清空")
        }
    }
}

#Preview {
    ErrorHandlingExampleView()
}
