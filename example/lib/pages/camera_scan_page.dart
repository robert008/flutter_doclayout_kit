import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_doclayout_kit/flutter_doclayout_kit.dart';
import 'package:path_provider/path_provider.dart';

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({super.key});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isModelReady = false;
  String _status = 'Initializing...';
  DetectionResult? _lastResult;
  int _fps = 0;
  int _inferenceMs = 0;

  Timer? _detectionTimer;
  final Stopwatch _fpsStopwatch = Stopwatch();
  int _frameCount = 0;

  final Map<String, Color> _classColors = {
    'paragraph_title': Colors.red,
    'text': Colors.blue,
    'figure': Colors.green,
    'figure_caption': Colors.orange,
    'table': Colors.purple,
    'table_caption': Colors.pink,
    'header': Colors.cyan,
    'footer': Colors.brown,
    'reference': Colors.indigo,
    'equation': Colors.teal,
    'number': Colors.amber,
  };

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _initModel();
    await _initCamera();
  }

  Future<void> _initModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/pp_doclayout_l.onnx';

      if (!File(modelPath).existsSync()) {
        setState(() => _status = 'Copying model L...');
        final data = await rootBundle.load('assets/pp_doclayout_l.onnx');
        final bytes = data.buffer.asUint8List();
        await File(modelPath).writeAsBytes(bytes);
      }

      setState(() {
        _isModelReady = true;
        _status = 'Model ready';
      });
    } catch (e) {
      setState(() => _status = 'Model error: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera available');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      setState(() {
        _isInitialized = true;
        _status = 'Ready - Tap Start';
      });
    } catch (e) {
      setState(() => _status = 'Camera error: $e');
    }
  }

  void _startScanning() {
    if (!_isInitialized || !_isModelReady) return;

    _fpsStopwatch.start();
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _captureAndDetect(),
    );
    setState(() => _status = 'Scanning...');
  }

  void _stopScanning() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _fpsStopwatch.stop();
    _fpsStopwatch.reset();
    _frameCount = 0;
    setState(() {
      _status = 'Stopped';
      _lastResult = null;
      _fps = 0;
    });
  }

  Future<void> _captureAndDetect() async {
    if (_isProcessing || _cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    _isProcessing = true;

    try {
      final xFile = await _cameraController!.takePicture();
      final imageBytes = await File(xFile.path).readAsBytes();

      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/pp_doclayout_l.onnx';

      final result = await DocLayoutService.detectLayout(
        imageBytes: imageBytes,
        modelPath: modelPath,
        confThreshold: 0.3,
        tempDirectory: appDir.path,
      );

      // Cleanup temp file
      await File(xFile.path).delete();

      _frameCount++;
      if (_fpsStopwatch.elapsedMilliseconds >= 1000) {
        _fps = (_frameCount * 1000 / _fpsStopwatch.elapsedMilliseconds).round();
        _frameCount = 0;
        _fpsStopwatch.reset();
        _fpsStopwatch.start();
      }

      if (mounted) {
        setState(() {
          _lastResult = result;
          _inferenceMs = result.inferenceTimeMs;
        });
      }
    } catch (e) {
      debugPrint('[CameraScan] Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Color _getColorForClass(String className) {
    return _classColors[className] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Scan'),
        actions: [
          if (_lastResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '${_lastResult!.count} items',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview with overlay
          Expanded(
            child: _isInitialized && _cameraController != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),
                      if (_lastResult != null && _lastResult!.isSuccess)
                        CustomPaint(
                          painter: RealtimeBoundingBoxPainter(
                            detections: _lastResult!.detections,
                            imageWidth: _lastResult!.imageWidth.toDouble(),
                            imageHeight: _lastResult!.imageHeight.toDouble(),
                            getColorForClass: _getColorForClass,
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_status),
                      ],
                    ),
                  ),
          ),

          // Status bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black87,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Status', _status),
                      _buildStatItem('Inference', '${_inferenceMs}ms'),
                      _buildStatItem('FPS', '$_fps'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isInitialized && _isModelReady
                              ? (_detectionTimer != null
                                  ? _stopScanning
                                  : _startScanning)
                              : null,
                          icon: Icon(
                            _detectionTimer != null
                                ? Icons.stop
                                : Icons.play_arrow,
                          ),
                          label: Text(
                            _detectionTimer != null ? 'Stop' : 'Start',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _detectionTimer != null
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class RealtimeBoundingBoxPainter extends CustomPainter {
  final List<DetectionBox> detections;
  final double imageWidth;
  final double imageHeight;
  final Color Function(String) getColorForClass;

  RealtimeBoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    required this.getColorForClass,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale from image coordinates to screen coordinates
    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    for (final box in detections) {
      final color = getColorForClass(box.className);

      final left = box.x1 * scaleX;
      final top = box.y1 * scaleY;
      final right = box.x2 * scaleX;
      final bottom = box.y2 * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Draw filled rectangle
      final fillPaint = Paint()
        ..color = color.withAlpha(40)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Draw border
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(rect, borderPaint);

      // Draw label
      final label = box.className;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        left,
        top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final labelBgPaint = Paint()..color = color;
      canvas.drawRect(labelRect, labelBgPaint);

      textPainter.paint(
        canvas,
        Offset(left + 4, top - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RealtimeBoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}
