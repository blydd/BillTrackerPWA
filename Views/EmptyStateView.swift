import SwiftUI

/// 空状态提示视图
/// Empty state view for displaying when no data is available
struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    init(
        icon: String = "tray",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview("Empty Bills") {
    EmptyStateView(
        icon: "doc.text",
        title: "暂无账单",
        message: "点击右上角的 + 按钮创建第一条账单记录",
        actionTitle: "创建账单",
        action: {}
    )
}

#Preview("Empty Categories") {
    EmptyStateView(
        icon: "tag",
        title: "暂无账单类型",
        message: "创建账单类型以便对账单进行分类管理",
        actionTitle: "创建类型",
        action: {}
    )
}

#Preview("Empty Owners") {
    EmptyStateView(
        icon: "person",
        title: "暂无归属人",
        message: "添加家庭成员以便标记账单归属",
        actionTitle: "添加归属人",
        action: {}
    )
}

#Preview("No Results") {
    EmptyStateView(
        icon: "magnifyingglass",
        title: "未找到结果",
        message: "尝试调整筛选条件或清除筛选"
    )
}
