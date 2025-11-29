# Permissions Guide

This project requires camera and photo library permissions for document scanning and image selection.

---

## iOS Permissions

Configure in `ios/Runner/Info.plist`:

### NSCameraUsageDescription
**Purpose:** Use camera to scan documents
**Message:** "This app needs camera access to scan and analyze document layouts"

### NSPhotoLibraryUsageDescription
**Purpose:** Select images from photo library
**Message:** "This app needs photo library access to select document images for analysis"

### NSPhotoLibraryAddUsageDescription
**Purpose:** Save processed images to photo library
**Message:** "This app needs to save processed document images to your photo library"

---

## Android Permissions

Configure in `android/app/src/main/AndroidManifest.xml`:

### CAMERA
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```
**Purpose:** Use camera to scan documents

### READ_EXTERNAL_STORAGE
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
```
**Purpose:** Read photos (Android 12 and below)

### READ_MEDIA_IMAGES
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```
**Purpose:** Read photos (Android 13+)

### Camera Feature
```xml
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```
**Note:** Declares camera feature but not required (supports devices without camera)

---

## Usage

### Automatic Permission Request

When using `image_picker`, permissions are requested automatically:

```dart
import 'package:image_picker/image_picker.dart';

final ImagePicker picker = ImagePicker();

// Take photo - automatically requests camera permission
final XFile? photo = await picker.pickImage(source: ImageSource.camera);

// Pick from gallery - automatically requests photo library permission
final XFile? image = await picker.pickImage(source: ImageSource.gallery);
```

### Manual Permission Check (Optional)

Use `permission_handler` package to check permission status:

```yaml
dependencies:
  permission_handler: ^11.0.0
```

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) {
    // Permission granted
  } else if (status.isDenied) {
    // Permission denied
  } else if (status.isPermanentlyDenied) {
    // Permission permanently denied, open settings
    openAppSettings();
  }
}
```

---

## FAQ

### Q: Why are there two Android photo library permissions?

A: Android 13 (API 33) introduced new granular media permissions:
- `READ_EXTERNAL_STORAGE` - For Android 12 and below
- `READ_MEDIA_IMAGES` - For Android 13+

Both are configured to ensure compatibility with all Android versions.

### Q: What if the user denies permission?

A: The app won't be able to use camera or photo library features. Recommendations:
1. Show explanation dialog before requesting permission
2. If denied, provide option to open settings
3. Provide alternative options (e.g., manual file path input)
