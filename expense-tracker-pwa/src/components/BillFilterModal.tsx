import { useState } from 'react';
import { X } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { BillFilter, TransactionType, AccountType } from '../models/types';

interface Props {
  filter: BillFilter;
  onApply: (filter: BillFilter) => void;
  onClose: () => void;
}

export default function BillFilterModal({ filter, onApply, onClose }: Props) {
  const [transactionTypes, setTransactionTypes] = useState<TransactionType[]>(filter.transactionTypes || []);
  const [accountTypes, setAccountTypes] = useState<AccountType[]>(filter.accountTypes || []);
  const [ownerIds, setOwnerIds] = useState<number[]>(filter.ownerIds || []);
  const [categoryIds, setCategoryIds] = useState<number[]>(filter.categoryIds || []);
  const [startDate, setStartDate] = useState(filter.startDate?.toISOString().split('T')[0] || '');
  const [endDate, setEndDate] = useState(filter.endDate?.toISOString().split('T')[0] || '');

  const owners = useLiveQuery(() => db.owners.orderBy('sortOrder').toArray());
  const categories = useLiveQuery(() => db.categories.orderBy('sortOrder').toArray());

  const handleApply = () => {
    onApply({
      transactionTypes: transactionTypes.length > 0 ? transactionTypes : undefined,
      accountTypes: accountTypes.length > 0 ? accountTypes : undefined,
      ownerIds: ownerIds.length > 0 ? ownerIds : undefined,
      categoryIds: categoryIds.length > 0 ? categoryIds : undefined,
      startDate: startDate ? new Date(startDate) : undefined,
      endDate: endDate ? new Date(endDate) : undefined
    });
  };

  const handleReset = () => {
    setTransactionTypes([]);
    setAccountTypes([]);
    setOwnerIds([]);
    setCategoryIds([]);
    setStartDate('');
    setEndDate('');
  };

  const toggleItem = <T,>(array: T[], item: T, setter: (arr: T[]) => void) => {
    setter(array.includes(item) ? array.filter(i => i !== item) : [...array, item]);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b px-6 py-4 flex items-center justify-between">
          <h2 className="text-xl font-bold">筛选条件</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X size={24} />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* 交易类型 */}
          <div>
            <label className="block text-sm font-medium mb-2">交易类型</label>
            <div className="flex gap-2">
              {[
                { value: TransactionType.EXPENSE, label: '支出' },
                { value: TransactionType.INCOME, label: '收入' },
                { value: TransactionType.EXCLUDED, label: '不计入' }
              ].map(type => (
                <button
                  key={type.value}
                  type="button"
                  onClick={() => toggleItem(transactionTypes, type.value, setTransactionTypes)}
                  className={`flex-1 py-2 rounded-lg border ${
                    transactionTypes.includes(type.value)
                      ? 'border-primary-600 bg-primary-200 text-primary-900 font-medium'
                      : 'border-gray-300'
                  }`}
                >
                  {type.label}
                </button>
              ))}
            </div>
          </div>

          {/* 账户类型 */}
          <div>
            <label className="block text-sm font-medium mb-2">账户类型</label>
            <div className="flex gap-2">
              {[
                { value: AccountType.CREDIT, label: '信贷方式' },
                { value: AccountType.SAVINGS, label: '储蓄方式' }
              ].map(type => (
                <button
                  key={type.value}
                  type="button"
                  onClick={() => toggleItem(accountTypes, type.value, setAccountTypes)}
                  className={`flex-1 py-2 rounded-lg border ${
                    accountTypes.includes(type.value)
                      ? 'border-primary-600 bg-primary-200 text-primary-900 font-medium'
                      : 'border-gray-300'
                  }`}
                >
                  {type.label}
                </button>
              ))}
            </div>
          </div>

          {/* 归属人 */}
          <div>
            <label className="block text-sm font-medium mb-2">归属人</label>
            <div className="flex flex-wrap gap-2">
              {owners?.map(owner => (
                <button
                  key={owner.id}
                  type="button"
                  onClick={() => toggleItem(ownerIds, owner.id!, setOwnerIds)}
                  className={`px-4 py-2 rounded-lg border ${
                    ownerIds.includes(owner.id!)
                      ? 'border-primary-600 bg-primary-200 text-primary-900 font-medium'
                      : 'border-gray-300'
                  }`}
                >
                  {owner.name}
                </button>
              ))}
            </div>
          </div>

          {/* 账单类型 */}
          <div>
            <label className="block text-sm font-medium mb-2">账单类型</label>
            <div className="flex flex-wrap gap-2">
              {categories?.map(cat => (
                <button
                  key={cat.id}
                  type="button"
                  onClick={() => toggleItem(categoryIds, cat.id!, setCategoryIds)}
                  className={`px-3 py-1.5 rounded-lg border text-sm ${
                    categoryIds.includes(cat.id!)
                      ? 'border-primary-600 bg-primary-200 text-primary-900 font-medium'
                      : 'border-gray-300'
                  }`}
                >
                  {cat.name}
                </button>
              ))}
            </div>
          </div>

          {/* 日期范围 */}
          <div>
            <label className="block text-sm font-medium mb-2">日期范围</label>
            <div className="grid grid-cols-2 gap-3">
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="px-4 py-2 border rounded-lg"
                placeholder="开始日期"
              />
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="px-4 py-2 border rounded-lg"
                placeholder="结束日期"
              />
            </div>
          </div>

          {/* 按钮 */}
          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={handleReset}
              className="flex-1 py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              重置
            </button>
            <button
              type="button"
              onClick={handleApply}
              className="flex-1 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
            >
              应用
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
