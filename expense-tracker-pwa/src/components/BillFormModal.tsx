import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { Bill, TransactionType } from '../models/types';
import { createBill, updateBill } from '../services/billService';
import { format } from 'date-fns';

interface Props {
  bill?: Bill;
  onClose: () => void;
}

export default function BillFormModal({ bill, onClose }: Props) {
  const [amount, setAmount] = useState(bill?.amount.toString() || '');
  const [transactionType, setTransactionType] = useState<TransactionType>(bill?.transactionType || TransactionType.EXPENSE);
  const [ownerId, setOwnerId] = useState(bill?.ownerId || 0);
  const [paymentMethodId, setPaymentMethodId] = useState(bill?.paymentMethodId || 0);
  const [categoryIds, setCategoryIds] = useState<number[]>(bill?.categoryIds || []);
  const [note, setNote] = useState(bill?.note || '');
  
  // 分离日期和时间
  const [date, setDate] = useState(
    bill?.date 
      ? format(new Date(bill.date), 'yyyy-MM-dd')
      : format(new Date(), 'yyyy-MM-dd')
  );
  const [time, setTime] = useState(
    bill?.date 
      ? format(new Date(bill.date), 'HH:mm:ss')
      : format(new Date(), 'HH:mm:ss')
  );

  const owners = useLiveQuery(() => db.owners.orderBy('sortOrder').toArray());
  const categories = useLiveQuery(() => 
    db.categories.where('transactionType').equals(transactionType).sortBy('sortOrder')
  , [transactionType]);
  
  const paymentMethods = useLiveQuery(async () => {
    if (!ownerId) return [];
    
    // 如果是收入，只显示储蓄方式
    if (transactionType === TransactionType.INCOME) {
      return await db.paymentMethods
        .where('ownerId').equals(ownerId)
        .and(pm => pm.accountType === 'savings')
        .sortBy('sortOrder');
    }
    
    // 支出和不计入显示所有支付方式
    return await db.paymentMethods.where('ownerId').equals(ownerId).sortBy('sortOrder');
  }, [ownerId, transactionType]);

  useEffect(() => {
    if (owners && owners.length > 0 && !ownerId) {
      setOwnerId(owners[0].id!);
    }
  }, [owners]);

  useEffect(() => {
    if (paymentMethods && paymentMethods.length > 0 && !paymentMethodId) {
      setPaymentMethodId(paymentMethods[0].id!);
    }
  }, [paymentMethods]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const amountValue = parseFloat(amount);
    
    // 支出和收入必须是正数
    if (transactionType !== TransactionType.EXCLUDED) {
      if (!amount || amountValue <= 0) {
        alert('请输入有效金额（必须大于0）');
        return;
      }
    } else {
      // 不计入可以是正数或负数，但不能为0
      if (!amount || amountValue === 0) {
        alert('请输入有效金额（不能为0）');
        return;
      }
    }

    if (!ownerId) {
      alert('请选择归属人');
      return;
    }

    if (!paymentMethodId) {
      alert('请选择支付方式');
      return;
    }

    if (categoryIds.length === 0) {
      alert('请选择至少一个账单类型');
      return;
    }

    try {
      // 合并日期和时间
      const dateTime = new Date(`${date}T${time}`);
      
      const billData = {
        amount: parseFloat(amount),
        transactionType,
        ownerId,
        paymentMethodId,
        categoryIds,
        note: note.trim() || undefined,
        date: dateTime
      };

      if (bill?.id) {
        await updateBill(bill.id, billData);
      } else {
        await createBill(billData);
      }

      onClose();
    } catch (error) {
      alert('保存失败：' + (error as Error).message);
    }
  };

  const toggleCategory = (catId: number) => {
    setCategoryIds(prev => 
      prev.includes(catId) ? prev.filter(id => id !== catId) : [...prev, catId]
    );
  };

  const toggleOwner = (id: number) => {
    if (ownerId === id) {
      setOwnerId(0);
      setPaymentMethodId(0);
    } else {
      setOwnerId(id);
      setPaymentMethodId(0);
    }
  };

  const togglePaymentMethod = (id: number) => {
    setPaymentMethodId(paymentMethodId === id ? 0 : id);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
      <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-2xl">
        <div className="sticky top-0 bg-gradient-to-r from-primary-600 to-primary-700 text-white px-6 py-4 flex items-center justify-between rounded-t-2xl">
          <h2 className="text-xl font-bold">{bill ? '编辑账单' : '添加账单'}</h2>
          <button onClick={onClose} className="p-1 hover:bg-white/20 rounded-lg transition-colors">
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {/* 交易类型 */}
          <div>
            <label className="block text-sm font-semibold mb-3 text-gray-700">交易类型</label>
            <div className="flex gap-3">
              {[
                { value: TransactionType.EXPENSE, label: '支出', color: 'red' },
                { value: TransactionType.INCOME, label: '收入', color: 'green' },
                { value: TransactionType.EXCLUDED, label: '不计入', color: 'gray' }
              ].map(type => (
                <button
                  key={type.value}
                  type="button"
                  onClick={() => {
                    setTransactionType(type.value);
                    setCategoryIds([]);
                    setPaymentMethodId(0); // 切换交易类型时清空支付方式
                  }}
                  className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
                    transactionType === type.value
                      ? type.value === 'expense' 
                        ? 'border-red-500 bg-gradient-to-br from-red-50 to-red-100 text-red-700 shadow-md'
                        : type.value === 'income'
                        ? 'border-green-500 bg-gradient-to-br from-green-50 to-green-100 text-green-700 shadow-md'
                        : 'border-gray-500 bg-gradient-to-br from-gray-50 to-gray-100 text-gray-700 shadow-md'
                      : 'border-gray-300 hover:border-gray-400 hover:bg-gray-50'
                  }`}
                >
                  {type.label}
                </button>
              ))}
            </div>
          </div>

          {/* 金额 */}
          <div>
            <label className="block text-sm font-semibold mb-3 text-gray-700">
              金额
              {transactionType === TransactionType.EXCLUDED && (
                <span className="ml-2 text-xs text-gray-500">（正数增加余额/欠费，负数减少余额/欠费）</span>
              )}
            </label>
            <input
              type="number"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-200 transition-all text-lg"
              placeholder={transactionType === TransactionType.EXCLUDED ? "可输入正数或负数" : "0.00"}
              required
            />
          </div>

          {/* 日期和时间 */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm font-semibold mb-3 text-gray-700">日期</label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-200 transition-all"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-semibold mb-3 text-gray-700">时间</label>
              <input
                type="time"
                step="1"
                value={time}
                onChange={(e) => setTime(e.target.value)}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-200 transition-all"
                required
              />
            </div>
          </div>

          {/* 归属人 */}
          <div>
            <label className="block text-sm font-semibold mb-3 text-gray-700">归属人</label>
            <div className="flex flex-wrap gap-2">
              {owners?.map(owner => (
                <button
                  key={owner.id}
                  type="button"
                  onClick={() => toggleOwner(owner.id!)}
                  className={`px-4 py-2 rounded-xl border-2 font-medium transition-all ${
                    ownerId === owner.id
                      ? 'border-green-600 bg-gradient-to-br from-green-200 to-green-300 text-green-900 shadow-md'
                      : 'border-gray-300 hover:border-green-300 hover:bg-green-50'
                  }`}
                >
                  👤 {owner.name}
                </button>
              ))}
            </div>
          </div>

          {/* 支付方式 */}
          <div>
            <label className="block text-sm font-semibold mb-3 text-gray-700">支付方式</label>
            {!ownerId ? (
              <div className="text-sm text-gray-500 py-4 text-center bg-gray-50 rounded-xl border-2 border-dashed border-gray-300">
                请先选择归属人
              </div>
            ) : paymentMethods && paymentMethods.length === 0 ? (
              <div className="text-sm text-gray-500 py-4 text-center bg-gray-50 rounded-xl border-2 border-dashed border-gray-300">
                该归属人暂无支付方式
              </div>
            ) : (
              <div className="flex flex-wrap gap-2">
                {paymentMethods?.map(pm => (
                  <button
                    key={pm.id}
                    type="button"
                    onClick={() => togglePaymentMethod(pm.id!)}
                    className={`px-4 py-2 rounded-xl border-2 font-medium transition-all ${
                      paymentMethodId === pm.id
                        ? 'border-purple-600 bg-gradient-to-br from-purple-200 to-purple-300 text-purple-900 shadow-md'
                        : 'border-gray-300 hover:border-purple-300 hover:bg-purple-50'
                    }`}
                  >
                    💳 {pm.name}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* 账单类型 */}
          <div>
            <label className="block text-sm font-semibold mb-3 text-gray-700">账单类型（可多选）</label>
            <div className="flex flex-wrap gap-2">
              {categories?.map(cat => (
                <button
                  key={cat.id}
                  type="button"
                  onClick={() => toggleCategory(cat.id!)}
                  className={`px-4 py-2 rounded-xl border-2 font-medium transition-all ${
                    categoryIds.includes(cat.id!)
                      ? 'border-primary-600 bg-gradient-to-br from-primary-200 to-primary-300 text-primary-900 shadow-md'
                      : 'border-gray-300 hover:border-primary-300 hover:bg-primary-50'
                  }`}
                >
                  {cat.name}
                </button>
              ))}
            </div>
          </div>

          {/* 备注 */}
          <div>
            <label className="block text-sm font-semibold mb-3 text-gray-700">备注（可选）</label>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-200 transition-all resize-none"
              rows={3}
              placeholder="添加备注..."
            />
          </div>

          {/* 按钮 */}
          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-3 border-2 border-gray-300 rounded-xl hover:bg-gray-50 font-medium transition-all"
            >
              取消
            </button>
            <button
              type="submit"
              className="flex-1 py-3 bg-gradient-to-r from-primary-600 to-primary-700 text-white rounded-xl hover:from-primary-700 hover:to-primary-800 font-medium shadow-lg transition-all"
            >
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
