import { db } from './db';
import { format } from 'date-fns';

// 自动备份间隔选项（天数）
export const AUTO_BACKUP_INTERVALS = {
  DAILY: 1,
  THREE_DAYS: 3,
  WEEKLY: 7,
  DISABLED: 0
} as const;

export type AutoBackupInterval = typeof AUTO_BACKUP_INTERVALS[keyof typeof AUTO_BACKUP_INTERVALS];

// 检查浏览器是否支持 File System Access API
export function isFileSystemAccessSupported(): boolean {
  try {
    return typeof window !== 'undefined' && 'showDirectoryPicker' in window;
  } catch {
    return false;
  }
}

// 请求文件夹访问权限
export async function requestBackupDirectory(): Promise<FileSystemDirectoryHandle | null> {
  try {
    if (!isFileSystemAccessSupported()) {
      throw new Error('您的浏览器不支持文件系统访问功能，请使用 Chrome、Edge 或其他支持的浏览器');
    }

    // 请求用户选择备份文件夹
    const dirHandle = await window.showDirectoryPicker({
      mode: 'readwrite',
      startIn: 'documents'
    });

    // 保存文件夹句柄到 IndexedDB（用于后续自动备份）
    await saveDirectoryHandle(dirHandle);

    return dirHandle;
  } catch (error) {
    if ((error as Error).name === 'AbortError') {
      // 用户取消选择
      return null;
    }
    throw error;
  }
}

