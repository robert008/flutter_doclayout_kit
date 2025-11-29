import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_doclayout_kit/flutter_doclayout_kit.dart';

import 'html_preview_page.dart';
import 'form_editor_page.dart';

class LayoutResultPage extends StatefulWidget {
  final DetectionResult result;
  final String imagePath;

  const LayoutResultPage({
    super.key,
    required this.result,
    required this.imagePath,
  });

  @override
  State<LayoutResultPage> createState() => _LayoutResultPageState();
}

class _LayoutResultPageState extends State<LayoutResultPage> {
  bool _showBoxes = true;

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

  Color _getColorForClass(String className) {
    return _classColors[className] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_document),
            onPressed: () => _showFormPreview(context),
            tooltip: 'Editable Form',
          ),
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => _showHtmlPreview(context),
            tooltip: 'Show HTML',
          ),
          IconButton(
            icon: Icon(_showBoxes ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showBoxes = !_showBoxes),
            tooltip: _showBoxes ? 'Hide boxes' : 'Show boxes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${widget.result.count} elements',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Inference: ${widget.result.inferenceTimeMs}ms'),
                    Text(
                      'Image: ${widget.result.imageWidth} x ${widget.result.imageHeight}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Preview image with bounding boxes
            _buildImageWithBoxes(),

            const SizedBox(height: 16),

            // Legend
            _buildLegend(),

            const SizedBox(height: 16),

            // Results list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.result.detections.length,
              itemBuilder: (context, index) {
                final box = widget.result.detections[index];
                final color = _getColorForClass(box.className);
                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        border: Border.all(color: color, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      box.className,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Score: ${box.score.toStringAsFixed(4)}\n'
                      'Box: [${box.x1.toInt()}, ${box.y1.toInt()}, ${box.x2.toInt()}, ${box.y2.toInt()}]',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size>(
          future: _getImageSize(widget.imagePath),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 300,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final imageSize = snapshot.data!;
            final maxWidth = constraints.maxWidth;
            final scale = maxWidth / imageSize.width;
            final displayHeight = imageSize.height * scale;

            return Container(
              width: maxWidth,
              height: displayHeight.clamp(100, 400),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                    ),
                    if (_showBoxes)
                      CustomPaint(
                        painter: BoundingBoxPainter(
                          detections: widget.result.detections,
                          imageSize: imageSize,
                          getColorForClass: _getColorForClass,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegend() {
    final classes =
        widget.result.detections.map((d) => d.className).toSet().toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Legend:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: classes.map((className) {
                final color = _getColorForClass(className);
                final count = widget.result.detections
                    .where((d) => d.className == className)
                    .length;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('$className ($count)', style: TextStyle(color: color)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<Size> _getImageSize(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  void _showHtmlPreview(BuildContext ctx) {
    final html = HtmlGenerator.generate(widget.result, title: 'Document Layout');

    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (context) => HtmlPreviewPage(html: html),
      ),
    );
  }

  void _showFormPreview(BuildContext ctx) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageBytes = await File(widget.imagePath).readAsBytes();

      if (ctx.mounted) {
        Navigator.pop(ctx);
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (context) => FormEditorPage(
              result: widget.result,
              imageBytes: imageBytes,
            ),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionBox> detections;
  final Size imageSize;
  final Color Function(String) getColorForClass;

  BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
    required this.getColorForClass,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = imageSize.width * scale;
    final scaledHeight = imageSize.height * scale;
    final offsetX = (size.width - scaledWidth) / 2;
    final offsetY = (size.height - scaledHeight) / 2;

    for (int i = 0; i < detections.length; i++) {
      final box = detections[i];
      final color = getColorForClass(box.className);

      final left = offsetX + box.x1 * scale;
      final top = offsetY + box.y1 * scale;
      final right = offsetX + box.x2 * scale;
      final bottom = offsetY + box.y2 * scale;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      final fillPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, borderPaint);

      final label = '${i + 1}. ${box.className}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
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

      textPainter.paint(canvas, Offset(left + 4, top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections ||
        imageSize != oldDelegate.imageSize;
  }
}
