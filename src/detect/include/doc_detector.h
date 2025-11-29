#ifndef DOC_DETECTOR_H
#define DOC_DETECTOR_H

#include "utils.h"
#include "config_manager.h"
#include <string>
#include <vector>

// Detection result structure
struct DetectionBox {
    float x1, y1, x2, y2;  // Bounding box coordinates (in original image space)
    float score;           // Confidence score
    int class_id;          // Class ID (0-22)
    std::string class_name; // Class name
};

// 23 document element classes
const std::vector<std::string> DOC_CLASSES = {
    "paragraph_title",  // 0
    "image",           // 1
    "text",            // 2
    "number",          // 3
    "abstract",        // 4
    "content",         // 5
    "figure_title",    // 6
    "formula",         // 7
    "table",           // 8
    "table_title",     // 9
    "reference",       // 10
    "doc_title",       // 11
    "footnote",        // 12
    "header",          // 13
    "algorithm",       // 14
    "footer",          // 15
    "seal",            // 16
    "chart_title",     // 17
    "chart",           // 18
    "formula_number",  // 19
    "header_image",    // 20
    "footer_image",    // 21
    "aside_text"       // 22
};

// Main detection function
std::vector<DetectionBox> detectDocLayout(const cv::Mat& image, float conf_threshold = 0.5);

// Convert detections to JSON string
std::string detectionsToJson(const std::vector<DetectionBox>& detections);

#endif // DOC_DETECTOR_H
