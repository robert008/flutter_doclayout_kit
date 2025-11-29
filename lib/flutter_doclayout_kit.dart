import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'flutter_doclayout_kit_bindings_generated.dart';
import 'src/models.dart';

export 'src/models.dart';
export 'src/doc_layout_service.dart';
export 'src/html_generator.dart';
export 'src/form_html_generator.dart';
export 'src/form_editor_widget.dart';

/// Document Layout Detection Kit
///
/// A Flutter FFI plugin for document layout detection using PP-DocLayout model.
///
/// Usage:
/// ```dart
/// // Initialize with model path
/// DocLayoutKit.init('/path/to/model.onnx');
///
/// // Detect from image file
/// final result = DocLayoutKit.detectFromFile('/path/to/image.jpg');
///
/// // Process detections
/// for (final box in result.detections) {
///   print('${box.className}: ${box.score}');
/// }
/// ```
class DocLayoutKit {
  static DocLayoutKitBindings? _bindings;
  static bool _isInitialized = false;

  /// Private constructor
  DocLayoutKit._();

  /// Get native bindings (lazy initialization)
  static DocLayoutKitBindings get _native {
    _bindings ??= DocLayoutKitBindings(_loadLibrary());
    return _bindings!;
  }

  /// Load native library based on platform
  static DynamicLibrary _loadLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS/macOS: Static library linked into main binary
      return DynamicLibrary.process();
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libdoc_layout_kit.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('doc_layout_kit.dll');
    }

    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Check if the library is initialized
  static bool get isInitialized => _isInitialized;

  /// Get library version
  static String get version {
    final ptr = _native.getVersion();
    return ptr.cast<Utf8>().toDartString();
  }

  /// Initialize the detection model
  ///
  /// [modelPath] - Path to the ONNX model file
  ///
  /// This must be called before any detection operations.
  static void init(String modelPath) {
    final pathPtr = modelPath.toNativeUtf8().cast<Char>();
    try {
      _native.initModel(pathPtr);
    } finally {
      calloc.free(pathPtr);
    }
    _isInitialized = true;
  }

  /// Detect document layout from image file
  ///
  /// [imagePath] - Path to the image file
  /// [confThreshold] - Confidence threshold (0.0 - 1.0), default 0.5
  ///
  /// Returns [DetectionResult] containing detected layout elements
  ///
  /// Note: The native code runs inference asynchronously internally.
  static DetectionResult detectFromFile(
    String imagePath, {
    double confThreshold = 0.5,
  }) {
    _checkInitialized();

    final pathPtr = imagePath.toNativeUtf8().cast<Char>();
    Pointer<Char>? resultPtr;

    try {
      resultPtr = _native.detectLayout(pathPtr, confThreshold);
      final jsonStr = resultPtr.cast<Utf8>().toDartString();
      return DetectionResult.fromJson(jsonDecode(jsonStr));
    } finally {
      calloc.free(pathPtr);
      if (resultPtr != null) {
        _native.freeString(resultPtr);
      }
    }
  }

  /// Detect document layout from raw image bytes
  ///
  /// [imageData] - Raw image bytes (RGB or RGBA format)
  /// [width] - Image width
  /// [height] - Image height
  /// [channels] - Number of channels (1=grayscale, 3=RGB, 4=RGBA)
  /// [confThreshold] - Confidence threshold (0.0 - 1.0), default 0.5
  ///
  /// This is useful for camera preview frames or images already in memory.
  static DetectionResult detectFromBytes(
    Uint8List imageData, {
    required int width,
    required int height,
    required int channels,
    double confThreshold = 0.5,
  }) {
    _checkInitialized();

    final dataPtr = calloc<UnsignedChar>(imageData.length);
    Pointer<Char>? resultPtr;

    try {
      // Copy image data to native memory
      for (int i = 0; i < imageData.length; i++) {
        dataPtr[i] = imageData[i];
      }

      resultPtr = _native.detectLayoutFromBytes(
        dataPtr,
        width,
        height,
        channels,
        confThreshold,
      );

      final jsonStr = resultPtr.cast<Utf8>().toDartString();
      return DetectionResult.fromJson(jsonDecode(jsonStr));
    } finally {
      calloc.free(dataPtr);
      if (resultPtr != null) {
        _native.freeString(resultPtr);
      }
    }
  }

  /// Check if library is initialized, throw if not
  static void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'DocLayoutKit is not initialized. Call DocLayoutKit.init() first.',
      );
    }
  }
}
