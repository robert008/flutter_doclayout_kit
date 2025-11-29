import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// Form HTML Generator for Scan-to-Form functionality
///
/// Generates editable HTML overlay based on AI layout detection results.
/// Supports Ghost Mode (original image as background) and PDF export.
class FormHtmlGenerator {
  /// Text-based element types that should be editable
  static const Set<String> _editableTypes = {
    'doc_title',
    'paragraph_title',
    'text',
    'abstract',
    'content',
    'figure_title',
    'table_title',
    'chart_title',
    'reference',
    'footnote',
    'header',
    'footer',
    'number',
    'formula_number',
    'aside_text',
  };

  /// Non-editable visual element types
  static const Set<String> _visualTypes = {
    'image',
    'table',
    'chart',
    'formula',
    'algorithm',
    'seal',
    'header_image',
    'footer_image',
  };

  /// Font size mapping based on element type
  static const Map<String, String> _fontSizeMapping = {
    'doc_title': '24px',
    'paragraph_title': '18px',
    'text': '14px',
    'abstract': '14px',
    'content': '14px',
    'figure_title': '12px',
    'table_title': '12px',
    'chart_title': '12px',
    'reference': '12px',
    'footnote': '11px',
    'header': '12px',
    'footer': '12px',
    'number': '14px',
    'formula_number': '12px',
    'aside_text': '12px',
  };

  /// Generate editable form HTML from detection result
  ///
  /// [result] - Detection result from AI analysis
  /// [imageFile] - Original image file for Ghost Mode background
  /// [title] - Optional document title
  /// [showGhostImage] - Whether to show background image (default: true)
  static Future<String> generate(
    DetectionResult result, {
    File? imageFile,
    Uint8List? imageBytes,
    String? title,
    bool showGhostImage = true,
  }) async {
    if (!result.isSuccess) {
      return _generateErrorHtml(result.error ?? 'Unknown error');
    }

    String? backgroundImageData;
    if (showGhostImage) {
      if (imageBytes != null) {
        backgroundImageData = _bytesToBase64DataUrl(imageBytes);
      } else if (imageFile != null) {
        backgroundImageData = await _fileToBase64DataUrl(imageFile);
      }
    }

    final sortedDetections = _sortByReadingOrder(result.detections);
    final elements = _generateElements(sortedDetections, result);
    final css = _generateCss(backgroundImageData);

    return '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${_escapeHtml(title ?? 'Document Form')}</title>
  <style>
$css
  </style>
</head>
<body>
  <div class="document-container" data-width="${result.imageWidth}" data-height="${result.imageHeight}">
$elements
  </div>
  <script>
${_generateScript()}
  </script>
</body>
</html>''';
  }

  /// Generate synchronous version (requires pre-loaded image bytes)
  static String generateSync(
    DetectionResult result, {
    Uint8List? imageBytes,
    String? title,
    bool showGhostImage = true,
  }) {
    if (!result.isSuccess) {
      return _generateErrorHtml(result.error ?? 'Unknown error');
    }

    String? backgroundImageData;
    if (showGhostImage && imageBytes != null) {
      backgroundImageData = _bytesToBase64DataUrl(imageBytes);
    }

    final sortedDetections = _sortByReadingOrder(result.detections);
    final elements = _generateElements(sortedDetections, result);
    final css = _generateCss(backgroundImageData);

    return '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${_escapeHtml(title ?? 'Document Form')}</title>
  <style>
$css
  </style>
</head>
<body>
  <div class="document-container" data-width="${result.imageWidth}" data-height="${result.imageHeight}">
$elements
  </div>
  <script>
${_generateScript()}
  </script>
</body>
</html>''';
  }

