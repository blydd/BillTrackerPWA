import Dexie, { Table } from 'dexie';
import { Bill, BillCategory, Owner, PaymentMethod } from '../models/types';

// 数据库类
export class ExpenseTrackerDB extends Dexie {
  bills!: Table<Bill>;
  categories!: Table<BillCategory>;
  owners!: Table<Owner>;
  paymentMethods!: Table<PaymentMethod>;

  constructor() {
    super('ExpenseTrackerDB');
    
    this.version(1).stores({
      bills: '++id, date, transactionType, ownerId, paymentMethodId, createdAt',
      categories: '++id, name, transactionType, sortOrder',
      owners: '++id, name, sortOrder',
      paymentMethods: '++id, name, accountType, ownerId, sortOrder'
    });
  }
}

export const db = new ExpenseTrackerDB();

// 初始化数据
export async function initializeData() {
  const categoryCount = await db.categories.count();
  const ownerCount = await db.owners.count();
  
  if (categoryCount > 0 || ownerCount > 0) {
    throw new Error('数据已存在，无法初始化');
  }

  // 创建归属人
  const owners = [
    { name: '男主', sortOrder: 0, createdAt: new Date() },
    { name: '女主', sortOrder: 1, createdAt: new Date() }
  ];
  const ownerIds = await db.owners.bulkAdd(owners, { allKeys: true });

  // 创建账单类型 - 支出
  const expenseCategories = [
    '衣', '食', '外卖', '下馆子', '超市', '赶集', '转给妈', '住', '电费', '水费',
    '燃气', '房租', '行', '加油', '停车费', '轿车', '摩托', '购物', '京东', '拼多多',
    '淘宝', '米乐', '教育', '医疗', '娱乐', '电影', '保险', '话费', '人情', '老家装修', '其他'
  ].map((name, index) => ({
    name,
    transactionType: 'expense' as const,
    sortOrder: index,
    createdAt: new Date()
  }));

  // 创建账单类型 - 收入
  const incomeCategories = [
    '工资', '保险理赔', '其他'
  ].map((name, index) => ({
    name,
    transactionType: 'income' as const,
    sortOrder: index,
    createdAt: new Date()
  }));

  // 创建账单类型 - 不计入
  const excludedCategories = [
    '还信用卡', '对冲'
  ].map((name, index) => ({
    name,
    transactionType: 'excluded' as const,
    sortOrder: index,
    createdAt: new Date()
  }));

  await db.categories.bulkAdd([...expenseCategories, ...incomeCategories, ...excludedCategories]);

  // 为男主创建支付方式
  const maleOwnerId = ownerIds[0] as number;
  const femaleOwnerId = ownerIds[1] as number;
  
  const paymentMethods = [];
  
  // 男主的信贷方式
  const maleCreditMethods = [
    { name: '青岛信用卡', limit: 40000, billingDay: 15 },
    { name: '广发信用卡', limit: 58000, billingDay: 9 },
    { name: '浦发信用卡', limit: 51000, billingDay: 10 },
    { name: '齐鲁信用卡', limit: 30000, billingDay: 15 },
    { name: '兴业信用卡', limit: 24000, billingDay: 22 },
    { name: '平安信用卡', limit: 70000, billingDay: 7 },
    { name: '华夏信用卡', limit: 46000, billingDay: 8 },
    { name: '交通信用卡', limit: 14000, billingDay: 11 },
    { name: '招商信用卡', limit: 60000, billingDay: 9 },
    { name: '光大信用卡', limit: 38000, billingDay: 1 },
    { name: '中信信用卡', limit: 87000, billingDay: 20 },
    { name: '农行信用卡', limit: 21000, billingDay: 28 },
    { name: '白条', limit: 43046, billingDay: 1 },
    { name: '花呗', limit: 58600, billingDay: 1 }
  ];
  
  maleCreditMethods.forEach((method, index) => {
    paymentMethods.push({
      name: method.name,
      accountType: 'credit' as const,
      ownerId: maleOwnerId,
      balance: 0,
      creditLimit: method.limit,
      billingDay: method.billingDay,
      sortOrder: index,
      createdAt: new Date()
    });
  });
  
  // 女主的信贷方式
  const femaleCreditMethods = [
    { name: '广发信用卡', limit: 34000, billingDay: 18 },
    { name: '齐鲁信用卡', limit: 32000, billingDay: 15 },
    { name: '平安信用卡', limit: 58000, billingDay: 3 },
    { name: '建设信用卡', limit: 10000, billingDay: 26 },
    { name: '招商信用卡', limit: 33000, billingDay: 17 },
    { name: '光大信用卡', limit: 20000, billingDay: 15 },
    { name: '中信信用卡', limit: 87000, billingDay: 2 },
    { name: '交通信用卡', limit: 48000, billingDay: 11 },
    { name: '白条', limit: 19993, billingDay: 1 },
    { name: '花呗', limit: 21300, billingDay: 1 }
  ];
  
  femaleCreditMethods.forEach((method, index) => {
    paymentMethods.push({
      name: method.name,
      accountType: 'credit' as const,
      ownerId: femaleOwnerId,
      balance: 0,
      creditLimit: method.limit,
      billingDay: method.billingDay,
      sortOrder: index,
      createdAt: new Date()
    });
  });
  
  // 男主和女主的储蓄方式
  const savingsMethods = ['微信零钱', '余额宝'];
  
  [maleOwnerId, femaleOwnerId].forEach((ownerId, ownerIndex) => {
    savingsMethods.forEach((name, index) => {
      paymentMethods.push({
        name,
        accountType: 'savings' as const,
        ownerId,
        balance: 0,
        sortOrder: index,
        createdAt: new Date()
      });
    });
  });

  await db.paymentMethods.bulkAdd(paymentMethods);
}

// 清空所有数据
export async function clearAllData() {
  await db.bills.clear();
  await db.categories.clear();
  await db.owners.clear();
  await db.paymentMethods.clear();
}
