# Requirements Document

## Introduction

本文档定义了ExpenseTracker应用的应用内购买（IAP）功能需求。该功能将应用分为免费版和Pro版，通过年订阅（¥12/年）和终身买断（¥38）两种方式提供Pro版功能。免费版限制账单记录数量为500条，Pro版解锁无限账单、云同步、数据导出等高级功能。

## Glossary

- **IAP System**: 应用内购买系统，负责处理购买流程、订阅管理和收据验证
- **Free Tier**: 免费版本，提供基础账单记录功能，最多500条账单
- **Pro Tier**: 专业版本，解锁所有高级功能
- **Subscription**: 年度订阅，价格为¥12/年，自动续订
- **Lifetime Purchase**: 终身买断，一次性支付¥38，永久使用Pro功能
- **Receipt Validator**: 收据验证器，验证购买凭证的有效性
- **Subscription Manager**: 订阅管理器，管理订阅状态和功能权限
- **Purchase UI**: 购买界面，展示功能对比和购买选项
- **Bill Limit**: 账单数量限制，免费版最多500条
- **Feature Gate**: 功能门控，根据订阅状态控制功能访问

## Requirements

### Requirement 1

**User Story:** 作为免费版用户，我希望能够创建最多500条账单记录，以便管理日常基础开销

#### Acceptance Criteria

1. WHEN a free tier user creates a bill AND the total bill count is less than 500 THEN the IAP System SHALL allow the bill creation
2. WHEN a free tier user attempts to create a bill AND the total bill count equals or exceeds 500 THEN the IAP System SHALL prevent the bill creation and display an upgrade prompt
3. WHEN the bill count is checked THEN the IAP System SHALL count all bills regardless of transaction type or category
4. WHEN a free tier user deletes a bill THEN the IAP System SHALL allow creating new bills if the count drops below 500
5. WHEN the bill limit is reached THEN the IAP System SHALL display the current count and the upgrade options

### Requirement 2

**User Story:** 作为用户，我希望能够查看免费版和Pro版的功能对比，以便了解升级后的价值

#### Acceptance Criteria

1. WHEN a user opens the purchase interface THEN the Purchase UI SHALL display a clear comparison of free tier and pro tier features
2. WHEN displaying features THEN the Purchase UI SHALL show free tier includes basic bill recording (max 500), basic statistics, and all management functions
3. WHEN displaying features THEN the Purchase UI SHALL show pro tier includes unlimited bills, cloud sync, CSV export, and database export
4. WHEN displaying pricing THEN the Purchase UI SHALL show annual subscription at ¥12/year and lifetime purchase at ¥38
5. WHEN a user views the comparison THEN the Purchase UI SHALL highlight the value proposition of each tier

### Requirement 3

**User Story:** 作为用户，我希望能够通过年订阅或终身买断购买Pro版，以便选择最适合我的付费方式

#### Acceptance Criteria

1. WHEN a user selects annual subscription THEN the IAP System SHALL initiate a purchase flow for the ¥12/year subscription product
2. WHEN a user selects lifetime purchase THEN the IAP System SHALL initiate a purchase flow for the ¥38 one-time purchase product
3. WHEN a purchase is initiated THEN the IAP System SHALL display the native iOS payment sheet with product details
4. WHEN a purchase completes successfully THEN the IAP System SHALL verify the receipt and unlock pro tier features
5. WHEN a purchase fails THEN the IAP System SHALL display an appropriate error message and maintain the current subscription status

### Requirement 4

**User Story:** 作为Pro版用户，我希望应用能够记住我的购买状态，以便每次打开应用时自动享有Pro功能

#### Acceptance Criteria

1. WHEN the application launches THEN the Subscription Manager SHALL verify the stored receipt with Apple servers
2. WHEN a valid subscription receipt is found THEN the Subscription Manager SHALL unlock pro tier features immediately
3. WHEN a valid lifetime purchase receipt is found THEN the Subscription Manager SHALL unlock pro tier features permanently
4. WHEN an expired subscription is detected THEN the Subscription Manager SHALL revert to free tier and notify the user
5. WHEN receipt verification fails THEN the Subscription Manager SHALL retry verification on next launch while maintaining current status

### Requirement 5

**User Story:** 作为Pro版用户，我希望能够访问云同步功能，以便在多设备间同步我的账单数据

#### Acceptance Criteria

1. WHEN a pro tier user accesses cloud sync settings THEN the Feature Gate SHALL allow full access to CloudKit synchronization
2. WHEN a free tier user attempts to access cloud sync THEN the Feature Gate SHALL display an upgrade prompt
3. WHEN cloud sync is enabled THEN the IAP System SHALL verify pro tier status before initiating sync operations
4. WHEN subscription expires during sync THEN the IAP System SHALL complete the current sync and then disable future syncs

