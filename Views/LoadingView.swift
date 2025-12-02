import SwiftUI

/// 加载状态指示器视图
/// Loading state indicator view
struct LoadingView: View {
    var message: String = "加载中..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// ViewModifier for displaying loading overlay
/// 用于显示加载遮罩层的ViewModifier
struct LoadingOverlayModifier: ViewModifier {
    var isLoading: Bool
    var message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray))
                )
            }
        }
    }
}

extension View {
    /// 添加加载遮罩层
    /// - Parameters:
    ///   - isLoading: 是否正在加载
    ///   - message: 加载提示消息
    /// - Returns: 带有加载遮罩层的视图
    func loadingOverlay(isLoading: Bool, message: String = "加载中...") -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

#Preview {
    LoadingView()
}

#Preview("Loading Overlay") {
    Text("Content")
        .loadingOverlay(isLoading: true)
}
