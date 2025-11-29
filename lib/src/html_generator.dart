import 'models.dart';

/// HTML Generator for document layout detection results
class HtmlGenerator {
  /// Class name to HTML tag mapping
  static const Map<String, String> _tagMapping = {
    'doc_title': 'h1',
    'paragraph_title': 'h2',
    'text': 'p',
    'abstract': 'blockquote',
    'content': 'section',
    'image': 'figure',
    'figure_title': 'figcaption',
    'table': 'table',
    'table_title': 'caption',
    'chart': 'figure',
    'chart_title': 'figcaption',
    'formula': 'div',
    'formula_number': 'span',
    'algorithm': 'pre',
    'reference': 'cite',
    'footnote': 'footer',
    'header': 'header',
    'footer': 'footer',
    'header_image': 'figure',
    'footer_image': 'figure',
    'number': 'span',
    'seal': 'figure',
    'aside_text': 'aside',
  };

  /// Class name to CSS class mapping
  static const Map<String, String> _cssClassMapping = {
    'doc_title': 'doc-title',
    'paragraph_title': 'paragraph-title',
    'text': 'text-block',
    'abstract': 'abstract',
    'content': 'content',
    'image': 'image',
    'figure_title': 'figure-title',
    'table': 'table',
    'table_title': 'table-title',
    'chart': 'chart',
    'chart_title': 'chart-title',
    'formula': 'formula',
    'formula_number': 'formula-number',
    'algorithm': 'algorithm',
    'reference': 'reference',
    'footnote': 'footnote',
    'header': 'header',
    'footer': 'footer',
    'header_image': 'header-image',
    'footer_image': 'footer-image',
    'number': 'number',
    'seal': 'seal',
    'aside_text': 'aside-text',
  };

