import { db } from './db';
import { Bill, BillFilter, TransactionType } from '../models/types';

// 创建账单
export async function createBill(bill: Omit<Bill, 'id' | 'createdAt' | 'updatedAt'>): Promise<number> {
  const now = new Date();
  const newBill: Bill = {
    ...bill,
    createdAt: now,
    updatedAt: now
  };

  // 开始事务
  return await db.transaction('rw', db.bills, db.paymentMethods, async () => {
    // 创建账单
    const billId = await db.bills.add(newBill);

    // 更新支付方式余额
    await updatePaymentMethodBalance(bill.paymentMethodId, bill.amount, bill.transactionType);

    return billId;
  });
}

// 更新账单
export async function updateBill(id: number, updates: Partial<Bill>): Promise<void> {
  const oldBill = await db.bills.get(id);
  if (!oldBill) {
    throw new Error('账单不存在');
  }

  return await db.transaction('rw', db.bills, db.paymentMethods, async () => {
    // 如果金额、支付方式或交易类型变化，需要回滚旧余额并应用新余额
    const amountChanged = updates.amount !== undefined && updates.amount !== oldBill.amount;
    const paymentMethodChanged = updates.paymentMethodId !== undefined && updates.paymentMethodId !== oldBill.paymentMethodId;
    const typeChanged = updates.transactionType !== undefined && updates.transactionType !== oldBill.transactionType;

    if (amountChanged || paymentMethodChanged || typeChanged) {
      // 回滚旧余额（反向操作）
      await revertPaymentMethodBalance(oldBill.paymentMethodId, oldBill.amount, oldBill.transactionType);

      // 应用新余额
      const newAmount = updates.amount ?? oldBill.amount;
      const newPaymentMethodId = updates.paymentMethodId ?? oldBill.paymentMethodId;
      const newType = updates.transactionType ?? oldBill.transactionType;
      await updatePaymentMethodBalance(newPaymentMethodId, newAmount, newType);
    }

    // 更新账单
    await db.bills.update(id, {
      ...updates,
      updatedAt: new Date()
    });
  });
}

// 删除账单
export async function deleteBill(id: number): Promise<void> {
  const bill = await db.bills.get(id);
  if (!bill) {
    throw new Error('账单不存在');
  }

  return await db.transaction('rw', db.bills, db.paymentMethods, async () => {
    // 回滚余额（反向操作）
    await revertPaymentMethodBalance(bill.paymentMethodId, bill.amount, bill.transactionType);

    // 删除账单
    await db.bills.delete(id);
  });
}

// 更新支付方式余额
async function updatePaymentMethodBalance(
  paymentMethodId: number,
  amount: number,
  transactionType: TransactionType
): Promise<void> {
  const paymentMethod = await db.paymentMethods.get(paymentMethodId);
  if (!paymentMethod) {
    throw new Error('支付方式不存在');
  }

  let balanceChange = 0;

  if (paymentMethod.accountType === 'credit') {
    // 信贷方式：支出增加欠费，收入减少欠费
    if (transactionType === TransactionType.EXPENSE) {
      balanceChange = Math.abs(amount); // 增加欠费
    } else if (transactionType === TransactionType.INCOME) {
      balanceChange = -Math.abs(amount); // 减少欠费
    } else {
      // 不计入：正数减少欠费（还款），负数增加欠费（借款）
      balanceChange = -amount;
    }
  } else {
    // 储蓄方式：支出减少余额，收入增加余额
    if (transactionType === TransactionType.EXPENSE) {
      balanceChange = -Math.abs(amount); // 减少余额
    } else if (transactionType === TransactionType.INCOME) {
      balanceChange = Math.abs(amount); // 增加余额
    } else {
      // 不计入：正数增加余额，负数减少余额
      balanceChange = amount;
    }
  }

  await db.paymentMethods.update(paymentMethodId, {
    balance: paymentMethod.balance + balanceChange
  });
}

// 回滚支付方式余额（反向操作）
async function revertPaymentMethodBalance(
  paymentMethodId: number,
  amount: number,
  transactionType: TransactionType
): Promise<void> {
  const paymentMethod = await db.paymentMethods.get(paymentMethodId);
  if (!paymentMethod) {
    throw new Error('支付方式不存在');
  }

  let balanceChange = 0;

  if (paymentMethod.accountType === 'credit') {
    // 信贷方式：回滚操作（与 updatePaymentMethodBalance 相反）
    if (transactionType === TransactionType.EXPENSE) {
      balanceChange = -Math.abs(amount); // 减少欠费（回滚支出）
    } else if (transactionType === TransactionType.INCOME) {
      balanceChange = Math.abs(amount); // 增加欠费（回滚收入）
    } else {
      // 不计入：正数增加欠费（回滚还款），负数减少欠费（回滚借款）
      balanceChange = amount;
    }
  } else {
    // 储蓄方式：回滚操作（与 updatePaymentMethodBalance 相反）
    if (transactionType === TransactionType.EXPENSE) {
      balanceChange = Math.abs(amount); // 增加余额（回滚支出）
    } else if (transactionType === TransactionType.INCOME) {
      balanceChange = -Math.abs(amount); // 减少余额（回滚收入）
    } else {
      // 不计入：正数减少余额（回滚），负数增加余额（回滚）
      balanceChange = -amount;
    }
  }

  await db.paymentMethods.update(paymentMethodId, {
    balance: paymentMethod.balance + balanceChange
  });
}

// 获取账单列表（带筛选）
export async function getBills(filter?: BillFilter): Promise<Bill[]> {
  let query = db.bills.orderBy('date').reverse();

  const bills = await query.toArray();

  // 应用筛选
  return bills.filter(bill => {
    if (filter?.transactionTypes && !filter.transactionTypes.includes(bill.transactionType)) {
      return false;
    }

    if (filter?.ownerIds && !filter.ownerIds.includes(bill.ownerId)) {
      return false;
    }

    if (filter?.paymentMethodIds && !filter.paymentMethodIds.includes(bill.paymentMethodId)) {
      return false;
    }

    // 账单类型筛选（AND 逻辑）
    if (filter?.categoryIds && filter.categoryIds.length > 0) {
      const hasAllCategories = filter.categoryIds.every(catId => 
        bill.categoryIds.includes(catId)
      );
      if (!hasAllCategories) {
        return false;
      }
    }

    // 账户类型筛选
    if (filter?.accountTypes && filter.accountTypes.length > 0) {
      // 需要查询支付方式的账户类型（这里简化处理，实际使用时需要预加载）
      // 暂时跳过此筛选
    }

    if (filter?.startDate && bill.date < filter.startDate) {
      return false;
    }

    if (filter?.endDate && bill.date > filter.endDate) {
      return false;
    }

    return true;
  });
}

// 获取账单数量
export async function getBillCount(): Promise<number> {
  return await db.bills.count();
}
