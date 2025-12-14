import SwiftUI
import StoreKit

/// 购买界面
/// 展示功能对比和购买选项
struct PurchaseView: View {
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRestoreAlert = false
    @State private var restoreSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 当前状态
                    currentStatusSection
                    
                    // 功能对比
                    featureComparisonSection
                    
                    // 购买选项
                    if !subscriptionManager.isProUser {
                        purchaseOptionsSection
                    }
                    
                    // 恢复购买
                    restorePurchasesButton
                }
                .padding()
            }
            .navigationTitle("升级到 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("恢复购买", isPresented: $showingRestoreAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(restoreSuccess ? "购买恢复成功！" : "未找到可恢复的购买")
            }
            .task {
                await iapManager.loadProducts()
            }
        }
    }
    
    // MARK: - Current Status Section
    
    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "star")
                .font(.system(size: 50))
                .foregroundColor(subscriptionManager.isProUser ? .yellow : .gray)
            
            Text(subscriptionManager.subscriptionStatus.displayStatus)
                .font(.title2)
                .fontWeight(.bold)
            
            if subscriptionManager.isProUser {
                Text("感谢您的支持！")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Feature Comparison Section
    
    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("功能对比")
                .font(.headline)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "doc.text",
                    title: "账单记录",
                    freeValue: "最多 500 条",
                    proValue: "无限制"
                )
                
                FeatureRow(
                    icon: "chart.bar",
                    title: "基础统计",
                    freeValue: "✓",
                    proValue: "✓"
                )
                
                FeatureRow(
                    icon: "gearshape",
                    title: "管理功能",
                    freeValue: "✓",
                    proValue: "✓"
                )
                
                Divider()
                
                FeatureRow(
                    icon: "icloud",
                    title: "云同步",
                    freeValue: "✗",
                    proValue: "✓",
                    highlight: true
                )
                
                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "导出 CSV",
                    freeValue: "✗",
                    proValue: "✓",
                    highlight: true
                )
                
                FeatureRow(
                    icon: "externaldrive",
                    title: "导出数据库",
                    freeValue: "✗",
                    proValue: "✓",
                    highlight: true
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Purchase Options Section
    
    private var purchaseOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择方案")
                .font(.headline)
            
            VStack(spacing: 12) {
                // 终身买断
                if let lifetimeProduct = iapManager.product(for: .lifetimePurchase) {
                    PurchaseOptionCard(
                        product: lifetimeProduct,
                        title: "终身买断",
                        subtitle: "一次购买，永久使用",
                        badge: "推荐",
                        isLoading: iapManager.isLoading
                    ) {
                        await purchaseProduct(lifetimeProduct)
                    }
                } else {
                    // 备用显示 - 终身买断
                    StaticPurchaseCard(
                        title: "终身买断",
                        price: "¥43",
                        subtitle: "一次购买，永久使用",
                        badge: "推荐"
                    )
                }
                
                // 年订阅
                if let annualProduct = iapManager.product(for: .annualSubscription) {
                    PurchaseOptionCard(
                        product: annualProduct,
                        title: "年订阅",
                        subtitle: "自动续订，随时取消",
                        badge: nil,
                        isLoading: iapManager.isLoading
                    ) {
                        await purchaseProduct(annualProduct)
                    }
                } else {
                    // 备用显示 - 年订阅
                    StaticPurchaseCard(
                        title: "年订阅",
                        price: "¥18/年",
                        subtitle: "自动续订，随时取消",
                        badge: nil
                    )
                }
            }
            
            // 调试信息
            if iapManager.products.isEmpty && !iapManager.isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🧪 当前为测试模式")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("• StoreKit 配置文件可能未正确加载")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• 真实购买需要在 App Store Connect 中配置产品")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            // 产品加载状态
            if iapManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在加载产品...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 错误信息
            if let error = iapManager.errorMessage {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Restore Purchases Button
    
    private var restorePurchasesButton: some View {
        Button {
            Task {
                let success = await iapManager.restorePurchases()
                restoreSuccess = success
                showingRestoreAlert = true
            }
        } label: {
            Text("恢复购买")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(iapManager.isLoading)
    }
    
    // MARK: - Actions
    
    private func purchaseProduct(_ product: Product) async {
        let success = await iapManager.purchase(product)
        if success {
            dismiss()
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let freeValue: String
    let proValue: String
    var highlight: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(highlight ? .blue : .primary)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(freeValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .center)
            
            Text(proValue)
                .font(.caption)
                .fontWeight(highlight ? .semibold : .regular)
                .foregroundColor(highlight ? .blue : .secondary)
                .frame(width: 60, alignment: .center)
        }
    }
}

// MARK: - Purchase Option Card

struct PurchaseOptionCard: View {
    let product: Product
    let title: String
    let subtitle: String
    let badge: String?
    let isLoading: Bool
    let onPurchase: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await onPurchase()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - 静态购买卡片（备用显示）

struct StaticPurchaseCard: View {
    let title: String
    let price: String
    let subtitle: String
    let badge: String?
    
    @State private var showingTestAlert = false
    
    var body: some View {
        Button {
            showingTestAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let badge = badge {
                                Text(badge)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(price)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Image(systemName: "flask")
                        .foregroundColor(.orange)
                    Text("测试模式 - 点击查看说明")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .alert("测试模式说明", isPresented: $showingTestAlert) {
            Button("了解", role: .cancel) { }
        } message: {
            Text("当前为开发测试模式。真实的购买功能需要：\n\n1. 付费 Apple Developer 账户\n2. 在 App Store Connect 中配置产品\n3. 通过 TestFlight 或 App Store 分发\n\n价格：\(title) - \(price)")
        }
    }
}

// MARK: - Preview

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
    }
}
