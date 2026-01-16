import { db } from './db';
import { Bill, Statistics, CategoryStat, OwnerStat, PaymentMethodStat, TransactionType } from '../models/types';

// 计算统计数据
export async function calculateStatistics(bills: Bill[]): Promise<Statistics> {
  // 获取所有相关数据
  const categories = await db.categories.toArray();
  const owners = await db.owners.toArray();
  const paymentMethods = await db.paymentMethods.toArray();

  // 创建映射
  const categoryMap = new Map(categories.map(c => [c.id!, c]));
  const ownerMap = new Map(owners.map(o => [o.id!, o]));
  const paymentMethodMap = new Map(paymentMethods.map(p => [p.id!, p]));

  // 初始化统计
  let totalIncome = 0;
  let totalExpense = 0;
  let totalExcluded = 0;

  const categoryStats = new Map<number, CategoryStat>();
  const ownerStats = new Map<number, OwnerStat>();
  const paymentMethodStats = new Map<number, PaymentMethodStat>();

  // 遍历账单计算统计
  for (const bill of bills) {
    const absAmount = Math.abs(bill.amount);

    // 总计
    if (bill.transactionType === TransactionType.INCOME) {
      totalIncome += absAmount;
    } else if (bill.transactionType === TransactionType.EXPENSE) {
      totalExpense += absAmount;
    } else {
      totalExcluded += absAmount;
    }

    // 按类型统计
    for (const categoryId of bill.categoryIds) {
      const category = categoryMap.get(categoryId);
      if (!category) continue;

      if (!categoryStats.has(categoryId)) {
        categoryStats.set(categoryId, {
          categoryId,
          categoryName: category.name,
          amount: 0,
          count: 0
        });
      }

      const stat = categoryStats.get(categoryId)!;
      stat.amount += absAmount;
      stat.count += 1;
    }

    // 按归属人统计
    const owner = ownerMap.get(bill.ownerId);
    if (owner) {
      if (!ownerStats.has(bill.ownerId)) {
        ownerStats.set(bill.ownerId, {
          ownerId: bill.ownerId,
          ownerName: owner.name,
          income: 0,
          expense: 0,
          excluded: 0,
          count: 0
        });
      }

      const stat = ownerStats.get(bill.ownerId)!;
      if (bill.transactionType === TransactionType.INCOME) {
        stat.income += absAmount;
      } else if (bill.transactionType === TransactionType.EXPENSE) {
        stat.expense += absAmount;
      } else {
        stat.excluded += absAmount;
      }
      stat.count += 1;
    }

    // 按支付方式统计
    const paymentMethod = paymentMethodMap.get(bill.paymentMethodId);
    if (paymentMethod) {
      if (!paymentMethodStats.has(bill.paymentMethodId)) {
        paymentMethodStats.set(bill.paymentMethodId, {
          paymentMethodId: bill.paymentMethodId,
          paymentMethodName: paymentMethod.name,
          amount: 0,
          count: 0
        });
      }

      const stat = paymentMethodStats.get(bill.paymentMethodId)!;
      stat.amount += absAmount;
      stat.count += 1;
    }
  }

  return {
    totalIncome,
    totalExpense,
    totalExcluded,
    netIncome: totalIncome - totalExpense,
    byCategory: Array.from(categoryStats.values()).sort((a, b) => b.amount - a.amount),
    byOwner: Array.from(ownerStats.values()).sort((a, b) => b.expense - a.expense),
    byPaymentMethod: Array.from(paymentMethodStats.values()).sort((a, b) => b.amount - a.amount)
  };
}
