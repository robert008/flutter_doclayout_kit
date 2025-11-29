import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doclayout_kit/flutter_doclayout_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FormEditorPage extends StatefulWidget {
  final DetectionResult result;
  final Uint8List imageBytes;

  const FormEditorPage({
    super.key,
    required this.result,
    required this.imageBytes,
  });

  @override
  State<FormEditorPage> createState() => _FormEditorPageState();
}

class _FormEditorPageState extends State<FormEditorPage> {
  final GlobalKey<FormEditorWidgetState> _editorKey = GlobalKey();
  bool _showGhost = true;
  bool _showBorder = true;
  double _ghostOpacity = 0.3;

  void _toggleGhostMode() {
    setState(() => _showGhost = !_showGhost);
  }

  void _toggleBorder() {
    setState(() => _showBorder = !_showBorder);
  }

  void _adjustOpacity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Opacity'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Slider(
            value: _ghostOpacity,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '${(_ghostOpacity * 100).toInt()}%',
            onChanged: (value) {
              setDialogState(() => _ghostOpacity = value);
              setState(() {});
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showFormData() {
    final data = _editorKey.currentState?.getFormData();
    if (data == null) return;

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Form Data'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _generateExportHtml() {
    final data = _editorKey.currentState?.getFormData();
    if (data == null) return '';

    final fieldContents = <int, String>{};
    for (final field in data.fields) {
      if (field.content.isNotEmpty) {
        fieldContents[field.index] = field.content;
      }
    }

    return FormHtmlGenerator.generateFilledHtml(
      widget.result,
      fieldContents: fieldContents,
      showBackgroundImage: false,
      showBorder: _showBorder,
      backgroundOpacity: _ghostOpacity,
      title: 'Document',
    );
  }

  Future<void> _exportHtml() async {
    try {
      final html = _generateExportHtml();
      if (html.isEmpty) return;

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/form_$timestamp.html';
      await File(filePath).writeAsString(html);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: $filePath')),
        );

        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Document Form',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Editor'),
        actions: [
          IconButton(
            icon: Icon(_showGhost ? Icons.image : Icons.image_not_supported),
            onPressed: _toggleGhostMode,
            tooltip: _showGhost ? 'Hide Background' : 'Show Background',
          ),
          if (_showGhost)
            IconButton(
              icon: const Icon(Icons.opacity),
              onPressed: _adjustOpacity,
              tooltip: 'Adjust Opacity',
            ),
          IconButton(
            icon: Icon(_showBorder ? Icons.border_outer : Icons.border_clear),
            onPressed: _toggleBorder,
            tooltip: _showBorder ? 'Hide Border' : 'Show Border',
          ),
          IconButton(
            icon: const Icon(Icons.data_object),
            onPressed: _showFormData,
            tooltip: 'View Form Data',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _exportHtml,
            tooltip: 'Export HTML',
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(100),
        child: FormEditorWidget(
          key: _editorKey,
          result: widget.result,
          imageBytes: widget.imageBytes,
          showGhostImage: _showGhost,
          ghostOpacity: _ghostOpacity,
          showBorder: _showBorder,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.touch_app, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pinch to zoom. Tap blue fields to edit.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editorKey.currentState?.clearAll(),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
