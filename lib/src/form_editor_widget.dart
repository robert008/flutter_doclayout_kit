import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';

/// Form field data for editing
class FormFieldData {
  final int index;
  final DetectionBox box;
  final TextEditingController controller;
  final FocusNode focusNode;
  bool isEditable;

  FormFieldData({
    required this.index,
    required this.box,
    required this.controller,
    required this.focusNode,
    this.isEditable = true,
  });

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// Form editor result containing all edited content
class FormEditorResult {
  final List<FormFieldContent> fields;
  final int imageWidth;
  final int imageHeight;

  FormEditorResult({
    required this.fields,
    required this.imageWidth,
    required this.imageHeight,
  });

  Map<String, dynamic> toJson() => {
    'fields': fields.map((f) => f.toJson()).toList(),
    'image_width': imageWidth,
    'image_height': imageHeight,
  };
}

/// Individual field content
class FormFieldContent {
  final int index;
  final String type;
  final String content;
  final double x1, y1, x2, y2;

  FormFieldContent({
    required this.index,
    required this.type,
    required this.content,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'type': type,
    'content': content,
    'bbox': [x1, y1, x2, y2],
  };
}

/// Text-based element types that should be editable
const Set<String> editableTypes = {
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

/// Check if element type is editable
bool isEditableType(String className) => editableTypes.contains(className);

/// Pure Flutter form editor widget
class FormEditorWidget extends StatefulWidget {
  /// Detection result from AI analysis
  final DetectionResult result;

  /// Background image bytes
  final Uint8List imageBytes;

  /// Whether to show ghost background image
  final bool showGhostImage;

  /// Ghost image opacity (0.0 - 1.0)
  final double ghostOpacity;

  /// Callback when form data changes
  final ValueChanged<FormEditorResult>? onChanged;

  /// Editable field border color
  final Color borderColor;

  /// Focused field border color
  final Color focusedBorderColor;

  /// Field background color
  final Color fieldBackgroundColor;

  /// Whether to show border on fields
  final bool showBorder;

  const FormEditorWidget({
    super.key,
    required this.result,
    required this.imageBytes,
    this.showGhostImage = true,
    this.ghostOpacity = 0.3,
    this.onChanged,
    this.borderColor = const Color(0x800078D7),
    this.focusedBorderColor = const Color(0xFF0078D7),
    this.fieldBackgroundColor = const Color(0xDDFFFFFF),
    this.showBorder = true,
  });

  @override
  State<FormEditorWidget> createState() => FormEditorWidgetState();
}

class FormEditorWidgetState extends State<FormEditorWidget> {
  final List<FormFieldData> _fields = [];
  ui.Image? _backgroundImage;
  Size? _imageSize;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initFields();
    _loadImage();
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    _backgroundImage?.dispose();
    super.dispose();
  }

  void _initFields() {
    final sortedDetections = _sortByReadingOrder(widget.result.detections);

    for (var i = 0; i < sortedDetections.length; i++) {
      final box = sortedDetections[i];
      final isEditable = isEditableType(box.className);

      _fields.add(FormFieldData(
        index: i,
        box: box,
        controller: TextEditingController(),
        focusNode: FocusNode(),
        isEditable: isEditable,
      ));
    }
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();

    if (mounted) {
      setState(() {
        _backgroundImage = frame.image;
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        _isLoading = false;
      });
    }
  }

  List<DetectionBox> _sortByReadingOrder(List<DetectionBox> detections) {
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

  /// Get current form data
  FormEditorResult getFormData() {
    final fields = _fields.map((f) => FormFieldContent(
      index: f.index,
      type: f.box.className,
      content: f.controller.text,
      x1: f.box.x1,
      y1: f.box.y1,
      x2: f.box.x2,
      y2: f.box.y2,
    )).toList();

    return FormEditorResult(
      fields: fields,
      imageWidth: widget.result.imageWidth,
      imageHeight: widget.result.imageHeight,
    );
  }

  /// Set form data
  void setFormData(Map<int, String> data) {
    for (final field in _fields) {
      if (data.containsKey(field.index)) {
        field.controller.text = data[field.index]!;
      }
    }
  }

  /// Clear all fields
  void clearAll() {
    for (final field in _fields) {
      field.controller.clear();
    }
  }

  /// Focus next editable field
  void focusNextField() {
    final currentIndex = _fields.indexWhere((f) => f.focusNode.hasFocus);
    if (currentIndex == -1) {
      // No field focused, focus first editable
      final first = _fields.where((f) => f.isEditable).firstOrNull;
      first?.focusNode.requestFocus();
    } else {
      // Find next editable field
      for (var i = currentIndex + 1; i < _fields.length; i++) {
        if (_fields[i].isEditable) {
          _fields[i].focusNode.requestFocus();
          return;
        }
      }
    }
  }

  /// Focus previous editable field
  void focusPreviousField() {
    final currentIndex = _fields.indexWhere((f) => f.focusNode.hasFocus);
    if (currentIndex > 0) {
      for (var i = currentIndex - 1; i >= 0; i--) {
        if (_fields[i].isEditable) {
          _fields[i].focusNode.requestFocus();
          return;
        }
      }
    }
  }

  void _onFieldChanged() {
    widget.onChanged?.call(getFormData());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate scale to fit image
        final scaleX = constraints.maxWidth / _imageSize!.width;
        final scaleY = constraints.maxHeight / _imageSize!.height;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final scaledWidth = _imageSize!.width * scale;
        final scaledHeight = _imageSize!.height * scale;

        return Center(
          child: SizedBox(
            width: scaledWidth,
            height: scaledHeight,
            child: Stack(
              children: [
                // Background image (Ghost mode)
                if (widget.showGhostImage && _backgroundImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: widget.ghostOpacity,
                      child: RawImage(
                        image: _backgroundImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                // Editable fields
                ..._fields.map((field) => _buildField(field, scale)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(FormFieldData field, double scale) {
    final box = field.box;
    final left = box.x1 * scale;
    final top = box.y1 * scale;
    final width = box.width * scale;
    final height = box.height * scale;

    if (!field.isEditable) {
      // Non-editable visual element - show type label
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.5),
              style: BorderStyle.solid,
            ),
            color: Colors.orange.withValues(alpha: 0.1),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    box.className,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Editable text field
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _EditableField(
              field: field,
              borderColor: widget.borderColor,
              focusedBorderColor: widget.focusedBorderColor,
              backgroundColor: widget.fieldBackgroundColor,
              showBorder: widget.showBorder,
              onChanged: _onFieldChanged,
              onSubmitted: focusNextField,
            ),
          ),
          // Type label
          Positioned(
            left: 0,
            top: -12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                box.className,
                style: const TextStyle(
                  fontSize: 7,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatefulWidget {
  final FormFieldData field;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color backgroundColor;
  final bool showBorder;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;

  const _EditableField({
    required this.field,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.backgroundColor,
    this.showBorder = true,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  double _getFontSize() {
    switch (widget.field.box.className) {
      case 'doc_title':
        return 14;
      case 'paragraph_title':
        return 12;
      case 'footnote':
      case 'reference':
        return 9;
      default:
        return 10;
    }
  }

  TextAlign _getTextAlign() {
    switch (widget.field.box.className) {
      case 'doc_title':
      case 'figure_title':
      case 'table_title':
      case 'chart_title':
      case 'header':
      case 'footer':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  String _getHint() {
    switch (widget.field.box.className) {
      case 'doc_title':
        return 'Document Title';
      case 'paragraph_title':
        return 'Section Title';
      case 'text':
      case 'content':
        return 'Text content...';
      case 'abstract':
        return 'Abstract...';
      case 'header':
        return 'Header';
      case 'footer':
        return 'Footer';
      default:
        return 'Enter text...';
    }
  }

  String _getTypeLabel() {
    switch (widget.field.box.className) {
      case 'doc_title':
        return 'Title';
      case 'paragraph_title':
        return 'Section';
      case 'text':
        return 'Text';
      case 'content':
        return 'Content';
      case 'abstract':
        return 'Abstract';
      case 'header':
        return 'Header';
      case 'footer':
        return 'Footer';
      case 'footnote':
        return 'Footnote';
      case 'reference':
        return 'Reference';
      default:
        return widget.field.box.className;
    }
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: widget.field.controller.text);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getTypeLabel()),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 2,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _getHint(),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(12),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null) {
      widget.field.controller.text = result;
      widget.onChanged?.call();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.field.controller.text.isNotEmpty;

    return GestureDetector(
      onTap: _showEditDialog,
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: widget.showBorder
              ? Border.all(
                  color: hasContent ? widget.focusedBorderColor : widget.borderColor,
                  width: 1,
                )
              : null,
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.all(2),
        child: hasContent
            ? Text(
                widget.field.controller.text,
                style: TextStyle(
                  fontSize: _getFontSize(),
                  height: 1.2,
                ),
                textAlign: _getTextAlign(),
                overflow: TextOverflow.ellipsis,
                maxLines: 10,
              )
            : Center(
                child: Icon(
                  Icons.edit,
                  size: 12,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ),
      ),
    );
  }
}
