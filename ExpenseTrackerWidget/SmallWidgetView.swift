import SwiftUI
import WidgetKit

/// 小尺寸小组件视图
struct SmallWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(spacing: 8) {
            // 标题栏
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("快速记账")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // 主要快速记账按钮
            if let firstItem = data.quickItems.first {
                Link(destination: URL(string: "expensetracker://quick?item=\(firstItem.title)")!) {
                    VStack(spacing: 6) {
                        Image(systemName: firstItem.icon)
                            .font(.title)
                            .foregroundColor(Color.fromName(firstItem.color))
                        
                        Text(firstItem.title)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("¥\(NSDecimalNumber(decimal: firstItem.amount).intValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // 最近记账信息
            if let recent = data.recentExpense {
                VStack(spacing: 2) {
                    Text("最近记账")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(recent.title) ¥\(NSDecimalNumber(decimal: recent.amount).intValue)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            } else {
                Text("暂无记录")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

#Preview(as: .systemSmall) {
    ExpenseTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData(
        quickItems: QuickExpenseItem.defaultItems,
        recentExpense: RecentExpense(title: "午餐", amount: 25, timestamp: Date())
    ))
}