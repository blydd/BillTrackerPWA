import SwiftUI

/// 升级提示视图
/// 用于在功能受限时显示升级提示
struct UpgradePromptView: View {
    let title: String
    let message: String
    let feature: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingPurchase = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    showingPurchase = true
                } label: {
                    Text("升级到 Pro")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("稍后再说")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
    }
}

/// 升级提示修饰符
struct UpgradePromptModifier: ViewModifier {
    let isPresented: Binding<Bool>
    let title: String
    let message: String
    let feature: String
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isPresented) {
                UpgradePromptView(
                    title: title,
                    message: message,
                    feature: feature
                )
                .presentationDetents([.medium])
            }
    }
}

extension View {
    /// 显示升级提示
    func upgradePrompt(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        feature: String
    ) -> some View {
        modifier(UpgradePromptModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            feature: feature
        ))
    }
}

// MARK: - Preview

struct UpgradePromptView_Previews: PreviewProvider {
    static var previews: some View {
        UpgradePromptView(
            title: "升级到 Pro 版",
            message: "解锁无限账单记录和更多高级功能",
            feature: "unlimited_bills"
        )
    }
}
