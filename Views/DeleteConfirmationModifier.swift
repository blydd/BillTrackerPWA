import SwiftUI

/// 删除确认对话框配置
/// Delete confirmation dialog configuration
struct DeleteConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmAction: () -> Void
    
    init(
        title: String = "确认删除",
        message: String,
        confirmAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmAction = confirmAction
    }
}

/// ViewModifier for displaying delete confirmation dialog
/// 用于显示删除确认对话框的ViewModifier
struct DeleteConfirmationModifier: ViewModifier {
    @Binding var confirmation: DeleteConfirmation?
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                confirmation?.title ?? "确认删除",
                isPresented: .constant(confirmation != nil),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    confirmation?.confirmAction()
                    confirmation = nil
                }
                Button("取消", role: .cancel) {
                    confirmation = nil
                }
            } message: {
                if let message = confirmation?.message {
                    Text(message)
                }
            }
    }
}

extension View {
    /// 添加删除确认对话框
    /// - Parameter confirmation: 绑定的删除确认配置
    /// - Returns: 带有删除确认对话框的视图
    func deleteConfirmation(confirmation: Binding<DeleteConfirmation?>) -> some View {
        modifier(DeleteConfirmationModifier(confirmation: confirmation))
    }
}
