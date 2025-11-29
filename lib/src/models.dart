/// 23 document element classes
enum DocLayoutClass {
  paragraphTitle(0, 'paragraph_title'),
  image(1, 'image'),
  text(2, 'text'),
  number(3, 'number'),
  abstract_(4, 'abstract'),
  content(5, 'content'),
  figureTitle(6, 'figure_title'),
  formula(7, 'formula'),
  table(8, 'table'),
  tableTitle(9, 'table_title'),
  reference(10, 'reference'),
  docTitle(11, 'doc_title'),
  footnote(12, 'footnote'),
  header(13, 'header'),
  algorithm(14, 'algorithm'),
  footer(15, 'footer'),
  seal(16, 'seal'),
  chartTitle(17, 'chart_title'),
  chart(18, 'chart'),
  formulaNumber(19, 'formula_number'),
  headerImage(20, 'header_image'),
  footerImage(21, 'footer_image'),
  asideText(22, 'aside_text');

  final int id;
  final String name;

  const DocLayoutClass(this.id, this.name);

  static DocLayoutClass? fromId(int id) {
    return DocLayoutClass.values.where((e) => e.id == id).firstOrNull;
  }

  static DocLayoutClass? fromName(String name) {
    return DocLayoutClass.values.where((e) => e.name == name).firstOrNull;
  }
}

/// Detection bounding box
class DetectionBox {
  /// Top-left x coordinate (in original image space)
  final double x1;

  /// Top-left y coordinate (in original image space)
  final double y1;

  /// Bottom-right x coordinate (in original image space)
  final double x2;

  /// Bottom-right y coordinate (in original image space)
  final double y2;

  /// Confidence score (0.0 - 1.0)
  final double score;

  /// Class ID (0-22)
  final int classId;

  /// Class name
  final String className;

  DetectionBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.classId,
    required this.className,
  });

  /// Get the layout class enum
  DocLayoutClass? get layoutClass => DocLayoutClass.fromId(classId);

  /// Box width
  double get width => x2 - x1;

  /// Box height
  double get height => y2 - y1;

  /// Box center x
  double get centerX => (x1 + x2) / 2;

  /// Box center y
  double get centerY => (y1 + y2) / 2;

  /// Box area
  double get area => width * height;

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    return DetectionBox(
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      classId: json['class_id'] as int,
      className: json['class_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'score': score,
      'class_id': classId,
      'class_name': className,
    };
  }

  @override
  String toString() {
    return 'DetectionBox($className: [$x1, $y1, $x2, $y2], score: ${score.toStringAsFixed(4)})';
  }
}

/// Detection result containing all detections and metadata
class DetectionResult {
  /// List of detected boxes
  final List<DetectionBox> detections;

  /// Total number of detections
  final int count;

  /// Inference time in milliseconds
  final int inferenceTimeMs;

  /// Original image width
  final int imageWidth;

  /// Original image height
  final int imageHeight;

  /// Error message (if any)
  final String? error;

  /// Error code (if any)
  final String? errorCode;

  DetectionResult({
    required this.detections,
    required this.count,
    required this.inferenceTimeMs,
    required this.imageWidth,
    required this.imageHeight,
    this.error,
    this.errorCode,
  });

  /// Check if result has error
  bool get hasError => error != null;

  /// Check if result is successful
  bool get isSuccess => error == null;

  /// Filter detections by class
  List<DetectionBox> filterByClass(DocLayoutClass layoutClass) {
    return detections.where((d) => d.classId == layoutClass.id).toList();
  }

  /// Filter detections by minimum score
  List<DetectionBox> filterByScore(double minScore) {
    return detections.where((d) => d.score >= minScore).toList();
  }

  /// Create an error result
  factory DetectionResult.error(String errorMessage, {String? code}) {
    return DetectionResult(
      detections: [],
      count: 0,
      inferenceTimeMs: 0,
      imageWidth: 0,
      imageHeight: 0,
      error: errorMessage,
      errorCode: code,
    );
  }

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    // Check for error response
    if (json.containsKey('error')) {
      return DetectionResult(
        detections: [],
        count: 0,
        inferenceTimeMs: 0,
        imageWidth: 0,
        imageHeight: 0,
        error: json['error'] as String,
        errorCode: json['code'] as String?,
      );
    }

    final detectionsJson = json['detections'] as List<dynamic>;
    final detections = detectionsJson
        .map((d) => DetectionBox.fromJson(d as Map<String, dynamic>))
        .toList();

    return DetectionResult(
      detections: detections,
      count: json['count'] as int,
      inferenceTimeMs: json['inference_time_ms'] as int,
      imageWidth: json['image_width'] as int,
      imageHeight: json['image_height'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    if (hasError) {
      return {
        'error': error,
        'code': errorCode,
      };
    }

    return {
      'detections': detections.map((d) => d.toJson()).toList(),
      'count': count,
      'inference_time_ms': inferenceTimeMs,
      'image_width': imageWidth,
      'image_height': imageHeight,
    };
  }

  @override
  String toString() {
    if (hasError) {
      return 'DetectionResult(error: $error, code: $errorCode)';
    }
    return 'DetectionResult(count: $count, inferenceTime: ${inferenceTimeMs}ms, size: ${imageWidth}x$imageHeight)';
  }
}
