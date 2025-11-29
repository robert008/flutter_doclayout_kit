# 權限說明 / Permissions Guide

本專案需要相機和相簿權限來進行文件掃描和圖片選擇。

This project requires camera and photo library permissions for document scanning and image selection.

---

## iOS 權限 / iOS Permissions

已在 `ios/Runner/Info.plist` 中配置：

### NSCameraUsageDescription
**用途：** 使用相機掃描文件
**說明文字：** "此應用程式需要使用相機來掃描和辨識文件佈局"

### NSPhotoLibraryUsageDescription
**用途：** 從相簿選擇圖片
**說明文字：** "此應用程式需要存取相簿以選擇要分析的文件圖片"

### NSPhotoLibraryAddUsageDescription
**用途：** 儲存處理後的圖片到相簿
**說明文字：** "此應用程式需要將處理後的文件圖片儲存到相簿"

---

## Android 權限 / Android Permissions

已在 `android/app/src/main/AndroidManifest.xml` 中配置：

### CAMERA
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```
**用途：** 使用相機掃描文件

### READ_EXTERNAL_STORAGE
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
```
**用途：** 讀取相簿圖片（Android 12 及以下）

### READ_MEDIA_IMAGES
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```
**用途：** 讀取相簿圖片（Android 13+）

### Camera Feature
```xml
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```
**說明：** 聲明使用相機功能，但不是必需（支援無相機裝置）

---

## 使用說明 / Usage Guide

### 自動請求權限

使用 `image_picker` 套件時，權限會自動請求：

```dart
import 'package:image_picker/image_picker.dart';

final ImagePicker picker = ImagePicker();

// 從相機拍照 - 會自動請求相機權限
final XFile? photo = await picker.pickImage(source: ImageSource.camera);

// 從相簿選擇 - 會自動請求相簿權限
final XFile? image = await picker.pickImage(source: ImageSource.gallery);
```

### 手動檢查權限（可選）

如果需要提前檢查權限狀態，可使用 `permission_handler` 套件：

```yaml
dependencies:
  permission_handler: ^11.0.0
```

```dart
import 'package:permission_handler/permission_handler.dart';

// 檢查並請求相機權限
Future<void> requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) {
    // 權限已授予
  } else if (status.isDenied) {
    // 權限被拒絕
  } else if (status.isPermanentlyDenied) {
    // 權限被永久拒絕，需要引導用戶到設定頁面
    openAppSettings();
  }
}

// 檢查並請求相簿權限
Future<void> requestGalleryPermission() async {
  final status = await Permission.photos.request();
  // 處理結果...
}
```

---

## 權限說明文字自定義 / Customizing Permission Messages

### iOS

編輯 `ios/Runner/Info.plist` 中的說明文字：

```xml
<key>NSCameraUsageDescription</key>
<string>您的自定義說明文字</string>
```

### Android

Android 權限說明由系統自動顯示，無法自定義。但可以在請求權限前顯示自己的說明對話框。

---

## 常見問題 / FAQ

### Q: 為什麼有兩個 Android 相簿權限？

A: Android 13 (API 33) 引入了新的細粒度媒體權限：
- `READ_EXTERNAL_STORAGE` - 適用於 Android 12 及以下
- `READ_MEDIA_IMAGES` - 適用於 Android 13+

兩者都配置可確保所有 Android 版本都能正常工作。

### Q: 如果用戶拒絕權限怎麼辦？

A: 應用會無法使用相機或相簿功能。建議：
1. 在請求權限前顯示說明對話框
2. 如果被拒絕，提供引導到設定頁面的選項
3. 提供替代方案（例如：只允許手動輸入）

### Q: 需要其他權限嗎？

A: 不需要。本專案只需要相機和相簿權限。如果您的應用有其他功能（如網路請求、位置等），請自行添加。

---

## 隱私政策建議 / Privacy Policy Recommendations

如果您的應用要上架到 App Store 或 Google Play，請在隱私政策中說明：

1. **收集的資料：** 相機拍攝的圖片、相簿選擇的圖片
2. **使用目的：** 文件佈局分析和辨識
3. **資料處理：**
   - 所有處理在本地裝置進行
   - 不會上傳到伺服器
   - 不會儲存用戶圖片（除非用戶明確選擇儲存）
4. **第三方共享：** 無

---

## 更新日誌 / Changelog

### 2024-11-25
- ✅ 添加 iOS 相機和相簿權限宣告
- ✅ Android 權限已配置（之前已存在）
- ✅ 建立權限說明文件
