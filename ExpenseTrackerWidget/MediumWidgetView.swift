import SwiftUI
import WidgetKit

/// 中等尺寸小组件视图
struct MediumWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
                Text("快速记账")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                
                // 最近记账信息
                if let recent = data.recentExpense {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("最近")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("¥\(NSDecimalNumber(decimal: recent.amount).intValue)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // 快速记账按钮网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(data.quickItems.prefix(4).enumerated()), id: \.offset) { index, item in
                    Link(destination: URL(string: "expensetracker://quick?item=\(item.title)")!) {
                        VStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.title2)
                                .foregroundColor(Color.fromName(item.color))
                            
                            Text(item.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Text("¥\(NSDecimalNumber(decimal: item.amount).intValue)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

#Preview(as: .systemMedium) {
    ExpenseTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, widgetData: WidgetData(
        quickItems: QuickExpenseItem.defaultItems,
        recentExpense: RecentExpense(title: "午餐", amount: 25, timestamp: Date())
    ))
}