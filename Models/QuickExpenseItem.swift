import Foundation
import SwiftUI

/// 快速记账项目模型
struct QuickExpenseItem: Identifiable, Codable {
    let id = UUID()
    let title: String          // 显示标题
    let amount: Decimal        // 预设金额
    let category: String       // 类别
    let icon: String          // SF Symbol 图标名
    let color: String         // 颜色名称
    
    /// 预设的快速记账项目
    static let defaultItems: [QuickExpenseItem] = [
        QuickExpenseItem(
            title: "早餐",
            amount: 15,
            category: "食",
            icon: "cup.and.saucer.fill",
            color: "orange"
        ),
        QuickExpenseItem(
            title: "午餐",
            amount: 25,
            category: "食",
            icon: "fork.knife",
            color: "green"
        ),
        QuickExpenseItem(
            title: "晚餐",
            amount: 35,
            category: "食",
            icon: "takeoutbag.and.cup.and.straw.fill",
            color: "red"
        ),
        QuickExpenseItem(
            title: "咖啡",
            amount: 20,
            category: "娱乐",
            icon: "cup.and.saucer.fill",
            color: "brown"
        ),
        QuickExpenseItem(
            title: "交通",
            amount: 10,
            category: "行",
            icon: "car.fill",
            color: "blue"
        ),
        QuickExpenseItem(
            title: "购物",
            amount: 100,
            category: "购物",
            icon: "bag.fill",
            color: "purple"
        ),
        QuickExpenseItem(
            title: "娱乐",
            amount: 50,
            category: "娱乐",
            icon: "gamecontroller.fill",
            color: "pink"
        ),
        QuickExpenseItem(
            title: "医疗",
            amount: 80,
            category: "医疗",
            icon: "cross.case.fill",
            color: "red"
        )
    ]
}

/// 小组件配置
struct WidgetConfiguration: Codable {
    var selectedItems: [QuickExpenseItem]
    var maxItems: Int = 4
    
    static let `default` = WidgetConfiguration(
        selectedItems: Array(QuickExpenseItem.defaultItems.prefix(4))
    )
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