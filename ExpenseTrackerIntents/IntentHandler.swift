//
//  IntentHandler.swift
//  ExpenseTrackerIntents
//
//  Created by 薄国通 on 2025/12/15.
//

import Intents
import Foundation
import UserNotifications

/// Intent 处理器 - 简化版本
/// 处理来自 Siri 和捷径的记账请求
class IntentHandler: INExtension, INSendMessageIntentHandling {
    
    override func handler(for intent: INIntent) -> Any {
        // 暂时使用消息 Intent 作为替代方案
        return self
    }
    
    // MARK: - INSendMessageIntentHandling
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        
        // 解析消息内容中的记账信息
        guard let content = intent.content else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // 简单的金额提取逻辑
        let amount = extractAmount(from: content)
        let category = extractCategory(from: content)
        
        if amount > 0 {
            // 创建账单数据
            let billData = ExpenseBillData(
                amount: Decimal(amount),
                category: category,
                note: content,
                timestamp: Date()
            )
            
            // 保存到共享数据存储
            Task {
                do {
                    try await saveBillToSharedStorage(billData)
                    
                    // 发送成功通知
                    await notifyMainApp(amount: amount, category: category)
                    
                    let response = INSendMessageIntentResponse(code: .success, userActivity: nil)
                    completion(response)
                    
                } catch {
                    print("保存账单失败: \(error)")
                    completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
                }
            }
        } else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
        }
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        completion(response)
    }
    
    // MARK: - 辅助方法
    
    /// 从文本中提取金额
    private func extractAmount(from text: String) -> Double {
        let pattern = #"(\d+(?:\.\d+)?)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex?.firstMatch(in: text, range: range) {
            let matchRange = Range(match.range, in: text)!
            return Double(text[matchRange]) ?? 0
        }
        
        return 0
    }
    
    /// 从文本中提取类别
    private func extractCategory(from text: String) -> String {
        let categories = ["食", "住", "行", "衣", "娱乐", "购物", "医疗", "教育", "人情"]
        
        for category in categories {
            if text.contains(category) {
                return category
            }
        }
        
        // 检查常见关键词
        if text.contains("午餐") || text.contains("早餐") || text.contains("晚餐") || text.contains("吃") {
            return "食"
        } else if text.contains("打车") || text.contains("地铁") || text.contains("公交") || text.contains("交通") {
            return "行"
        } else if text.contains("购物") || text.contains("买") {
            return "购物"
        }
        
        return "其他"
    }
}

// MARK: - 数据模型

/// 支出账单数据
struct ExpenseBillData: Codable {
    let amount: Decimal
    let category: String
    let note: String?
    let timestamp: Date
    let id: UUID
    
    init(amount: Decimal, category: String, note: String?, timestamp: Date) {
        self.amount = amount
        self.category = category
        self.note = note
        self.timestamp = timestamp
        self.id = UUID()
    }
}

// MARK: - 共享数据存储

/// 保存账单到共享存储
private func saveBillToSharedStorage(_ bill: ExpenseBillData) async throws {
    
    // 使用 App Groups 共享数据
    guard let sharedContainer = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.expensetracker.shared"
    ) else {
        throw IntentError.sharedContainerNotFound
    }
    
    let pendingBillsURL = sharedContainer.appendingPathComponent("pendingBills.json")
    
    // 读取现有的待处理账单
    var pendingBills: [ExpenseBillData] = []
    
    if FileManager.default.fileExists(atPath: pendingBillsURL.path) {
        let data = try Data(contentsOf: pendingBillsURL)
        pendingBills = try JSONDecoder().decode([ExpenseBillData].self, from: data)
    }
    
    // 添加新账单
    pendingBills.append(bill)
    
    // 保存回文件
    let data = try JSONEncoder().encode(pendingBills)
    try data.write(to: pendingBillsURL)
}

/// 通知主应用有新的账单
private func notifyMainApp(amount: Double, category: String) async {
    let content = UNMutableNotificationContent()
    content.title = "记账成功"
    content.body = "已添加 \(amount) 元的\(category)支出"
    content.sound = .default
    
    let request = UNNotificationRequest(
        identifier: "expense_added_\(UUID().uuidString)",
        content: content,
        trigger: nil
    )
    
    do {
        try await UNUserNotificationCenter.current().add(request)
    } catch {
        print("发送通知失败: \(error)")
    }
}

// MARK: - 错误类型

enum IntentError: Error {
    case sharedContainerNotFound
    case invalidAmount
    case saveFailed
}