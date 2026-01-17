import { db } from './db';
import { format } from 'date-fns';
import {
  initializeGoogleDrive,
  isGoogleDriveSignedIn,
  signInToGoogleDrive,
  uploadBackupToGoogleDrive,
  downloadBackupFromGoogleDrive,
  listBackupFiles,
  isGoogleDriveAvailable
} from './googleDriveService';

// Google Drive 备份相关接口（预留）
// interface GoogleDriveConfig {
//   clientId: string;
//   apiKey: string;
//   scope: string;
//   discoveryDoc: string;
// }

// Google Drive 配置（需要用户自己申请 API 密钥）
// 暂时保留配置结构，后续实现时使用
// const GOOGLE_DRIVE_CONFIG: GoogleDriveConfig = {
//   clientId: '', // 用户需要配置
//   apiKey: '', // 用户需要配置
//   scope: 'https://www.googleapis.com/auth/drive.file',
//   discoveryDoc: 'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest'
// };

// 备份方式枚举
export enum BackupMethod {
  LOCAL_DOWNLOAD = 'local_download',
  GOOGLE_DRIVE = 'google_drive',
  DISABLED = 'disabled'
}

// 备份间隔选项（天数）
export const BACKUP_INTERVALS = {
  DAILY: 1,
  THREE_DAYS: 3,
  WEEKLY: 7,
  DISABLED: 0
} as const;

export type BackupInterval = typeof BACKUP_INTERVALS[keyof typeof BACKUP_INTERVALS];

// 备份配置接口
export interface BackupConfig {
  method: BackupMethod;
  interval: BackupInterval;
  lastBackupTime?: Date;
}

// 生成备份数据
export async function generateBackupData(): Promise<string> {
  const bills = await db.bills.toArray();
  const categories = await db.categories.toArray();
  const owners = await db.owners.toArray();
  const paymentMethods = await db.paymentMethods.toArray();

  const backupData = {
    version: '1.0',
    timestamp: new Date().toISOString(),
    appName: '账单管理 PWA',
    data: {
      bills,
      categories,
      owners,
      paymentMethods
    }
  };

  return JSON.stringify(backupData, null, 2);
}

// 生成备份文件名
export function generateBackupFileName(): string {
  const timestamp = format(new Date(), 'yyyyMMdd_HHmmss');
  return `账单备份_${timestamp}.json`;
}

// 本地下载备份
export async function downloadBackup(): Promise<void> {
  try {
    const data = await generateBackupData();
    const fileName = generateBackupFileName();
    
    // 创建 Blob 对象
    const blob = new Blob([data], { type: 'application/json' });
    
    // 创建下载链接
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    
    // 触发下载
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    // 清理 URL 对象
    URL.revokeObjectURL(url);
    
    // 更新最后备份时间
    await updateLastBackupTime();
    
    console.log('本地下载备份成功:', fileName);
  } catch (error) {
    console.error('本地下载备份失败:', error);
    throw error;
  }
}

// 从备份文件恢复数据
export async function restoreFromBackupFile(): Promise<void> {
  return new Promise((resolve, reject) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    
    input.onchange = async (e) => {
      try {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (!file) return;
        
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
        
        resolve();
      } catch (error) {
        reject(error);
      }
    };
    
    input.click();
  });
}

// Google Drive 备份
export async function uploadToGoogleDrive(): Promise<string> {
  try {
    if (!isGoogleDriveAvailable()) {
      throw new Error('Google Drive 功能暂不可用');
    }

    // 初始化 Google Drive API
    await initializeGoogleDrive();

    // 检查登录状态
    if (!isGoogleDriveSignedIn()) {
      await signInToGoogleDrive();
    }

    // 生成备份数据
    const backupData = await generateBackupData();
    const fileName = generateBackupFileName();

    // 上传到 Google Drive
    const fileId = await uploadBackupToGoogleDrive(fileName, backupData);
    
    // 更新最后备份时间
    await updateLastBackupTime();
    
    console.log('Google Drive 备份成功:', fileId);
    return fileId;
  } catch (error) {
    console.error('Google Drive 备份失败:', error);
    throw error;
  }
}