  /// Generate HTML from detection result
  static String generate(DetectionResult result, {String? title}) {
    if (!result.isSuccess || result.detections.isEmpty) {
      return _generateEmptyHtml(title);
    }

    final sortedDetections = _sortByReadingOrder(result.detections);
    final elements = _generateElements(sortedDetections, result);
    final css = _generateCss();

    return '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title ?? 'Document Layout'}</title>
  <style>
$css
  </style>
</head>
<body>
  <article class="document-container" data-width="${result.imageWidth}" data-height="${result.imageHeight}">
$elements
  </article>
</body>
</html>''';
  }

  /// Generate only the body content (without full HTML structure)
  static String generateBody(DetectionResult result) {
    if (!result.isSuccess || result.detections.isEmpty) {
      return '<article class="document-container"></article>';
    }

    final sortedDetections = _sortByReadingOrder(result.detections);
    final elements = _generateElements(sortedDetections, result);

    return '''<article class="document-container" data-width="${result.imageWidth}" data-height="${result.imageHeight}">
$elements
</article>''';
  }

  /// Sort detections by reading order (top to bottom, left to right)
  static List<DetectionBox> _sortByReadingOrder(List<DetectionBox> detections) {
    final sorted = List<DetectionBox>.from(detections);
    sorted.sort((a, b) {
      // Group by approximate row (using y center with tolerance)
      final rowTolerance = 50.0;
      final aRow = (a.centerY / rowTolerance).floor();
      final bRow = (b.centerY / rowTolerance).floor();

      if (aRow != bRow) {
        return aRow.compareTo(bRow);
      }
      // Same row, sort by x
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
      final tag = _tagMapping[box.className] ?? 'div';
      final cssClass = _cssClassMapping[box.className] ?? 'unknown';

      // Calculate percentage positions
      final left = (box.x1 / imgWidth * 100).toStringAsFixed(2);
      final top = (box.y1 / imgHeight * 100).toStringAsFixed(2);
      final width = (box.width / imgWidth * 100).toStringAsFixed(2);
      final height = (box.height / imgHeight * 100).toStringAsFixed(2);

      final style =
          'left: $left%; top: $top%; width: $width%; height: $height%;';

      buffer.writeln('    <$tag class="layout-element $cssClass"');
      buffer.writeln('         style="$style"');
      buffer.writeln(
          '         data-box="${box.x1.toInt()},${box.y1.toInt()},${box.x2.toInt()},${box.y2.toInt()}"');
      buffer.writeln('         data-score="${box.score.toStringAsFixed(4)}"');
      buffer.writeln('         data-class="${box.className}"');
      buffer.writeln('         data-index="$i">');
      buffer.writeln('      <!-- ${box.className} -->');
      buffer.writeln('    </$tag>');
    }

    return buffer.toString();
  }

  /// Generate CSS styles
  static String _generateCss() {
    return '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f5f5f5;
      padding: 20px;
    }

    .document-container {
      position: relative;
      width: 100%;
      max-width: 800px;
      margin: 0 auto;
      background: white;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      aspect-ratio: attr(data-width) / attr(data-height);
      min-height: 600px;
    }

    .layout-element {
      position: absolute;
      border: 2px solid;
      border-radius: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
      color: #666;
      transition: all 0.2s ease;
    }

    .layout-element:hover {
      z-index: 100;
      transform: scale(1.02);
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }

    .layout-element::before {
      content: attr(data-class);
      position: absolute;
      top: -20px;
      left: 0;
      font-size: 10px;
      padding: 2px 6px;
      border-radius: 3px;
      color: white;
      white-space: nowrap;
    }

    /* Element type colors */
    .doc-title { border-color: #e74c3c; background: rgba(231,76,60,0.1); }
    .doc-title::before { background: #e74c3c; }

    .paragraph-title { border-color: #e67e22; background: rgba(230,126,34,0.1); }
    .paragraph-title::before { background: #e67e22; }

    .text-block { border-color: #3498db; background: rgba(52,152,219,0.1); }
    .text-block::before { background: #3498db; }

    .abstract { border-color: #9b59b6; background: rgba(155,89,182,0.1); }
    .abstract::before { background: #9b59b6; }

    .content { border-color: #1abc9c; background: rgba(26,188,156,0.1); }
    .content::before { background: #1abc9c; }

    .image { border-color: #2ecc71; background: rgba(46,204,113,0.1); }
    .image::before { background: #2ecc71; }

    .figure-title { border-color: #27ae60; background: rgba(39,174,96,0.1); }
    .figure-title::before { background: #27ae60; }

    .table { border-color: #8e44ad; background: rgba(142,68,173,0.1); }
    .table::before { background: #8e44ad; }

    .table-title { border-color: #9b59b6; background: rgba(155,89,182,0.1); }
    .table-title::before { background: #9b59b6; }

    .chart { border-color: #16a085; background: rgba(22,160,133,0.1); }
    .chart::before { background: #16a085; }

    .chart-title { border-color: #1abc9c; background: rgba(26,188,156,0.1); }
    .chart-title::before { background: #1abc9c; }

    .formula { border-color: #f39c12; background: rgba(243,156,18,0.1); }
    .formula::before { background: #f39c12; }

    .formula-number { border-color: #f1c40f; background: rgba(241,196,15,0.1); }
    .formula-number::before { background: #f1c40f; }

    .algorithm { border-color: #34495e; background: rgba(52,73,94,0.1); }
    .algorithm::before { background: #34495e; }

    .reference { border-color: #7f8c8d; background: rgba(127,140,141,0.1); }
    .reference::before { background: #7f8c8d; }

    .footnote { border-color: #95a5a6; background: rgba(149,165,166,0.1); }
    .footnote::before { background: #95a5a6; }

    .header { border-color: #2c3e50; background: rgba(44,62,80,0.1); }
    .header::before { background: #2c3e50; }

    .footer { border-color: #34495e; background: rgba(52,73,94,0.1); }
    .footer::before { background: #34495e; }

    .header-image { border-color: #1e3a5f; background: rgba(30,58,95,0.1); }
    .header-image::before { background: #1e3a5f; }

    .footer-image { border-color: #2c3e50; background: rgba(44,62,80,0.1); }
    .footer-image::before { background: #2c3e50; }

    .number { border-color: #e74c3c; background: rgba(231,76,60,0.1); }
    .number::before { background: #e74c3c; }

    .seal { border-color: #c0392b; background: rgba(192,57,43,0.1); }
    .seal::before { background: #c0392b; }

    .aside-text { border-color: #bdc3c7; background: rgba(189,195,199,0.1); }
    .aside-text::before { background: #bdc3c7; }

    .unknown { border-color: #95a5a6; background: rgba(149,165,166,0.1); }
    .unknown::before { background: #95a5a6; }
''';
  }

  /// Generate empty HTML template
  static String _generateEmptyHtml(String? title) {
    return '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title ?? 'Document Layout'}</title>
</head>
<body>
  <article class="document-container">
    <p>No detections available</p>
  </article>
</body>
</html>''';
  }
}