// 保存文件夹句柄
async function saveDirectoryHandle(dirHandle: FileSystemDirectoryHandle): Promise<void> {
  // 使用 IndexedDB 存储文件夹句柄
  const database = await openBackupDB();
  const tx = database.transaction('settings', 'readwrite');
  const store = tx.objectStore('settings');
  store.put({ key: 'backupDirectory', handle: dirHandle });
  
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// 获取保存的文件夹句柄
export async function getSavedDirectoryHandle(): Promise<FileSystemDirectoryHandle | null> {
  try {
    const database = await openBackupDB();
    const tx = database.transaction('settings', 'readonly');
    const store = tx.objectStore('settings');
    const request = store.get('backupDirectory');
    
    const result: any = await new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    
    if (!result || !result.handle) {
      return null;
    }

    const dirHandle = result.handle as FileSystemDirectoryHandle;

    // 验证权限
    const permission = await dirHandle.queryPermission({ mode: 'readwrite' });
    if (permission === 'granted') {
      return dirHandle;
    }

    // 请求权限
    const requestPermission = await dirHandle.requestPermission({ mode: 'readwrite' });
    if (requestPermission === 'granted') {
      return dirHandle;
    }

    return null;
  } catch (error) {
    console.error('获取备份文件夹失败:', error);
    return null;
  }
}

// 清除保存的文件夹句柄
export async function clearBackupDirectory(): Promise<void> {
  const database = await openBackupDB();
  const tx = database.transaction('settings', 'readwrite');
  const store = tx.objectStore('settings');
  store.delete('backupDirectory');
  
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// 执行备份
export async function performBackup(dirHandle?: FileSystemDirectoryHandle | null): Promise<string> {
  try {
    // 如果没有传入文件夹句柄，尝试获取保存的
    if (!dirHandle) {
      dirHandle = await getSavedDirectoryHandle();
      if (!dirHandle) {
        throw new Error('未设置备份文件夹，请先选择备份位置');
      }
    }

    // 生成备份文件名
    const timestamp = format(new Date(), 'yyyyMMdd_HHmmss');
    const fileName = `账单备份_${timestamp}.json`;

    // 获取所有数据
    const bills = await db.bills.toArray();
    const categories = await db.categories.toArray();
    const owners = await db.owners.toArray();
    const paymentMethods = await db.paymentMethods.toArray();

    const backupData = {
      version: '1.0',
      timestamp: new Date().toISOString(),
      data: {
        bills,
        categories,
        owners,
        paymentMethods
      }
    };

    // 创建文件
    const fileHandle = await dirHandle.getFileHandle(fileName, { create: true });
    const writable = await fileHandle.createWritable();
    await writable.write(JSON.stringify(backupData, null, 2));
    await writable.close();

    // 保存最后备份时间
    await saveLastBackupTime();

    return fileName;
  } catch (error) {
    console.error('备份失败:', error);
    throw error;
  }
}

// 从备份恢复数据
export async function restoreFromBackup(): Promise<void> {
  try {
    if (!isFileSystemAccessSupported()) {
      throw new Error('您的浏览器不支持文件系统访问功能');
    }

    // 让用户选择备份文件
    const [fileHandle] = await window.showOpenFilePicker({
      types: [{
        description: '账单备份文件',
        accept: { 'application/json': ['.json'] }
      }],
      multiple: false
    });

    const file = await fileHandle.getFile();
    const content = await file.text();
    const backupData = JSON.parse(content);

    // 验证备份数据格式
    if (!backupData.version || !backupData.data) {
      throw new Error('备份文件格式不正确');
    }

    // 清空现有数据
    await db.bills.clear();
    await db.categories.clear();
    await db.owners.clear();
    await db.paymentMethods.clear();

    // 恢复数据
    if (backupData.data.categories?.length > 0) {
      await db.categories.bulkAdd(backupData.data.categories);
    }
    if (backupData.data.owners?.length > 0) {
      await db.owners.bulkAdd(backupData.data.owners);
    }
    if (backupData.data.paymentMethods?.length > 0) {
      await db.paymentMethods.bulkAdd(backupData.data.paymentMethods);
    }
    if (backupData.data.bills?.length > 0) {
      await db.bills.bulkAdd(backupData.data.bills);
    }
  } catch (error) {
    console.error('恢复失败:', error);
    throw error;
  }
}

// 保存最后备份时间
async function saveLastBackupTime(): Promise<void> {
  const database = await openBackupDB();
  const tx = database.transaction('settings', 'readwrite');
  const store = tx.objectStore('settings');
  store.put({ 
    key: 'lastBackupTime', 
    value: new Date().toISOString() 
  });
  
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// 获取最后备份时间
export async function getLastBackupTime(): Promise<Date | null> {
  try {
    const database = await openBackupDB();
    const tx = database.transaction('settings', 'readonly');
    const store = tx.objectStore('settings');
    const request = store.get('lastBackupTime');
    
    const result: any = await new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    
    return result?.value ? new Date(result.value) : null;
  } catch {
    return null;
  }
}

// 检查是否需要备份（超过指定天数）
export async function shouldBackup(days: number = 7): Promise<boolean> {
  if (days === 0) return false; // 禁用自动备份
  
  const lastBackup = await getLastBackupTime();
  if (!lastBackup) return true;

  const daysSinceBackup = (Date.now() - lastBackup.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceBackup >= days;
}

// 获取自动备份间隔设置
export async function getAutoBackupInterval(): Promise<AutoBackupInterval> {
  try {
    const database = await openBackupDB();
    const tx = database.transaction('settings', 'readonly');
    const store = tx.objectStore('settings');
    const request = store.get('autoBackupInterval');
    
    const result: any = await new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    
    return result?.value ?? AUTO_BACKUP_INTERVALS.WEEKLY;
  } catch {
    return AUTO_BACKUP_INTERVALS.WEEKLY;
  }
}

// 设置自动备份间隔
export async function setAutoBackupInterval(interval: AutoBackupInterval): Promise<void> {
  const database = await openBackupDB();
  const tx = database.transaction('settings', 'readwrite');
  const store = tx.objectStore('settings');
  store.put({ 
    key: 'autoBackupInterval', 
    value: interval 
  });
  
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// 尝试自动备份（静默执行，失败不报错）
export async function tryAutoBackup(): Promise<boolean> {
  try {
    const interval = await getAutoBackupInterval();
    if (interval === AUTO_BACKUP_INTERVALS.DISABLED) {
      return false;
    }

    const needsBackup = await shouldBackup(interval);
    if (!needsBackup) {
      return false;
    }

    const dirHandle = await getSavedDirectoryHandle();
    if (!dirHandle) {
      return false;
    }

    await performBackup(dirHandle);
    console.log('自动备份成功');
    return true;
  } catch (error) {
    console.error('自动备份失败:', error);
    return false;
  }
}

// 启动自动备份检查（定时器）
let autoBackupTimer: number | null = null;

export function startAutoBackupCheck(): void {
  // 清除现有定时器
  if (autoBackupTimer !== null) {
    clearInterval(autoBackupTimer);
  }

  // 立即检查一次
  tryAutoBackup();

  // 每小时检查一次
  autoBackupTimer = window.setInterval(() => {
    tryAutoBackup();
  }, 60 * 60 * 1000); // 1小时
}

export function stopAutoBackupCheck(): void {
  if (autoBackupTimer !== null) {
    clearInterval(autoBackupTimer);
    autoBackupTimer = null;
  }
}

// 打开备份设置数据库
function openBackupDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('BackupSettingsDB', 1);

    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);

    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains('settings')) {
        db.createObjectStore('settings', { keyPath: 'key' });
      }
    };
  });
}