  /// Generate static HTML with filled content (for export, no editing)
  static String generateFilledHtml(
    DetectionResult result, {
    required Map<int, String> fieldContents,
    Uint8List? imageBytes,
    String? title,
    bool showBackgroundImage = false,
    bool showBorder = false,
    double backgroundOpacity = 0.3,
  }) {
    if (!result.isSuccess) {
      return _generateErrorHtml(result.error ?? 'Unknown error');
    }

    String? backgroundImageData;
    if (showBackgroundImage && imageBytes != null) {
      backgroundImageData = _bytesToBase64DataUrl(imageBytes);
    }

    final sortedDetections = _sortByReadingOrder(result.detections);
    final elements = _generateFilledElements(sortedDetections, result, fieldContents);
    final css = _generateExportCss(
      backgroundImageData,
      showBorder: showBorder,
      backgroundOpacity: backgroundOpacity,
    );

    return '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${_escapeHtml(title ?? 'Document')}</title>
  <style>
$css
  </style>
</head>
<body>
  <div class="document-container">
$elements
  </div>
</body>
</html>''';
  }

  /// Generate filled elements (static text, no editing)
  static String _generateFilledElements(
    List<DetectionBox> detections,
    DetectionResult result,
    Map<int, String> fieldContents,
  ) {
    final buffer = StringBuffer();
    final imgWidth = result.imageWidth.toDouble();
    final imgHeight = result.imageHeight.toDouble();

    for (var i = 0; i < detections.length; i++) {
      final box = detections[i];
      final content = fieldContents[i] ?? '';

      // Skip non-editable types (images, tables, etc.)
      if (!isEditable(box.className)) {
        continue;
      }

      // Calculate percentage positions
      final left = (box.x1 / imgWidth * 100).toStringAsFixed(3);
      final top = (box.y1 / imgHeight * 100).toStringAsFixed(3);
      final width = (box.width / imgWidth * 100).toStringAsFixed(3);
      final height = (box.height / imgHeight * 100).toStringAsFixed(3);

      final fontSize = _fontSizeMapping[box.className] ?? '14px';
      final cssClass = _toCssClass(box.className);

      buffer.writeln('    <div class="text-element $cssClass"');
      buffer.writeln('         style="left: $left%; top: $top%; width: $width%; height: $height%; font-size: $fontSize;">');
      buffer.writeln('      ${_escapeHtml(content)}');
      buffer.writeln('    </div>');
    }

    return buffer.toString();
  }

  /// Generate CSS for export (clean, no edit controls)
  static String _generateExportCss(
    String? backgroundImageData, {
    bool showBorder = false,
    double backgroundOpacity = 0.3,
  }) {
    // Convert opacity to rgba blue color
    final String blueBackground = 'background: rgba(0, 120, 215, ${backgroundOpacity.toStringAsFixed(2)});';

    final backgroundStyle = backgroundImageData != null
        ? '''
      background-image: url('$backgroundImageData');
      background-size: 100% 100%;
      background-position: center;
      background-repeat: no-repeat;'''
        : blueBackground;

    final borderStyle = showBorder
        ? 'border: 1px solid #ccc; border-radius: 2px;'
        : '';

    return '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang TC', 'Microsoft JhengHei', sans-serif;
      background: #fff;
    }

    .document-container {
      position: relative;
      width: 100%;
      padding-bottom: 141.4%; /* A4 ratio */
      $backgroundStyle
    }

    .text-element {
      position: absolute;
      overflow: hidden;
      word-wrap: break-word;
      line-height: 1.3;
      padding: 2px;
      background: #fff;
      $borderStyle
    }

    /* Element type styles */
    .doc-title {
      font-weight: bold;
      text-align: center;
    }

    .paragraph-title {
      font-weight: 600;
    }

    .text-block, .content, .abstract {
      text-align: justify;
    }

    .figure-title, .table-title, .chart-title {
      text-align: center;
      font-style: italic;
    }

    .header, .footer {
      text-align: center;
      color: #666;
    }

    @media print {
      body { background: none; }
      .document-container {
        background-image: none !important;
        padding-bottom: 0;
        height: auto;
      }
    }
''';
  }

  /// Check if element type is editable
  static bool isEditable(String className) => _editableTypes.contains(className);

