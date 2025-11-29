import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';

class HtmlPreviewPage extends StatefulWidget {
  final String html;

  const HtmlPreviewPage({super.key, required this.html});

  @override
  State<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends State<HtmlPreviewPage> {
  late final WebViewController _controller;
  bool _showCode = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTML Preview'),
        actions: [
          IconButton(
            icon: Icon(_showCode ? Icons.web : Icons.code),
            onPressed: () => setState(() => _showCode = !_showCode),
            tooltip: _showCode ? 'Show Preview' : 'Show Code',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.html));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('HTML copied to clipboard')),
              );
            },
            tooltip: 'Copy HTML',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareHtml(context),
            tooltip: 'Share HTML',
          ),
        ],
      ),
      body: _showCode ? _buildCodeView() : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return WebViewWidget(controller: _controller);
  }

  Widget _buildCodeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          widget.html,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Colors.greenAccent,
          ),
        ),
      ),
    );
  }

  Future<void> _shareHtml(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/layout_$timestamp.html';
      await File(filePath).writeAsString(widget.html);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Document Layout HTML',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }
}
