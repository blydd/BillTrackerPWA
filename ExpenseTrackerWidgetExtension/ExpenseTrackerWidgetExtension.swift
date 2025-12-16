import WidgetKit
import SwiftUI

/// 快速记账小组件扩展入口
@main
struct ExpenseTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExpenseTrackerWidget()
    }
}

/// 快速记账小组件
struct ExpenseTrackerWidget: Widget {
    let kind: String = "ExpenseTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpenseTrackerProvider()) { entry in
            ExpenseTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("标签记账")
        .description("快速记录日常支出")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 小组件数据提供器
struct ExpenseTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpenseTrackerEntry {
        ExpenseTrackerEntry(date: Date(), quickItems: QuickExpenseItem.defaultItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseTrackerEntry) -> ()) {
        let entry = ExpenseTrackerEntry(date: Date(), quickItems: QuickExpenseItem.defaultItems)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = ExpenseTrackerEntry(date: currentDate, quickItems: QuickExpenseItem.defaultItems)
        
        // 每小时更新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

/// 小组件时间线条目
struct ExpenseTrackerEntry: TimelineEntry {
    let date: Date
    let quickItems: [QuickExpenseItem]
}

/// 小组件主视图
struct ExpenseTrackerWidgetEntryView: View {
    var entry: ExpenseTrackerProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(quickItems: entry.quickItems)
        case .systemMedium:
            MediumWidgetView(quickItems: entry.quickItems)
        default:
            SmallWidgetView(quickItems: entry.quickItems)
        }
    }
}

/// 小尺寸小组件视图
struct SmallWidgetView: View {
    let quickItems: [QuickExpenseItem]
    
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
            if let firstItem = quickItems.first {
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
        }
        .padding(12)
        .background(Color(.systemBackground))
        .widgetBackground()
    }
}

/// 中等尺寸小组件视图
struct MediumWidgetView: View {
    let quickItems: [QuickExpenseItem]
    
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
            }
            
            // 快速记账按钮网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(quickItems.prefix(4).enumerated()), id: \.offset) { index, item in
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
        .widgetBackground()
    }
}

/// 快速记账项目模型（小组件版本）
struct QuickExpenseItem {
    let title: String
    let amount: Decimal
    let category: String
    let icon: String
    let color: String
    
    static let defaultItems: [QuickExpenseItem] = [
        QuickExpenseItem(title: "早餐", amount: 15, category: "食", icon: "cup.and.saucer.fill", color: "orange"),
        QuickExpenseItem(title: "午餐", amount: 25, category: "食", icon: "fork.knife", color: "green"),
        QuickExpenseItem(title: "晚餐", amount: 35, category: "食", icon: "takeoutbag.and.cup.and.straw.fill", color: "red"),
        QuickExpenseItem(title: "咖啡", amount: 20, category: "娱乐", icon: "cup.and.saucer.fill", color: "brown"),
        QuickExpenseItem(title: "交通", amount: 10, category: "行", icon: "car.fill", color: "blue"),
        QuickExpenseItem(title: "购物", amount: 100, category: "购物", icon: "bag.fill", color: "purple")
    ]
}

extension Color {
    /// 根据颜色名称获取颜色
    static func fromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "brown": return .brown
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .primary
        }
    }
}

extension View {
    /// 兼容不同 iOS 版本的小组件背景设置
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            // iOS 17.0+ 使用 containerBackground API
            self.containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            // iOS 15.0-16.x 使用普通背景
            self
        }
    }
}

// iOS 15.0 兼容的预览代码
@available(iOS 17.0, *)
struct ExpenseTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 小尺寸预览
            ExpenseTrackerWidgetEntryView(entry: ExpenseTrackerEntry(date: Date(), quickItems: QuickExpenseItem.defaultItems))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("小尺寸")
            
            // 中等尺寸预览
            ExpenseTrackerWidgetEntryView(entry: ExpenseTrackerEntry(date: Date(), quickItems: QuickExpenseItem.defaultItems))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("中等尺寸")
        }
    }
}