  /// Check if element type is visual (non-editable)
  static bool isVisual(String className) => _visualTypes.contains(className);

  /// Convert file to Base64 data URL
  static Future<String> _fileToBase64DataUrl(File file) async {
    final bytes = await file.readAsBytes();
    return _bytesToBase64DataUrl(bytes);
  }

  /// Convert bytes to Base64 data URL
  static String _bytesToBase64DataUrl(Uint8List bytes) {
    final base64 = base64Encode(bytes);
    final mimeType = _detectMimeType(bytes);
    return 'data:$mimeType;base64,$base64';
  }

  /// Detect MIME type from image bytes
  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3) {
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      // PNG: 89 50 4E 47
      if (bytes.length >= 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      // GIF: 47 49 46
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return 'image/gif';
      }
      // WebP: 52 49 46 46 ... 57 45 42 50
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'image/webp';
      }
    }
    return 'image/jpeg'; // Default
  }

  /// Sort detections by reading order (top to bottom, left to right)
  static List<DetectionBox> _sortByReadingOrder(List<DetectionBox> detections) {
    final sorted = List<DetectionBox>.from(detections);
    sorted.sort((a, b) {
      final rowTolerance = 30.0;
      final aRow = (a.centerY / rowTolerance).floor();
      final bRow = (b.centerY / rowTolerance).floor();

      if (aRow != bRow) {
        return aRow.compareTo(bRow);
      }
      return a.x1.compareTo(b.x1);
    });
    return sorted;
  }

  /// Generate HTML elements from detections
  static String _generateElements(
      List<DetectionBox> detections, DetectionResult result) {
    final buffer = StringBuffer();
    final imgWidth = result.imageWidth.toDouble();
    final imgHeight = result.imageHeight.toDouble();

    for (var i = 0; i < detections.length; i++) {
      final box = detections[i];
      final isEditableElement = isEditable(box.className);

      // Calculate percentage positions
      final left = (box.x1 / imgWidth * 100).toStringAsFixed(3);
      final top = (box.y1 / imgHeight * 100).toStringAsFixed(3);
      final width = (box.width / imgWidth * 100).toStringAsFixed(3);
      final height = (box.height / imgHeight * 100).toStringAsFixed(3);

      final fontSize = _fontSizeMapping[box.className] ?? '14px';
      final cssClass = isEditableElement ? 'editable-field' : 'visual-element';
      final editableAttr = isEditableElement ? 'contenteditable="true"' : '';

      buffer.writeln('    <div class="form-element $cssClass ${_toCssClass(box.className)}"');
      buffer.writeln('         $editableAttr');
      buffer.writeln('         style="left: $left%; top: $top%; width: $width%; height: $height%; font-size: $fontSize;"');
      buffer.writeln('         data-type="${box.className}"');
      buffer.writeln('         data-index="$i"');
      buffer.writeln('         data-score="${box.score.toStringAsFixed(4)}"');
      if (isEditableElement) {
        buffer.writeln('         placeholder="${_getPlaceholder(box.className)}"');
      }
      buffer.writeln('    ></div>');
    }

    return buffer.toString();
  }

  /// Convert class name to CSS class
  static String _toCssClass(String className) {
    return className.replaceAll('_', '-');
  }

  /// Get placeholder text for editable field
  static String _getPlaceholder(String className) {
    switch (className) {
      case 'doc_title':
        return 'Document Title';
      case 'paragraph_title':
        return 'Section Title';
      case 'text':
        return 'Text content...';
      case 'abstract':
        return 'Abstract...';
      case 'content':
        return 'Content...';
      case 'figure_title':
        return 'Figure caption';
      case 'table_title':
        return 'Table caption';
      case 'chart_title':
        return 'Chart caption';
      case 'reference':
        return 'Reference';
      case 'footnote':
        return 'Footnote';
      case 'header':
        return 'Header';
      case 'footer':
        return 'Footer';
      case 'number':
        return '#';
      case 'formula_number':
        return '(#)';
      case 'aside_text':
        return 'Note...';
      default:
        return '';
    }
  }

  /// Generate CSS styles
  static String _generateCss(String? backgroundImageData) {
    final backgroundStyle = backgroundImageData != null
        ? '''
      background-image: url('$backgroundImageData');
      background-size: 100% 100%;
      background-position: center;
      background-repeat: no-repeat;'''
        : 'background: #fff;';

    return '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang TC', 'Microsoft JhengHei', sans-serif;
      background: #e0e0e0;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      padding: 0;
    }

    .document-container {
      position: relative;
      width: 100%;
      height: 100%;
      $backgroundStyle
    }

    .form-element {
      position: absolute;
      overflow: hidden;
      word-wrap: break-word;
      line-height: 1.4;
    }

    /* Editable field styles */
    .editable-field {
      background: rgba(255, 255, 255, 0.7);
      border: 1px dashed rgba(0, 120, 215, 0.5);
      border-radius: 2px;
      padding: 2px 4px;
      cursor: text;
      outline: none;
      transition: background 0.2s, border-color 0.2s, box-shadow 0.2s;
    }

    .editable-field:hover {
      background: rgba(255, 255, 255, 0.85);
      border-color: rgba(0, 120, 215, 0.8);
    }

    .editable-field:focus,
    .editable-field.focused {
      background: rgba(255, 255, 255, 0.95);
      border: 2px solid #0078d7;
      box-shadow: 0 0 0 3px rgba(0, 120, 215, 0.3);
      z-index: 100;
    }

    .editable-field:empty::before {
      content: attr(placeholder);
      color: #999;
      font-style: italic;
      pointer-events: none;
    }

    /* Visual element styles (non-editable) */
    .visual-element {
      pointer-events: none;
      border: 1px dashed rgba(100, 100, 100, 0.3);
      background: rgba(200, 200, 200, 0.1);
    }

    /* Element type specific styles */
    .doc-title {
      font-weight: bold;
      text-align: center;
    }

    .paragraph-title {
      font-weight: 600;
    }

    .text, .content, .abstract {
      text-align: justify;
    }

    .figure-title, .table-title, .chart-title {
      text-align: center;
      font-style: italic;
    }

    .footnote, .reference {
      font-size: 11px;
    }

    .header, .footer {
      text-align: center;
      color: #666;
    }

    .number, .formula-number {
      text-align: center;
    }

    /* Print styles */
    @media print {
      body {
        background: none;
        padding: 0;
      }

      .document-container {
        background-image: none !important;
        background: none !important;
        width: 100%;
        height: auto;
        box-shadow: none;
      }

      .form-element {
        border: none !important;
        background: none !important;
        box-shadow: none !important;
      }

      .editable-field:empty::before {
        display: none;
      }

      .visual-element {
        display: none;
      }
    }

    /* Export mode - hide ghost image but keep layout */
    .document-container.export-mode {
      background-image: none !important;
      background: #fff !important;
    }

    .export-mode .form-element {
      border: none !important;
      background: none !important;
    }

    .export-mode .visual-element {
      display: none;
    }
