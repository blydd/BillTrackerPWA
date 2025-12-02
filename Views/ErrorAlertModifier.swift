import SwiftUI

/// ViewModifier for displaying error alerts
/// 用于显示错误提示的ViewModifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .alert("错误", isPresented: .constant(errorMessage != nil)) {
                Button("确定", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
    }
}

extension View {
    /// 添加错误提示功能
    /// - Parameter errorMessage: 绑定的错误消息
    /// - Returns: 带有错误提示功能的视图
    func errorAlert(errorMessage: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(errorMessage: errorMessage))
    }
}
