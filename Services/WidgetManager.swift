import Foundation
import SwiftUI
import WidgetKit

/// 小组件管理器
/// 处理快速记账和小组件更新
@MainActor
class WidgetManager: ObservableObject {
    
    static let shared = WidgetManager()
    
    private let repository: DataRepository
    private let userDefaults = UserDefaults(suiteName: "group.com.expensetracker.shared")
    
    @Published var configuration: WidgetConfiguration
    @Published var isProcessing = false
    
    init(repository: DataRepository? = nil) {
        // 如果没有提供 repository，尝试创建默认的
        if let repo = repository {
            self.repository = repo
        } else {
            do {
                self.repository = try SQLiteRepository()
            } catch {
                print("⚠️ WidgetManager 回退到 UserDefaults")
                self.repository = UserDefaultsRepository()
            }
        }
        
        // 加载配置
        self.configuration = Self.loadConfiguration()
    }
    
    // MARK: - 配置管理
    
    /// 加载小组件配置
    private static func loadConfiguration() -> WidgetConfiguration {
        guard let userDefaults = UserDefaults(suiteName: "group.com.expensetracker.shared"),
              let data = userDefaults.data(forKey: "widget_configuration"),
              let config = try? JSONDecoder().decode(WidgetConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
    
    /// 保存小组件配置
    func saveConfiguration() {
        guard let userDefaults = userDefaults,
              let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        
        userDefaults.set(data, forKey: "widget_configuration")
        
        // 通知小组件更新
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 更新小组件配置
    func updateConfiguration(_ newConfig: WidgetConfiguration) {
        configuration = newConfig
        saveConfiguration()
    }
    
    // MARK: - 快速记账
    
    /// 执行快速记账
    func quickExpense(_ item: QuickExpenseItem) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 获取默认数据
            let owners = try await repository.fetchOwners()
            let paymentMethods = try await repository.fetchPaymentMethods()
            let categories = try await repository.fetchCategories()
            
            guard let defaultOwner = owners.first else {
                print("❌ 没有找到归属人")
                return false
            }
            
            guard let defaultPaymentMethod = paymentMethods.first(where: { $0.ownerId == defaultOwner.id }) else {
                print("❌ 没有找到支付方式")
                return false
            }
            
            // 查找匹配的类别
            let matchedCategory = categories.first { category in
                category.name.contains(item.category) || item.category.contains(category.name)
            }
            
            let categoryId = matchedCategory?.id ?? categories.first?.id ?? UUID()
            
            // 创建账单
            let bill = Bill(
                amount: -abs(item.amount), // 支出为负数
                paymentMethodId: defaultPaymentMethod.id,
                categoryIds: [categoryId],
                ownerId: defaultOwner.id,
                note: "🚀 快速记账：\(item.title)",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 保存账单
            try await repository.saveBill(bill)
            
            print("✅ 快速记账成功：\(item.title) \(item.amount) 元")
            
            // 更新小组件显示最近记账
            await updateRecentExpense(item)
            
            return true
            
        } catch {
            print("❌ 快速记账失败：\(error)")
            return false
        }
    }
    
    /// 更新最近记账信息
    private func updateRecentExpense(_ item: QuickExpenseItem) async {
        guard let userDefaults = userDefaults else { return }
        
        let recentExpense: [String: Any] = [
            "title": item.title,
            "amount": NSDecimalNumber(decimal: item.amount).doubleValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        userDefaults.set(recentExpense, forKey: "recent_expense")
        
        // 通知小组件更新
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - 统计数据
    
    /// 获取今日支出总额（用于小组件显示）
    func getTodayExpenseTotal() async -> Decimal {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            
            let bills = try await repository.fetchBills()
            
            let todayExpenses = bills.filter { bill in
                bill.amount < 0 && // 只计算支出
                bill.createdAt >= today &&
                bill.createdAt < tomorrow
            }
            
            return todayExpenses.reduce(0) { total, bill in
                total + abs(bill.amount)
            }
            
        } catch {
            print("❌ 获取今日支出失败：\(error)")
            return 0
        }
    }
    
    /// 获取本月支出总额
    func getMonthExpenseTotal() async -> Decimal {
        do {
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            
            let bills = try await repository.fetchBills()
            
            let monthExpenses = bills.filter { bill in
                bill.amount < 0 && // 只计算支出
                bill.createdAt >= startOfMonth &&
                bill.createdAt < endOfMonth
            }
            
            return monthExpenses.reduce(0) { total, bill in
                total + abs(bill.amount)
            }
            
        } catch {
            print("❌ 获取本月支出失败：\(error)")
            return 0
        }
    }
}

// MARK: - 小组件数据提供

extension WidgetManager {
    
    /// 获取小组件显示数据
    static func getWidgetData() -> WidgetData {
        let userDefaults = UserDefaults(suiteName: "group.com.expensetracker.shared")
        let configuration = loadConfiguration()
        
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
            configuration: configuration,
            recentExpense: recentExpense
        )
    }
}

/// 小组件显示数据
struct WidgetData {
    let configuration: WidgetConfiguration
    let recentExpense: RecentExpense?
}

/// 最近记账信息
struct RecentExpense {
    let title: String
    let amount: Decimal
    let timestamp: Date
}