''';
  }

  /// Generate JavaScript for interactivity
  static String _generateScript() {
    return '''
    var editableFields = document.querySelectorAll('.editable-field');
    var fieldArray = Array.from(editableFields);
    var currentFieldIndex = -1;

    // Track content changes
    editableFields.forEach(function(el, index) {
      el.dataset.fieldIndex = index;

      el.addEventListener('input', function() {
        if (this.textContent.trim().length > 0) {
          this.classList.add('has-content');
        } else {
          this.classList.remove('has-content');
        }
      });

      // Track focus
      el.addEventListener('focus', function() {
        currentFieldIndex = parseInt(this.dataset.fieldIndex);
        this.classList.add('focused');
      });

      el.addEventListener('blur', function() {
        this.classList.remove('focused');
      });

      // Handle keyboard navigation
      el.addEventListener('keydown', function(e) {
        // Tab or Enter to next field
        if (e.key === 'Tab' || e.key === 'Enter') {
          e.preventDefault();
          var nextIndex = e.shiftKey ? currentFieldIndex - 1 : currentFieldIndex + 1;
          if (nextIndex >= 0 && nextIndex < fieldArray.length) {
            fieldArray[nextIndex].focus();
            // Move cursor to end
            var range = document.createRange();
            var sel = window.getSelection();
            range.selectNodeContents(fieldArray[nextIndex]);
            range.collapse(false);
            sel.removeAllRanges();
            sel.addRange(range);
          }
        }
        // Arrow down to next field
        if (e.key === 'ArrowDown' && e.ctrlKey) {
          e.preventDefault();
          if (currentFieldIndex + 1 < fieldArray.length) {
            fieldArray[currentFieldIndex + 1].focus();
          }
        }
        // Arrow up to previous field
        if (e.key === 'ArrowUp' && e.ctrlKey) {
          e.preventDefault();
          if (currentFieldIndex - 1 >= 0) {
            fieldArray[currentFieldIndex - 1].focus();
          }
        }
      });
    });

    // Prevent losing focus when clicking container background
    document.querySelector('.document-container').addEventListener('mousedown', function(e) {
      if (e.target === this) {
        e.preventDefault();
        // Keep focus on current field
        if (currentFieldIndex >= 0 && currentFieldIndex < fieldArray.length) {
          fieldArray[currentFieldIndex].focus();
        }
      }
    });

    // Click on editable field to focus
    editableFields.forEach(function(el) {
      el.addEventListener('mousedown', function(e) {
        e.stopPropagation();
      });

      el.addEventListener('click', function(e) {
        e.stopPropagation();
        this.focus();
      });
    });

    // Get all form data as JSON
    function getFormData() {
      var data = [];
      document.querySelectorAll('.form-element').forEach(function(el) {
        data.push({
          type: el.dataset.type,
          index: parseInt(el.dataset.index),
          content: el.textContent || '',
          isEditable: el.classList.contains('editable-field')
        });
      });
      return JSON.stringify(data);
    }

    // Set form data from JSON
    function setFormData(jsonData) {
      var data = JSON.parse(jsonData);
      data.forEach(function(item) {
        var el = document.querySelector('[data-index="' + item.index + '"]');
        if (el && item.content) {
          el.textContent = item.content;
          if (item.content.trim().length > 0) {
            el.classList.add('has-content');
          }
        }
      });
    }

    // Toggle export mode (hide background and borders)
    function setExportMode(enabled) {
      var container = document.querySelector('.document-container');
      if (enabled) {
        container.classList.add('export-mode');
      } else {
        container.classList.remove('export-mode');
      }
    }

    // Get HTML content for export
    function getExportHtml() {
      setExportMode(true);
      var html = document.documentElement.outerHTML;
      setExportMode(false);
      return html;
    }

    // Focus specific field by index
    function focusField(index) {
      if (index >= 0 && index < fieldArray.length) {
        fieldArray[index].focus();
      }
    }

    // Focus next field
    function focusNextField() {
      var next = currentFieldIndex + 1;
      if (next < fieldArray.length) {
        fieldArray[next].focus();
      }
    }

    // Focus previous field
    function focusPrevField() {
      var prev = currentFieldIndex - 1;
      if (prev >= 0) {
        fieldArray[prev].focus();
      }
    }
''';
  }

  /// Generate error HTML
  static String _generateErrorHtml(String error) {
    return '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Error</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background: #f5f5f5;
    }
    .error {
      background: #fff;
      padding: 20px 40px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      color: #e74c3c;
    }
  </style>
</head>
<body>
  <div class="error">
    <h2>Error</h2>
    <p>${_escapeHtml(error)}</p>
  </div>
</body>
</html>''';
  }

  /// Escape HTML special characters
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