// 从 Google Drive 恢复备份
export async function restoreFromGoogleDrive(): Promise<void> {
  try {
    if (!isGoogleDriveAvailable()) {
      throw new Error('Google Drive 功能暂不可用');
    }

    // 初始化 Google Drive API
    await initializeGoogleDrive();

    // 检查登录状态
    if (!isGoogleDriveSignedIn()) {
      await signInToGoogleDrive();
    }

    // 获取备份文件列表
    const files = await listBackupFiles();
    
    if (files.length === 0) {
      throw new Error('Google Drive 中没有找到备份文件');
    }

    // 使用最新的备份文件
    const latestFile = files[0];
    const backupData = await downloadBackupFromGoogleDrive(latestFile.id!);
    
    // 解析备份数据
    const parsedData = JSON.parse(backupData);
    
    // 验证备份数据格式
    if (!parsedData.version || !parsedData.data) {
      throw new Error('备份文件格式不正确');
    }

    // 清空现有数据
    await db.bills.clear();
    await db.categories.clear();
    await db.owners.clear();
    await db.paymentMethods.clear();

    // 恢复数据
    if (parsedData.data.categories?.length > 0) {
      await db.categories.bulkAdd(parsedData.data.categories);
    }
    if (parsedData.data.owners?.length > 0) {
      await db.owners.bulkAdd(parsedData.data.owners);
    }
    if (parsedData.data.paymentMethods?.length > 0) {
      await db.paymentMethods.bulkAdd(parsedData.data.paymentMethods);
    }
    if (parsedData.data.bills?.length > 0) {
      await db.bills.bulkAdd(parsedData.data.bills);
    }

    console.log('从 Google Drive 恢复数据成功');
  } catch (error) {
    console.error('从 Google Drive 恢复数据失败:', error);
    throw error;
  }
}

// 获取 Google Drive 备份文件列表
export async function getGoogleDriveBackupList(): Promise<any[]> {
  try {
    if (!isGoogleDriveAvailable()) {
      throw new Error('Google Drive 功能暂不可用');
    }

    // 初始化 Google Drive API
    await initializeGoogleDrive();

    // 检查登录状态
    if (!isGoogleDriveSignedIn()) {
      await signInToGoogleDrive();
    }

    return await listBackupFiles();
  } catch (error) {
    console.error('获取 Google Drive 备份列表失败:', error);
    throw error;
  }
}

// 获取备份配置
export async function getBackupConfig(): Promise<BackupConfig> {
  try {
    const database = await openBackupDB();
    const tx = database.transaction('settings', 'readonly');
    const store = tx.objectStore('settings');
    const request = store.get('backupConfig');
    
    const result: any = await new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    
    if (result?.value) {
      const config = result.value;
      // 转换日期字符串为 Date 对象
      if (config.lastBackupTime) {
        config.lastBackupTime = new Date(config.lastBackupTime);
      }
      return config;
    }
    
    // 默认配置
    return {
      method: BackupMethod.LOCAL_DOWNLOAD,
      interval: BACKUP_INTERVALS.WEEKLY
    };
  } catch {
    return {
      method: BackupMethod.LOCAL_DOWNLOAD,
      interval: BACKUP_INTERVALS.WEEKLY
    };
  }
}

// 保存备份配置
export async function saveBackupConfig(config: BackupConfig): Promise<void> {
  const database = await openBackupDB();
  const tx = database.transaction('settings', 'readwrite');
  const store = tx.objectStore('settings');
  store.put({ 
    key: 'backupConfig', 
    value: config 
  });
  
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// 更新最后备份时间
export async function updateLastBackupTime(): Promise<void> {
  const config = await getBackupConfig();
  config.lastBackupTime = new Date();
  await saveBackupConfig(config);
}

// 检查是否需要备份
export async function shouldBackup(): Promise<boolean> {
  const config = await getBackupConfig();
  
  if (config.method === BackupMethod.DISABLED || config.interval === BACKUP_INTERVALS.DISABLED) {
    return false;
  }
  
  if (!config.lastBackupTime) {
    return true;
  }
  
  const daysSinceBackup = (Date.now() - config.lastBackupTime.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceBackup >= config.interval;
}

// 执行自动备份
export async function performAutoBackup(): Promise<boolean> {
  try {
    const config = await getBackupConfig();
    const needsBackup = await shouldBackup();
    
    if (!needsBackup) {
      return false;
    }
    
    switch (config.method) {
      case BackupMethod.LOCAL_DOWNLOAD:
        await downloadBackup();
        return true;
        
      case BackupMethod.GOOGLE_DRIVE:
        await uploadToGoogleDrive();
        return true;
        
      default:
        return false;
    }
  } catch (error) {
    console.error('自动备份失败:', error);
    return false;
  }
}

// 启动自动备份检查
let autoBackupTimer: number | null = null;

export function startAutoBackupCheck(): void {
  // 清除现有定时器
  if (autoBackupTimer !== null) {
    clearInterval(autoBackupTimer);
  }

  // 立即检查一次
  performAutoBackup();

  // 每小时检查一次
  autoBackupTimer = window.setInterval(() => {
    performAutoBackup();
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