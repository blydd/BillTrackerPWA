import WidgetKit
import SwiftUI

/// 记账应用小组件
struct ExpenseTrackerWidget: Widget {
    let kind: String = "ExpenseTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ExpenseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("标签记账")
        .description("快速记录日常支出，支持多种预设项目")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 小组件数据提供器
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), widgetData: getWidgetData())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), widgetData: getWidgetData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, widgetData: getWidgetData())
        
        // 每小时更新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    /// 获取小组件显示数据
    private func getWidgetData() -> WidgetData {
        let userDefaults = UserDefaults(suiteName: "group.com.expensetracker.shared")
        
        // 获取最近记账信息
        var recentExpense: RecentExpense?
        if let recentData = userDefaults?.dictionary(forKey: "recent_expense"),
           let title = recentData["title"] as? String,
           let amount = recentData["amount"] as? Double,
           let timestamp = recentData["timestamp"] as? TimeInterval {
            recentExpense = RecentExpense(
                title: title,
                amount: Decimal(amount),
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
        }
        
        return WidgetData(
            quickItems: QuickExpenseItem.defaultItems,
            recentExpense: recentExpense
        )
    }
}

/// 小组件时间线条目
struct SimpleEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

/// 小组件主视图
struct ExpenseWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.widgetData)
        case .systemMedium:
            MediumWidgetView(data: entry.widgetData)
        default:
            SmallWidgetView(data: entry.widgetData)
        }
    }
}

/// 小组件数据模型
struct WidgetData {
    let quickItems: [QuickExpenseItem]
    let recentExpense: RecentExpense?
}

/// 最近记账信息
struct RecentExpense {
    let title: String
    let amount: Decimal
    let timestamp: Date
}

/// 快速记账项目（小组件版本）
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