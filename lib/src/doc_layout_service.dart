import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../flutter_doclayout_kit_bindings_generated.dart';
import 'models.dart';

/// High-level document layout detection service with isolate support
///
/// This service automatically runs detection in a background isolate
/// to prevent blocking the UI thread.
///
/// Usage:
/// ```dart
/// // Single image detection
/// final result = await DocLayoutService.detectLayout(
///   imageBytes: imageBytes,
///   modelPath: '/path/to/model.onnx',
///   confThreshold: 0.3,
/// );
///
/// // Camera frame detection
/// void onCameraFrame(CameraImage image) {
///   if (!_isProcessing) {
///     _isProcessing = true;
///     Uint8List imageBytes = convertCameraImage(image);
///
///     DocLayoutService.detectLayout(
///       imageBytes: imageBytes,
///       modelPath: _modelPath,
///     ).then((result) {
///       setState(() {
///         _detections = result.detections;
///       });
///     }).whenComplete(() {
///       _isProcessing = false;
///     });
///   }
/// }
/// ```
class DocLayoutService {
  /// Private constructor
  DocLayoutService._();

  /// Detect document layout from image bytes in a background isolate
  ///
  /// [imageBytes] - Image data in any format supported by OpenCV (PNG, JPEG, etc.)
  /// [modelPath] - Path to the ONNX model file
  /// [confThreshold] - Confidence threshold (0.0 - 1.0), default 0.3
  /// [tempDirectory] - Optional temporary directory for saving image file
  ///
  /// Returns [DetectionResult] containing detected layout elements.
  /// Automatically runs in a background isolate to avoid blocking UI.
  static Future<DetectionResult> detectLayout({
    required Uint8List imageBytes,
    required String modelPath,
    double confThreshold = 0.3,
    String? tempDirectory,
  }) async {
    // Use compute() to automatically create and manage isolate
    return compute(_isolateDetect, {
      'imageBytes': imageBytes,
      'modelPath': modelPath,
      'confThreshold': confThreshold,
      'tempDirectory': tempDirectory,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Isolate entry point - must be static or top-level function
  ///
  /// This function runs in a separate isolate and handles:
  /// 1. FFI library initialization
  /// 2. Saving image to temporary file
  /// 3. Calling native detection function
  /// 4. Parsing JSON result
  /// 5. Cleaning up temporary file
  static DetectionResult _isolateDetect(Map<String, dynamic> params) {
    // Extract parameters
    final Uint8List imageBytes = params['imageBytes'];
    final String modelPath = params['modelPath'];
    final double confThreshold = params['confThreshold'];
    final String? tempDir = params['tempDirectory'];
    final int timestamp = params['timestamp'];

    // Determine temp directory
    String tempDirPath;
    if (tempDir != null) {
      tempDirPath = tempDir;
    } else {
      // In isolate, we can't use async getTemporaryDirectory()
      // Use system temp directory instead
      final dir = Directory.systemTemp;
      tempDirPath = dir.path;
    }

    // Generate temporary file path
    final fileName = 'doclayout_$timestamp.png';
    final filePath = '$tempDirPath/$fileName';

    try {
      // Step 1: Initialize FFI in isolate
      // Note: FFI library must be reinitialized in each isolate
      late final DynamicLibrary nativeLib;
      late final DocLayoutKitBindings bindings;

      try {
        const libName = 'doc_layout_kit';

        if (Platform.isIOS || Platform.isMacOS) {
          // iOS/macOS: Static library linked into main binary
          nativeLib = DynamicLibrary.process();
        } else if (Platform.isAndroid || Platform.isLinux) {
          nativeLib = DynamicLibrary.open('lib$libName.so');
        } else if (Platform.isWindows) {
          nativeLib = DynamicLibrary.open('$libName.dll');
        } else {
          return DetectionResult.error('Unsupported platform: ${Platform.operatingSystem}');
        }

        bindings = DocLayoutKitBindings(nativeLib);
      } catch (e) {
        return DetectionResult.error('FFI initialization failed: $e');
      }

      // Step 2: Initialize model
      final modelPathPtr = modelPath.toNativeUtf8().cast<Char>();
      try {
        bindings.initModel(modelPathPtr);
      } catch (e) {
        calloc.free(modelPathPtr);
        return DetectionResult.error('Model initialization failed: $e');
      } finally {
        calloc.free(modelPathPtr);
      }

      // Step 3: Save image to temporary file (synchronous in isolate)
      try {
        File(filePath).writeAsBytesSync(imageBytes, flush: false);
      } catch (e) {
        return DetectionResult.error('Failed to save image: $e');
      }

      // Verify file was saved correctly
      final savedFile = File(filePath);
      if (!savedFile.existsSync()) {
        return DetectionResult.error('Image file not found after saving');
      }

      // Step 4: Call native detection function
      final imagePathPtr = filePath.toNativeUtf8().cast<Char>();
      Pointer<Char>? resultPtr;

      try {
        resultPtr = bindings.detectLayout(imagePathPtr, confThreshold);
        final jsonStr = resultPtr.cast<Utf8>().toDartString();

        // Step 5: Parse result
        final result = DetectionResult.fromJson(jsonDecode(jsonStr));

        // Step 6: Clean up temporary file
        try {
          savedFile.deleteSync();
        } catch (e) {
          // Log warning but don't fail
          debugPrint('[Isolate] Warning: Failed to delete temp file: $e');
        }

        return result;

      } catch (e) {
        // Clean up on error
        try {
          savedFile.deleteSync();
        } catch (_) {}
        return DetectionResult.error('Detection failed: $e');
      } finally {
        calloc.free(imagePathPtr);
        if (resultPtr != null) {
          bindings.freeString(resultPtr);
        }
      }

    } catch (e) {
      // Clean up on unexpected error
      try {
        File(filePath).deleteSync();
      } catch (_) {}
      return DetectionResult.error('Unexpected error: $e');
    }
  }
}