### Requirement 6

**User Story:** 作为Pro版用户，我希望能够导出账单数据为CSV格式，以便在其他工具中分析数据

#### Acceptance Criteria

1. WHEN a pro tier user selects CSV export THEN the Feature Gate SHALL allow the export operation
2. WHEN a free tier user attempts CSV export THEN the Feature Gate SHALL display an upgrade prompt
3. WHEN CSV export is initiated THEN the IAP System SHALL verify pro tier status before generating the file
4. WHEN export completes THEN the IAP System SHALL provide the CSV file through the iOS share sheet

### Requirement 7

**User Story:** 作为Pro版用户，我希望能够导出完整的数据库文件，以便进行数据备份和迁移

#### Acceptance Criteria

1. WHEN a pro tier user selects database export THEN the Feature Gate SHALL allow the export operation
2. WHEN a free tier user attempts database export THEN the Feature Gate SHALL display an upgrade prompt
3. WHEN database export is initiated THEN the IAP System SHALL verify pro tier status before copying the database file
4. WHEN export completes THEN the IAP System SHALL provide the database file through the iOS share sheet

### Requirement 8

**User Story:** 作为年订阅用户，我希望能够管理我的订阅，以便取消或续订

#### Acceptance Criteria

1. WHEN a subscription user opens subscription settings THEN the Purchase UI SHALL display the current subscription status and expiration date
2. WHEN a subscription user selects manage subscription THEN the Purchase UI SHALL open the iOS subscription management interface
3. WHEN a subscription is cancelled THEN the Subscription Manager SHALL continue providing pro features until the expiration date
4. WHEN a subscription auto-renews THEN the Subscription Manager SHALL verify the new receipt and extend the pro tier access

### Requirement 9

**User Story:** 作为开发者，我希望系统能够安全地验证购买凭证，以防止盗版和欺诈

#### Acceptance Criteria

1. WHEN a purchase completes THEN the Receipt Validator SHALL retrieve the receipt from the app bundle
2. WHEN validating a receipt THEN the Receipt Validator SHALL verify the receipt signature with Apple servers
3. WHEN a receipt is valid THEN the Receipt Validator SHALL extract the product ID and expiration date
4. WHEN a receipt is invalid or tampered THEN the Receipt Validator SHALL reject the receipt and maintain free tier status
5. WHEN network is unavailable THEN the Receipt Validator SHALL use cached validation results and retry on next launch

### Requirement 10

**User Story:** 作为用户，我希望在应用的关键位置看到升级提示，以便了解Pro版功能

#### Acceptance Criteria

1. WHEN a free tier user reaches 450 bills THEN the Purchase UI SHALL display a gentle reminder about the 500 bill limit
2. WHEN a free tier user reaches 500 bills THEN the Purchase UI SHALL display a prominent upgrade prompt
3. WHEN a free tier user attempts to use a pro feature THEN the Purchase UI SHALL display a feature-specific upgrade prompt
4. WHEN displaying upgrade prompts THEN the Purchase UI SHALL include a dismiss option that does not block basic functionality
5. WHEN a user dismisses an upgrade prompt THEN the Purchase UI SHALL not show the same prompt again for 24 hours

### Requirement 11

**User Story:** 作为用户，我希望能够恢复之前的购买，以便在重新安装应用或更换设备后继续使用Pro功能

#### Acceptance Criteria

1. WHEN a user selects restore purchases THEN the IAP System SHALL query Apple servers for previous purchases
2. WHEN previous purchases are found THEN the IAP System SHALL verify each receipt and unlock corresponding features
3. WHEN a lifetime purchase is restored THEN the Subscription Manager SHALL unlock pro tier permanently
4. WHEN an active subscription is restored THEN the Subscription Manager SHALL unlock pro tier until expiration
5. WHEN no purchases are found THEN the IAP System SHALL display a message indicating no purchases to restore

### Requirement 12

**User Story:** 作为用户，我希望看到清晰的购买状态指示，以便了解我当前的订阅情况

#### Acceptance Criteria

1. WHEN a user opens settings THEN the Purchase UI SHALL display the current tier status (Free or Pro)
2. WHEN a pro tier user views status THEN the Purchase UI SHALL show the purchase type (Annual Subscription or Lifetime)
3. WHEN an annual subscription user views status THEN the Purchase UI SHALL display the next renewal date
4. WHEN a lifetime purchase user views status THEN the Purchase UI SHALL display "Lifetime Access" with no expiration
5. WHEN subscription status changes THEN the Purchase UI SHALL update the display immediately
