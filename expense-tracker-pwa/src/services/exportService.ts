import { db } from './db';
import { Bill, TransactionType } from '../models/types';
import { format } from 'date-fns';

// 导出为 CSV
export async function exportToCSV(bills: Bill[]): Promise<void> {
  // 获取所有相关数据
  const categories = await db.categories.toArray();
  const owners = await db.owners.toArray();
  const paymentMethods = await db.paymentMethods.toArray();

  // 创建映射
  const categoryMap = new Map(categories.map(c => [c.id!, c.name]));
  const ownerMap = new Map(owners.map(o => [o.id!, o.name]));
  const paymentMethodMap = new Map(paymentMethods.map(p => [p.id!, p.name]));

  // CSV 头部
  const headers = ['日期', '时间', '金额', '交易类型', '账单类型', '归属人', '支付方式', '备注'];
  
  // CSV 数据行
  const rows = bills.map(bill => {
    const categoryNames = bill.categoryIds
      .map(id => categoryMap.get(id))
      .filter(Boolean)
      .join(', ');

    const transactionTypeMap = {
      expense: '支出',
      income: '收入',
      excluded: '不计入'
    };

    // 根据交易类型调整金额的正负号
    let exportAmount = bill.amount;
    if (bill.transactionType === TransactionType.INCOME) {
      // 收入：导出为正数
      exportAmount = Math.abs(bill.amount);
    } else if (bill.transactionType === TransactionType.EXPENSE) {
      // 支出：导出为负数
      exportAmount = -Math.abs(bill.amount);
    }
    // 不计入：保持原样（正数或负数）

    return [
      format(bill.date, 'yyyy-MM-dd'),
      format(bill.date, 'HH:mm:ss'),
      exportAmount.toString(),
      transactionTypeMap[bill.transactionType],
      categoryNames,
      ownerMap.get(bill.ownerId) || '',
      paymentMethodMap.get(bill.paymentMethodId) || '',
      bill.note || ''
    ];
  });

  // 组合 CSV 内容
  const csvContent = [
    headers.join(','),
    ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
  ].join('\n');

  // 添加 BOM 以支持中文
  const BOM = '\uFEFF';
  const blob = new Blob([BOM + csvContent], { type: 'text/csv;charset=utf-8;' });

  // 下载文件
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  link.setAttribute('href', url);
  link.setAttribute('download', `账单导出_${format(new Date(), 'yyyyMMdd_HHmmss')}.csv`);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

// 导入 CSV
export async function importFromCSV(file: File): Promise<{ success: number; failed: number; skipped: number }> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = async (e) => {
      try {
        const text = e.target?.result as string;
        const lines = text.split('\n').filter(line => line.trim());
        
        if (lines.length < 2) {
          throw new Error('CSV 文件为空或格式不正确');
        }

        // 跳过头部
        const dataLines = lines.slice(1);
        
        // 获取所有相关数据
        const categories = await db.categories.toArray();
        const owners = await db.owners.toArray();
        const paymentMethods = await db.paymentMethods.toArray();

        // 创建名称到ID的映射
        const categoryNameMap = new Map(categories.map(c => [c.name, c.id!]));
        const ownerNameMap = new Map(owners.map(o => [o.name, o.id!]));
        const paymentMethodNameMap = new Map(paymentMethods.map(p => [p.name, p.id!]));

        // 用于自动创建缺失的数据
        const newCategories = new Set<string>();
        const newOwners = new Set<string>();
        const newPaymentMethods = new Set<string>();

        const transactionTypeMap: Record<string, TransactionType> = {
          '支出': TransactionType.EXPENSE,
          '收入': TransactionType.INCOME,
          '不计入': TransactionType.EXCLUDED
        };

        let success = 0;
        let failed = 0;
        let skipped = 0;

        // 第一遍：收集所有需要创建的数据
        for (const line of dataLines) {
          try {
            const values = parseCSVLine(line);
            if (values.length < 8) continue;

            const [, , , , categoryStr, ownerStr, paymentMethodStr] = values;

            // 收集账单类型
            const categoryNames = categoryStr.split(',').map(s => s.trim()).filter(Boolean);
            for (const name of categoryNames) {
              if (!categoryNameMap.has(name)) {
                newCategories.add(name);
              }
            }

            // 收集归属人
            if (ownerStr && !ownerNameMap.has(ownerStr)) {
              newOwners.add(ownerStr);
            }

            // 收集支付方式
            if (paymentMethodStr && !paymentMethodNameMap.has(paymentMethodStr)) {
              newPaymentMethods.add(paymentMethodStr);
            }
          } catch (error) {
            // 忽略解析错误，第二遍再处理
          }
        }

        // 自动创建缺失的数据
        const now = new Date();
        
        // 创建账单类型
        for (const name of newCategories) {
          const id = await db.categories.add({
            name,
            color: '#6366f1', // 默认靛蓝色
            icon: '📝',
            sortOrder: categories.length + categoryNameMap.size,
            createdAt: now,
            updatedAt: now
          });
          categoryNameMap.set(name, id);
        }

        // 创建归属人
        for (const name of newOwners) {
          const id = await db.owners.add({
            name,
            sortOrder: owners.length + ownerNameMap.size,
            createdAt: now,
            updatedAt: now
          });
          ownerNameMap.set(name, id);
        }

        // 创建支付方式（默认为储蓄方式，余额为0）
        for (const name of newPaymentMethods) {
          const id = await db.paymentMethods.add({
            name,
            accountType: 'savings', // 默认储蓄方式
            balance: 0, // 初始余额为0
            sortOrder: paymentMethods.length + paymentMethodNameMap.size,
            createdAt: now,
            updatedAt: now
          });
          paymentMethodNameMap.set(name, id);
        }

        // 第二遍：导入账单数据

        for (const line of dataLines) {
          try {
            // 改进的 CSV 解析：正确处理引号内的逗号
            const values = parseCSVLine(line);
            
            if (values.length < 8) {
              console.error('列数不足:', values.length, line);
              failed++;
              continue;
            }

            const [dateStr, timeStr, amountStr, typeStr, categoryStr, ownerStr, paymentMethodStr, ...noteArr] = values;
            const note = noteArr.join(','); // 备注可能包含逗号

            // 解析日期时间
            const dateTime = new Date(`${dateStr}T${timeStr || '00:00:00'}`);
            if (isNaN(dateTime.getTime())) {
              console.error('日期时间解析失败:', dateStr, timeStr);
              failed++;
              continue;
            }

            // 解析金额
            const amount = parseFloat(amountStr);
            if (isNaN(amount)) {
              console.error('金额解析失败:', amountStr);
              failed++;
              continue;
            }

            // 解析交易类型
            const transactionType = transactionTypeMap[typeStr];
            if (!transactionType) {
              console.error('交易类型未知:', typeStr);
              failed++;
              continue;
            }

            // 根据交易类型和金额正负号，确定实际存储的金额
            let actualAmount = amount;
            if (transactionType === TransactionType.INCOME) {
              // 收入：存储为正数（CSV中应该是正数）
              actualAmount = Math.abs(amount);
            } else if (transactionType === TransactionType.EXPENSE) {
              // 支出：存储为正数（CSV中应该是负数，取绝对值）
              actualAmount = Math.abs(amount);
            }
            // 不计入：保持原样（正数或负数）

            // 解析账单类型（可能有多个，用逗号+空格分隔）
            const categoryNames = categoryStr.split(',').map(s => s.trim()).filter(Boolean);
            const categoryIds = categoryNames
              .map(name => categoryNameMap.get(name))
              .filter((id): id is number => id !== undefined);

            if (categoryIds.length === 0) {
              console.error('账单类型未找到:', categoryStr, categoryNames);
              failed++;
              continue;
            }

            // 解析归属人
            const ownerId = ownerNameMap.get(ownerStr);
            if (!ownerId) {
              console.error('归属人未找到:', ownerStr);
              failed++;
              continue;
            }

            // 解析支付方式
            const paymentMethodId = paymentMethodNameMap.get(paymentMethodStr);
            if (!paymentMethodId) {
              console.error('支付方式未找到:', paymentMethodStr);
              failed++;
              continue;
            }

            // 检查重复：相同日期时间、金额、交易类型、归属人、支付方式的账单视为重复
            const existingBill = await db.bills
              .where('date')
              .equals(dateTime)
              .and(bill => 
                bill.amount === actualAmount &&
                bill.transactionType === transactionType &&
                bill.ownerId === ownerId &&
                bill.paymentMethodId === paymentMethodId
              )
              .first();

            if (existingBill) {
              console.log('跳过重复账单:', dateStr, timeStr, actualAmount, typeStr);
              skipped++;
              continue;
            }

            // 在事务中创建账单并更新支付方式余额
            await db.transaction('rw', db.bills, db.paymentMethods, async () => {
              const now = new Date();
              
              // 创建账单
              await db.bills.add({
                date: dateTime,
                amount: actualAmount,
                transactionType,
                categoryIds,
                ownerId,
                paymentMethodId,
                note: note || undefined,
                createdAt: now,
                updatedAt: now
              });

              // 更新支付方式余额
              const paymentMethod = await db.paymentMethods.get(paymentMethodId);
              if (paymentMethod) {
                let balanceChange = 0;

                if (paymentMethod.accountType === 'credit') {
                  // 信贷方式：支出增加欠费，收入减少欠费
                  if (transactionType === TransactionType.EXPENSE) {
                    balanceChange = Math.abs(actualAmount);
                  } else if (transactionType === TransactionType.INCOME) {
                    balanceChange = -Math.abs(actualAmount);
                  } else {
                    // 不计入：正数减少欠费（还款），负数增加欠费（借款）
                    balanceChange = -actualAmount;
                  }
                } else {
                  // 储蓄方式：支出减少余额，收入增加余额
                  if (transactionType === TransactionType.EXPENSE) {
                    balanceChange = -Math.abs(actualAmount);
                  } else if (transactionType === TransactionType.INCOME) {
                    balanceChange = Math.abs(actualAmount);
                  } else {
                    // 不计入：正数增加余额，负数减少余额
                    balanceChange = actualAmount;
                  }
                }

                await db.paymentMethods.update(paymentMethodId, {
                  balance: paymentMethod.balance + balanceChange
                });
              }
            });

            success++;
          } catch (error) {
            console.error('导入行失败:', line, error);
            failed++;
          }
        }

        resolve({ success, failed, skipped });
      } catch (error) {
        reject(error);
      }
    };

    reader.onerror = () => reject(new Error('读取文件失败'));
    reader.readAsText(file, 'UTF-8');
  });
}

// 解析 CSV 行，正确处理引号内的逗号
function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;
  
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    
    if (char === '"') {
      // 检查是否是转义的引号
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++; // 跳过下一个引号
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  
  // 添加最后一个字段
  result.push(current.trim());
  
  return result;
}
