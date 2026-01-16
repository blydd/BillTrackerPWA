import { useState } from 'react';
import { Plus, Edit, Trash2, X, ChevronUp, ChevronDown } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { PaymentMethod, AccountType } from '../models/types';

export default function PaymentMethodManagementView() {
  const [selectedTab, setSelectedTab] = useState<AccountType>(AccountType.CREDIT);
  const [selectedOwnerId, setSelectedOwnerId] = useState<number | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [editingMethod, setEditingMethod] = useState<PaymentMethod | undefined>();
  
  // 表单字段
  const [name, setName] = useState('');
  const [accountType, setAccountType] = useState<AccountType>(AccountType.CREDIT);
  const [ownerId, setOwnerId] = useState<number>(0);
  const [balance, setBalance] = useState('');
  const [creditLimit, setCreditLimit] = useState('');
  const [billingDay, setBillingDay] = useState('1');

  const owners = useLiveQuery(() => db.owners.orderBy('sortOrder').toArray(), []);
  const paymentMethods = useLiveQuery(() => db.paymentMethods.toArray(), []);

  // 设置默认选中的归属人
  if (owners && owners.length > 0 && selectedOwnerId === null) {
    setSelectedOwnerId(owners[0].id!);
  }

  const filteredMethods = paymentMethods
    ?.filter(pm => 
      pm.accountType === selectedTab && 
      (selectedOwnerId === null || pm.ownerId === selectedOwnerId)
    )
    .sort((a, b) => a.sortOrder - b.sortOrder) || [];

  // 计算统计信息
  const statistics = filteredMethods.reduce((acc, pm) => {
    if (pm.accountType === AccountType.CREDIT) {
      acc.totalCreditLimit += pm.creditLimit || 0;
      acc.totalDebt += pm.balance;
      acc.totalAvailable += (pm.creditLimit || 0) - pm.balance;
    } else {
      acc.totalBalance += pm.balance;
    }
    return acc;
  }, {
    totalCreditLimit: 0,
    totalDebt: 0,
    totalAvailable: 0,
    totalBalance: 0
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!name.trim()) {
      alert('请输入支付方式名称');
      return;
    }

    if (!ownerId) {
      alert('请选择归属人');
      return;
    }

    try {
      const data: Omit<PaymentMethod, 'id'> = {
        name: name.trim(),
        accountType,
        ownerId,
        balance: parseFloat(balance) || 0,
        sortOrder: 0,
        createdAt: new Date()
      };

      if (accountType === AccountType.CREDIT) {
        data.creditLimit = parseFloat(creditLimit) || 0;
        data.billingDay = parseInt(billingDay) || 1;
      }

      if (editingMethod?.id) {
        // 更新
        await db.paymentMethods.update(editingMethod.id, data);
      } else {
        // 新增
        const maxOrder = paymentMethods
          ?.filter(pm => pm.accountType === accountType && pm.ownerId === ownerId)
          .reduce((max, pm) => Math.max(max, pm.sortOrder), -1) || -1;
        
        data.sortOrder = maxOrder + 1;
        await db.paymentMethods.add(data as PaymentMethod);
      }
      
      resetForm();
    } catch (error) {
      alert('保存失败：' + (error as Error).message);
    }
  };

  const handleEdit = (method: PaymentMethod) => {
    setEditingMethod(method);
    setName(method.name);
    setAccountType(method.accountType);
    setOwnerId(method.ownerId);
    setBalance(method.balance.toString());
    setCreditLimit(method.creditLimit?.toString() || '');
    setBillingDay(method.billingDay?.toString() || '1');
    setShowForm(true);
  };

  const handleDelete = async (method: PaymentMethod) => {
    if (!confirm(`确定要删除「${method.name}」吗？\n\n注意：相关的账单记录不会被删除，但会失去与此支付方式的关联。`)) {
      return;
    }

    try {
      // 检查是否有关联的账单
      const billCount = await db.bills.where('paymentMethodId').equals(method.id!).count();
      if (billCount > 0) {
        if (!confirm(`该支付方式还有 ${billCount} 条账单记录，确定要删除吗？`)) {
          return;
        }
      }

      await db.paymentMethods.delete(method.id!);
    } catch (error) {
      alert('删除失败：' + (error as Error).message);
    }
  };

  const resetForm = () => {
    setName('');
    setAccountType(AccountType.CREDIT);
    setOwnerId(0);
    setBalance('');
    setCreditLimit('');
    setBillingDay('1');
    setEditingMethod(undefined);
    setShowForm(false);
  };

  const handleMoveUp = async (method: PaymentMethod, index: number) => {
    if (index === 0) return;
    
    const prevMethod = filteredMethods[index - 1];
    
    try {
      await db.transaction('rw', db.paymentMethods, async () => {
        await db.paymentMethods.update(method.id!, { sortOrder: prevMethod.sortOrder });
        await db.paymentMethods.update(prevMethod.id!, { sortOrder: method.sortOrder });
      });
    } catch (error) {
      alert('移动失败：' + (error as Error).message);
    }
  };

  const handleMoveDown = async (method: PaymentMethod, index: number) => {
    if (index === filteredMethods.length - 1) return;
    
    const nextMethod = filteredMethods[index + 1];
    
    try {
      await db.transaction('rw', db.paymentMethods, async () => {
        await db.paymentMethods.update(method.id!, { sortOrder: nextMethod.sortOrder });
        await db.paymentMethods.update(nextMethod.id!, { sortOrder: method.sortOrder });
      });
    } catch (error) {
      alert('移动失败：' + (error as Error).message);
    }
  };

  return (
    <div className="p-4 space-y-4">
      {/* 账户类型 Tab */}
      <div className="flex gap-3">
        <button
          onClick={() => setSelectedTab(AccountType.CREDIT)}
          className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
            selectedTab === AccountType.CREDIT
              ? 'border-primary-500 bg-gradient-to-br from-primary-50 to-primary-100 text-primary-700 shadow-md'
              : 'border-gray-300 hover:border-gray-400 hover:bg-gray-50'
          }`}
        >
          信贷方式
        </button>
        <button
          onClick={() => setSelectedTab(AccountType.SAVINGS)}
          className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
            selectedTab === AccountType.SAVINGS
              ? 'border-primary-500 bg-gradient-to-br from-primary-50 to-primary-100 text-primary-700 shadow-md'
              : 'border-gray-300 hover:border-gray-400 hover:bg-gray-50'
          }`}
        >
          储蓄方式
        </button>
      </div>

      {/* 归属人选择 */}
      {owners && owners.length > 0 && (
        <div className="flex gap-2 overflow-x-auto pb-2">
          {owners.map(owner => (
            <button
              key={owner.id}
              onClick={() => setSelectedOwnerId(owner.id!)}
              className={`px-5 py-2.5 rounded-xl whitespace-nowrap font-medium transition-all shadow-sm ${
                selectedOwnerId === owner.id
                  ? 'bg-gradient-to-r from-primary-600 to-primary-700 text-white shadow-md'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {owner.name}
            </button>
          ))}
        </div>
      )}

      {/* 统计信息 */}
      {filteredMethods.length > 0 && (
        <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-2xl p-5 border border-blue-100 shadow-md">
          <h3 className="font-semibold mb-3 text-gray-800">
            {selectedTab === AccountType.CREDIT ? '信贷方式统计' : '储蓄方式统计'}
          </h3>
          <div className="grid grid-cols-3 gap-4">
            {selectedTab === AccountType.CREDIT ? (
              <>
                <div className="bg-white/70 rounded-xl p-3 backdrop-blur-sm">
                  <div className="text-xs text-gray-600 mb-1">总额度</div>
                  <div className="text-lg font-bold text-blue-600">
                    ¥{statistics.totalCreditLimit.toFixed(2)}
                  </div>
                </div>
                <div className="bg-white/70 rounded-xl p-3 backdrop-blur-sm">
                  <div className="text-xs text-gray-600 mb-1">总欠费</div>
                  <div className="text-lg font-bold text-red-600">
                    ¥{statistics.totalDebt.toFixed(2)}
                  </div>
                </div>
                <div className="bg-white/70 rounded-xl p-3 backdrop-blur-sm">
                  <div className="text-xs text-gray-600 mb-1">总可用</div>
                  <div className="text-lg font-bold text-green-600">
                    ¥{statistics.totalAvailable.toFixed(2)}
                  </div>
                </div>
              </>
            ) : (
              <div className="bg-white/70 rounded-xl p-3 backdrop-blur-sm col-span-3">
                <div className="text-xs text-gray-600 mb-1">总余额</div>
                <div className="text-2xl font-bold text-green-600">
                  ¥{statistics.totalBalance.toFixed(2)}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 添加按钮 */}
      <button
        onClick={() => {
          setAccountType(selectedTab);
          setOwnerId(selectedOwnerId || 0);
          setShowForm(true);
        }}
        className="w-full flex items-center justify-center gap-2 py-3 bg-gradient-to-r from-primary-600 to-primary-700 text-white rounded-xl hover:from-primary-700 hover:to-primary-800 shadow-lg transition-all"
      >
        <Plus size={20} />
        <span className="font-medium">添加支付方式</span>
      </button>

      {/* 支付方式列表 */}
      <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
        {filteredMethods.length === 0 ? (
          <div className="p-12 text-center">
            <div className="text-5xl mb-3">💳</div>
            <div className="text-gray-500">暂无支付方式</div>
          </div>
        ) : (
          filteredMethods.map((method, index) => (
            <div 
              key={method.id} 
              className={`p-4 hover:bg-gradient-to-r hover:from-purple-50 hover:to-transparent transition-all ${
                index !== filteredMethods.length - 1 ? 'border-b' : ''
              }`}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="font-semibold text-lg text-gray-800">{method.name}</div>
                  {method.accountType === AccountType.CREDIT ? (
                    <div className="text-sm space-y-1.5 mt-3">
                      <div className="flex items-center gap-2">
                        <span className="text-gray-500">额度:</span>
                        <span className="font-medium text-blue-600">¥{method.creditLimit?.toFixed(2)}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-gray-500">欠费:</span>
                        <span className="font-medium text-red-600">¥{method.balance.toFixed(2)}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-gray-500">可用:</span>
                        <span className="font-medium text-green-600">
                          ¥{((method.creditLimit || 0) - method.balance).toFixed(2)}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-gray-500">账单日:</span>
                        <span className="font-medium text-gray-700">{method.billingDay}号</span>
                      </div>
                    </div>
                  ) : (
                    <div className="text-sm mt-3">
                      <div className="flex items-center gap-2">
                        <span className="text-gray-500">余额:</span>
                        <span className="font-medium text-green-600">¥{method.balance.toFixed(2)}</span>
                      </div>
                    </div>
                  )}
                </div>
                <div className="flex gap-2 ml-4">
                  <button
                    onClick={() => handleMoveUp(method, index)}
                    disabled={index === 0}
                    className={`p-2 rounded-lg transition-colors ${
                      index === 0
                        ? 'text-gray-300 cursor-not-allowed'
                        : 'text-gray-600 hover:bg-gray-100'
                    }`}
                    title="上移"
                  >
                    <ChevronUp size={18} />
                  </button>
                  <button
                    onClick={() => handleMoveDown(method, index)}
                    disabled={index === filteredMethods.length - 1}
                    className={`p-2 rounded-lg transition-colors ${
                      index === filteredMethods.length - 1
                        ? 'text-gray-300 cursor-not-allowed'
                        : 'text-gray-600 hover:bg-gray-100'
                    }`}
                    title="下移"
                  >
                    <ChevronDown size={18} />
                  </button>
                  <button
                    onClick={() => handleEdit(method)}
                    className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition-colors"
                    title="编辑"
                  >
                    <Edit size={18} />
                  </button>
                  <button
                    onClick={() => handleDelete(method)}
                    className="p-2 text-red-600 hover:bg-red-100 rounded-lg transition-colors"
                    title="删除"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* 表单弹窗 */}
      {showForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl max-w-md w-full max-h-[90vh] overflow-y-auto shadow-2xl">
            <div className="sticky top-0 bg-gradient-to-r from-purple-600 to-purple-700 text-white px-6 py-4 flex items-center justify-between rounded-t-2xl">
              <h2 className="text-xl font-bold">
                {editingMethod ? '编辑支付方式' : '添加支付方式'}
              </h2>
              <button onClick={resetForm} className="p-1 hover:bg-white/20 rounded-lg transition-colors">
                <X size={24} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-semibold mb-3 text-gray-700">名称</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                  placeholder="请输入名称"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold mb-3 text-gray-700">账户类型</label>
                <div className="flex gap-3">
                  <button
                    type="button"
                    onClick={() => setAccountType(AccountType.CREDIT)}
                    className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
                      accountType === AccountType.CREDIT
                        ? 'border-purple-500 bg-gradient-to-br from-purple-50 to-purple-100 text-purple-700 shadow-md'
                        : 'border-gray-300 hover:border-gray-400'
                    }`}
                  >
                    信贷方式
                  </button>
                  <button
                    type="button"
                    onClick={() => setAccountType(AccountType.SAVINGS)}
                    className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
                      accountType === AccountType.SAVINGS
                        ? 'border-purple-500 bg-gradient-to-br from-purple-50 to-purple-100 text-purple-700 shadow-md'
                        : 'border-gray-300 hover:border-gray-400'
                    }`}
                  >
                    储蓄方式
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-semibold mb-3 text-gray-700">归属人</label>
                <select
                  value={ownerId}
                  onChange={(e) => setOwnerId(Number(e.target.value))}
                  className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                  required
                >
                  <option value={0}>请选择</option>
                  {owners?.map(owner => (
                    <option key={owner.id} value={owner.id}>{owner.name}</option>
                  ))}
                </select>
              </div>

              {accountType === AccountType.CREDIT ? (
                <>
                  <div>
                    <label className="block text-sm font-semibold mb-3 text-gray-700">信用额度</label>
                    <input
                      type="number"
                      step="0.01"
                      value={creditLimit}
                      onChange={(e) => setCreditLimit(e.target.value)}
                      className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                      placeholder="0.00"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-semibold mb-3 text-gray-700">
                      {editingMethod ? '当前欠费' : '初始欠费'}
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      value={balance}
                      onChange={(e) => setBalance(e.target.value)}
                      className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                      placeholder="0.00"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-semibold mb-3 text-gray-700">账单日</label>
                    <input
                      type="number"
                      min="1"
                      max="31"
                      value={billingDay}
                      onChange={(e) => setBillingDay(e.target.value)}
                      className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                      required
                    />
                  </div>
                </>
              ) : (
                <div>
                  <label className="block text-sm font-semibold mb-3 text-gray-700">
                    {editingMethod ? '当前余额' : '初始余额'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={balance}
                    onChange={(e) => setBalance(e.target.value)}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                    placeholder="0.00"
                    required
                  />
                </div>
              )}

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={resetForm}
                  className="flex-1 py-3 border-2 border-gray-300 rounded-xl hover:bg-gray-50 font-medium transition-all"
                >
                  取消
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-xl hover:from-purple-700 hover:to-purple-800 font-medium shadow-lg transition-all"
                >
                  保存
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
