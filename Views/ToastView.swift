import SwiftUI

/// Toast消息类型
/// Toast message type
enum ToastType {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        case .warning:
            return .orange
        }
    }
}

/// Toast消息配置
/// Toast message configuration
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: TimeInterval
    
    init(
        type: ToastType = .info,
        message: String,
        duration: TimeInterval = 3.0
    ) {
        self.type = type
        self.message = message
        self.duration = duration
    }
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Toast视图
/// Toast notification view
struct ToastView: View {
    let toast: ToastMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.system(size: 20))
            
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
}

/// ViewModifier for displaying toast notifications
/// 用于显示Toast通知的ViewModifier
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let toast = toast {
                VStack {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                                withAnimation {
                                    self.toast = nil
                                }
                            }
                        }
                    
                    Spacer()
                }
                .padding(.top, 50)
                .animation(.spring(), value: toast)
            }
        }
    }
}

extension View {
    /// 添加Toast通知功能
    /// - Parameter toast: 绑定的Toast消息
    /// - Returns: 带有Toast通知功能的视图
    func toast(message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(toast: message))
    }
}

#Preview("Success Toast") {
    VStack {
        Text("Content")
    }
    .toast(message: .constant(ToastMessage(type: .success, message: "操作成功")))
}

#Preview("Error Toast") {
    VStack {
        Text("Content")
    }
    .toast(message: .constant(ToastMessage(type: .error, message: "操作失败，请重试")))
}

#Preview("Info Toast") {
    VStack {
        Text("Content")
    }
    .toast(message: .constant(ToastMessage(type: .info, message: "这是一条提示信息")))
}

#Preview("Warning Toast") {
    VStack {
        Text("Content")
    }
    .toast(message: .constant(ToastMessage(type: .warning, message: "请注意检查输入")))
}
