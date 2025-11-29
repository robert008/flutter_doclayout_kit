// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;

/// FFI bindings for libdoc_layout_kit native library
class DocLayoutKitBindings {
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  DocLayoutKitBindings(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// Initialize model with path
  /// void initModel(const char* model_path)
  void initModel(ffi.Pointer<ffi.Char> modelPath) {
    return _initModel(modelPath);
  }

  late final _initModelPtr = _lookup<
      ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>('initModel');
  late final _initModel =
      _initModelPtr.asFunction<void Function(ffi.Pointer<ffi.Char>)>();

  /// Detect layout from image file path
  /// char* detectLayout(const char* img_path, float conf_threshold)
  ffi.Pointer<ffi.Char> detectLayout(
      ffi.Pointer<ffi.Char> imgPath, double confThreshold) {
    return _detectLayout(imgPath, confThreshold);
  }

  late final _detectLayoutPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ffi.Char>, ffi.Float)>>('detectLayout');
  late final _detectLayout = _detectLayoutPtr
      .asFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, double)>();

  /// Detect layout from raw image bytes
  /// char* detectLayoutFromBytes(const unsigned char* image_data, int width, int height, int channels, float conf_threshold)
  ffi.Pointer<ffi.Char> detectLayoutFromBytes(
    ffi.Pointer<ffi.UnsignedChar> imageData,
    int width,
    int height,
    int channels,
    double confThreshold,
  ) {
    return _detectLayoutFromBytes(
        imageData, width, height, channels, confThreshold);
  }

  late final _detectLayoutFromBytesPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ffi.UnsignedChar>,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Float)>>('detectLayoutFromBytes');
  late final _detectLayoutFromBytes = _detectLayoutFromBytesPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(
          ffi.Pointer<ffi.UnsignedChar>, int, int, int, double)>();

  /// Free allocated string memory
  /// void freeString(char* str)
  void freeString(ffi.Pointer<ffi.Char> str) {
    return _freeString(str);
  }

  late final _freeStringPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>(
          'freeString');
  late final _freeString =
      _freeStringPtr.asFunction<void Function(ffi.Pointer<ffi.Char>)>();

  /// Get library version
  /// const char* getVersion()
  ffi.Pointer<ffi.Char> getVersion() {
    return _getVersion();
  }

  late final _getVersionPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>(
          'getVersion');
  late final _getVersion =
      _getVersionPtr.asFunction<ffi.Pointer<ffi.Char> Function()>();
}
