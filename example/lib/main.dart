import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doclayout_kit/flutter_doclayout_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

import 'pages/layout_result_page.dart';
import 'pages/camera_scan_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Not initialized';
  String _version = '';
  bool _isInitialized = false;
  bool _isProcessing = false;

  final List<Map<String, String>> _testImages = [
    {'name': 'Test 1 (Magazine)', 'asset': 'assets/test_2.jpg'},
    {'name': 'Test 2 (Vertical Layout)', 'asset': 'assets/test_3.png'},
    {'name': 'Test 3 (Horizontal Layout)', 'asset': 'assets/test_4.jpeg'},
  ];

  @override
  void initState() {
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    setState(() {
      _status = 'Initializing...';
    });

    try {
      debugPrint('[DocLayout] Getting app directory...');
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/pp_doclayout_l.onnx';
      debugPrint('[DocLayout] Model path: $modelPath');

      if (!File(modelPath).existsSync()) {
        debugPrint('[DocLayout] Model not found, copying from assets...');
        setState(() {
          _status = 'Copying model (L)...';
        });
        final data = await rootBundle.load('assets/pp_doclayout_l.onnx');
        final bytes = data.buffer.asUint8List();
        await File(modelPath).writeAsBytes(bytes);
        debugPrint('[DocLayout] Model copied, size: ${bytes.length} bytes');
      } else {
        debugPrint('[DocLayout] Model already exists');
      }

      debugPrint('[DocLayout] Initializing native library...');
      DocLayoutKit.init(modelPath);
      debugPrint('[DocLayout] Native library initialized');

      final version = DocLayoutKit.version;
      debugPrint('[DocLayout] Version: $version');

      setState(() {
        _isInitialized = true;
        _version = version;
        _status = 'Ready';
      });
      debugPrint('[DocLayout] Ready!');
    } catch (e, stack) {
      debugPrint('[DocLayout] Init error: $e');
      debugPrint('[DocLayout] Stack: $stack');
      setState(() {
        _status = 'Init failed: $e';
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (!_isInitialized || _isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4000,
        maxHeight: 4000,
        imageQuality: 90,
      );

      if (photo != null) {
        final imageBytes = await File(photo.path).readAsBytes();
        await _runDetection(imageBytes, photo.path);
      }
    } catch (e) {
      debugPrint('[DocLayout] Camera error: $e');
      setState(() => _status = 'Camera error: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (!_isInitialized || _isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4000,
        maxHeight: 4000,
      );

      if (image != null) {
        final imageBytes = await File(image.path).readAsBytes();
        await _runDetection(imageBytes, image.path);
      }
    } catch (e) {
      debugPrint('[DocLayout] Gallery error: $e');
      setState(() => _status = 'Gallery error: $e');
    }
  }

  Future<void> _testIsolateDetection(String assetPath) async {
    if (!_isInitialized || _isProcessing) return;

    try {
      debugPrint('[DocLayout] Loading asset...');
      final data = await rootBundle.load(assetPath);
      final imageBytes = data.buffer.asUint8List();
      debugPrint('[DocLayout] Asset loaded, size: ${imageBytes.length} bytes');

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = assetPath.split('/').last;
      final imagePath = '${appDir.path}/$fileName';
      await File(imagePath).writeAsBytes(imageBytes);

      await _runDetection(imageBytes, imagePath);
    } catch (e, stack) {
      debugPrint('[DocLayout] Detection error: $e');
      debugPrint('[DocLayout] Stack: $stack');
      setState(() {
        _status = 'Detection failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _runDetection(Uint8List imageBytes, String imagePath) async {
    setState(() {
      _status = 'Detecting...';
      _isProcessing = true;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/pp_doclayout_l.onnx';

      debugPrint('[DocLayout] Calling DocLayoutService.detectLayout (isolate)...');
      final stopwatch = Stopwatch()..start();

      final result = await DocLayoutService.detectLayout(
        imageBytes: imageBytes,
        modelPath: modelPath,
        confThreshold: 0.3,
        tempDirectory: appDir.path,
      );

      stopwatch.stop();
      debugPrint('[DocLayout] Detection complete!');
      debugPrint('[DocLayout] Total time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[DocLayout] Result: count=${result.count}, error=${result.error}');

      setState(() {
        _status = 'Ready';
        _isProcessing = false;
      });

      if (result.isSuccess && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LayoutResultPage(
              result: result,
              imagePath: imagePath,
            ),
          ),
        );
      } else if (result.hasError) {
        setState(() => _status = 'Error: ${result.error}');
      }
    } catch (e) {
      setState(() {
        _status = 'Detection failed: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocLayout Kit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isProcessing)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            'Status: $_status',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (_version.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Version: $_version',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Real-time scan button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CameraScanPage(),
                  ),
                );
              },
              icon: const Icon(Icons.document_scanner),
              label: const Text('Real-time Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Camera and Gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && !_isProcessing
                        ? _pickImageFromCamera
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && !_isProcessing
                        ? _pickImageFromGallery
                        : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Test buttons
            const Text(
              'Test Images',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.separated(
                itemCount: _testImages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final img = _testImages[index];
                  return ElevatedButton(
                    onPressed: _isInitialized && !_isProcessing
                        ? () => _testIsolateDetection(img['asset']!)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(img['name']!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
