// 交易类型
export enum TransactionType {
  EXPENSE = 'expense',    // 支出
  INCOME = 'income',      // 收入
  EXCLUDED = 'excluded'   // 不计入
}

// 账户类型
export enum AccountType {
  CREDIT = 'credit',      // 信贷方式（信用卡等）
  SAVINGS = 'savings'     // 储蓄方式（现金、储蓄卡等）
}

// 账单类型
export interface BillCategory {
  id?: number;
  name: string;
  transactionType: TransactionType;
  sortOrder: number;
  createdAt: Date;
}

// 归属人
export interface Owner {
  id?: number;
  name: string;
  sortOrder: number;
  createdAt: Date;
}

// 支付方式
export interface PaymentMethod {
  id?: number;
  name: string;
  accountType: AccountType;
  ownerId: number;
  balance: number;           // 余额（储蓄）或欠费（信贷）
  creditLimit?: number;      // 信用额度（仅信贷）
  billingDay?: number;       // 账单日（仅信贷）
  sortOrder: number;
  createdAt: Date;
}

// 账单
export interface Bill {
  id?: number;
  amount: number;
  transactionType: TransactionType;
  ownerId: number;
  paymentMethodId: number;
  categoryIds: number[];     // 多个类型ID
  note?: string;
  date: Date;
  createdAt: Date;
  updatedAt: Date;
}

// 统计数据
export interface Statistics {
  totalIncome: number;
  totalExpense: number;
  totalExcluded: number;
  netIncome: number;
  byCategory: CategoryStat[];
  byOwner: OwnerStat[];
  byPaymentMethod: PaymentMethodStat[];
}

export interface CategoryStat {
  categoryId: number;
  categoryName: string;
  amount: number;
  count: number;
}

export interface OwnerStat {
  ownerId: number;
  ownerName: string;
  income: number;
  expense: number;
  excluded: number;
  count: number;
}

export interface PaymentMethodStat {
  paymentMethodId: number;
  paymentMethodName: string;
  amount: number;
  count: number;
}

// 筛选条件
export interface BillFilter {
  transactionTypes?: TransactionType[];
  accountTypes?: AccountType[];
  ownerIds?: number[];
  categoryIds?: number[];
  paymentMethodIds?: number[];
  startDate?: Date;
  endDate?: Date;
}

// 日期范围预设
export enum DateRangePreset {
  THIS_MONTH = 'thisMonth',
  LAST_MONTH = 'lastMonth',
  THIS_YEAR = 'thisYear',
  ALL = 'all',
  CUSTOM = 'custom'
}
