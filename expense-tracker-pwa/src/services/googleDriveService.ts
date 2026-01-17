import { gapi } from 'gapi-script';

// 导入 Google Drive API 类型
/// <reference types="gapi.client.drive-v3" />

// Google Drive API 配置
const GOOGLE_DRIVE_CONFIG = {
  apiKey: '', // 需要用户配置
  clientId: '', // 需要用户配置
  discoveryDoc: 'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest',
  scope: 'https://www.googleapis.com/auth/drive.file'
};

// Google Drive 初始化状态
let isGapiInitialized = false;
let isSignedIn = false;

// 初始化 Google API
export async function initializeGoogleDrive(apiKey: string, clientId: string): Promise<void> {
  try {
    if (isGapiInitialized) {
      return;
    }

    if (!apiKey || !clientId) {
      throw new Error('请先配置 Google Drive API 密钥和客户端 ID');
    }

    // 加载 gapi
    await new Promise<void>((resolve, reject) => {
      gapi.load('auth2', {
        callback: resolve,
        onerror: reject
      });
    });

    // 初始化 gapi
    await gapi.client.init({
      apiKey: apiKey,
      clientId: clientId,
      discoveryDocs: [GOOGLE_DRIVE_CONFIG.discoveryDoc],
      scope: GOOGLE_DRIVE_CONFIG.scope
    });

    isGapiInitialized = true;
    
    // 检查登录状态
    const authInstance = gapi.auth2.getAuthInstance();
    isSignedIn = authInstance.isSignedIn.get();
    
    console.log('Google Drive API 初始化成功');
  } catch (error) {
    console.error('Google Drive API 初始化失败:', error);
    throw error;
  }
}

// 检查是否已登录
export function isGoogleDriveSignedIn(): boolean {
  if (!isGapiInitialized) {
    return false;
  }
  
  const authInstance = gapi.auth2.getAuthInstance();
  return authInstance.isSignedIn.get();
}

// 登录 Google Drive
export async function signInToGoogleDrive(): Promise<void> {
  try {
    if (!isGapiInitialized) {
      throw new Error('Google Drive API 未初始化');
    }

    const authInstance = gapi.auth2.getAuthInstance();
    
    if (!authInstance.isSignedIn.get()) {
      await authInstance.signIn();
    }
    
    isSignedIn = true;
    console.log('Google Drive 登录成功');
  } catch (error) {
    console.error('Google Drive 登录失败:', error);
    throw error;
  }
}

// 登出 Google Drive
export async function signOutFromGoogleDrive(): Promise<void> {
  try {
    if (!isGapiInitialized) {
      return;
    }

    const authInstance = gapi.auth2.getAuthInstance();
    
    if (authInstance.isSignedIn.get()) {
      await authInstance.signOut();
    }
    
    isSignedIn = false;
    console.log('Google Drive 登出成功');
  } catch (error) {
    console.error('Google Drive 登出失败:', error);
    throw error;
  }
}

// 获取当前用户信息
export function getCurrentUser(): gapi.auth2.GoogleUser | null {
  if (!isGapiInitialized || !isSignedIn) {
    return null;
  }

  const authInstance = gapi.auth2.getAuthInstance();
  return authInstance.currentUser.get();
}

// 上传备份文件到 Google Drive
export async function uploadBackupToGoogleDrive(
  fileName: string, 
  content: string
): Promise<string> {
  try {
    if (!isGapiInitialized || !isSignedIn) {
      throw new Error('请先登录 Google Drive');
    }

    // 创建文件元数据
    const metadata = {
      name: fileName,
      parents: ['appDataFolder'], // 使用应用数据文件夹，用户不可见
      description: '账单管理 PWA 备份文件'
    };

    // 创建表单数据
    const form = new FormData();
    form.append('metadata', new Blob([JSON.stringify(metadata)], { type: 'application/json' }));
    form.append('file', new Blob([content], { type: 'application/json' }));

    // 上传文件
    const response = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${gapi.auth2.getAuthInstance().currentUser.get().getAuthResponse().access_token}`
      },
      body: form
    });

    if (!response.ok) {
      throw new Error(`上传失败: ${response.statusText}`);
    }

    const result = await response.json();
    console.log('备份文件上传成功:', result.id);
    return result.id;
  } catch (error) {
    console.error('上传备份文件失败:', error);
    throw error;
  }
}

// 从 Google Drive 下载备份文件
export async function downloadBackupFromGoogleDrive(fileId: string): Promise<string> {
  try {
    if (!isGapiInitialized || !isSignedIn) {
      throw new Error('请先登录 Google Drive');
    }

    const response = await gapi.client.drive.files.get({
      fileId: fileId,
      alt: 'media'
    });

    return response.body;
  } catch (error) {
    console.error('下载备份文件失败:', error);
    throw error;
  }
}

// 列出 Google Drive 中的备份文件
export async function listBackupFiles(): Promise<gapi.client.drive.File[]> {
  try {
    if (!isGapiInitialized || !isSignedIn) {
      throw new Error('请先登录 Google Drive');
    }

    const response = await gapi.client.drive.files.list({
      q: "parents in 'appDataFolder' and name contains '账单备份_'",
      orderBy: 'createdTime desc',
      pageSize: 10
    });

    return response.result.files || [];
  } catch (error) {
    console.error('获取备份文件列表失败:', error);
    throw error;
  }
}

// 删除 Google Drive 中的备份文件
export async function deleteBackupFromGoogleDrive(fileId: string): Promise<void> {
  try {
    if (!isGapiInitialized || !isSignedIn) {
      throw new Error('请先登录 Google Drive');
    }

    await gapi.client.drive.files.delete({
      fileId: fileId
    });

    console.log('备份文件删除成功:', fileId);
  } catch (error) {
    console.error('删除备份文件失败:', error);
    throw error;
  }
}

// 检查 Google Drive API 配置是否完整
export function isGoogleDriveConfigured(apiKey?: string, clientId?: string): boolean {
  return !!(apiKey && clientId);
}

// 获取用户的 Google Drive 存储空间信息
export async function getGoogleDriveStorageInfo(): Promise<{
  used: string;
  limit: string;
  usedInDrive: string;
}> {
  try {
    if (!isGapiInitialized || !isSignedIn) {
      throw new Error('请先登录 Google Drive');
    }

    const response = await gapi.client.drive.about.get({
      fields: 'storageQuota'
    });

    const quota = response.result.storageQuota;
    return {
      used: quota?.usage || '0',
      limit: quota?.limit || '0',
      usedInDrive: quota?.usageInDrive || '0'
    };
  } catch (error) {
    console.error('获取存储空间信息失败:', error);
    throw error;
  }
}