#include <opencv2/opencv.hpp>
#include <onnxruntime_cxx_api.h>
#include <cstring>
#include <vector>
#include <iostream>
#include <string>
#include <future>
#include <chrono>

#include "detect/include/config_manager.h"
#include "detect/include/doc_detector.h"

#ifdef __ANDROID__
#include <android/log.h>
#endif

#define LOGI(...) do {} while(0)
#define LOGE(...) do {} while(0)

using namespace std::chrono;

// Initialize model path
extern "C" __attribute__((visibility("default")))
void initModel(const char* model_path) {
    ConfigManager::GetInstance().Init(std::string(model_path));
    LOGI("Model initialized: %s\n", model_path);
}

// Detect document layout from image path (async)
extern "C" __attribute__((visibility("default")))
char* detectLayout(const char* img_path, float conf_threshold) {
    return strdup(std::async(std::launch::async, [img_path, conf_threshold]() -> std::string {
        auto start = high_resolution_clock::now();

        // Load image
        cv::Mat image = cv::imread(img_path);
        if (image.empty()) {
            return "{\"error\":\"Could not load image\",\"code\":\"IMAGE_LOAD_FAILED\"}";
        }

        // Run detection
        std::vector<DetectionBox> detections = detectDocLayout(image, conf_threshold);

        auto end = high_resolution_clock::now();
        long long inference_time = duration_cast<milliseconds>(end - start).count();

        // Build JSON response
        std::ostringstream json;
        json << "{\"detections\":[";

        for (size_t i = 0; i < detections.size(); i++) {
            const auto& box = detections[i];
            json << "{";
            json << "\"x1\":" << std::fixed << std::setprecision(1) << box.x1 << ",";
            json << "\"y1\":" << box.y1 << ",";
            json << "\"x2\":" << box.x2 << ",";
            json << "\"y2\":" << box.y2 << ",";
            json << "\"score\":" << std::setprecision(4) << box.score << ",";
            json << "\"class_id\":" << box.class_id << ",";
            json << "\"class_name\":\"" << box.class_name << "\"";
            json << "}";
            if (i < detections.size() - 1) {
                json << ",";
            }
        }

        json << "],";
        json << "\"count\":" << detections.size() << ",";
        json << "\"inference_time_ms\":" << inference_time << ",";
        json << "\"image_width\":" << image.cols << ",";
        json << "\"image_height\":" << image.rows;
        json << "}";

        return json.str();
    }).get().c_str());
}

// Detect from image bytes (for camera preview)
extern "C" __attribute__((visibility("default")))
char* detectLayoutFromBytes(const unsigned char* image_data, int width, int height, int channels, float conf_threshold) {
    return strdup(std::async(std::launch::async, [image_data, width, height, channels, conf_threshold]() -> std::string {
        auto start = high_resolution_clock::now();

        // Create cv::Mat from bytes
        int cv_type = (channels == 4) ? CV_8UC4 : (channels == 3) ? CV_8UC3 : CV_8UC1;
        cv::Mat image(height, width, cv_type, const_cast<unsigned char*>(image_data));

        // Convert to BGR if needed
        cv::Mat bgr_image;
        if (channels == 4) {
            cv::cvtColor(image, bgr_image, cv::COLOR_RGBA2BGR);
        } else if (channels == 1) {
            cv::cvtColor(image, bgr_image, cv::COLOR_GRAY2BGR);
        } else {
            bgr_image = image;
        }

        // Run detection
        std::vector<DetectionBox> detections = detectDocLayout(bgr_image, conf_threshold);

        auto end = high_resolution_clock::now();
        long long inference_time = duration_cast<milliseconds>(end - start).count();

        // Build JSON response
        std::ostringstream json;
        json << "{\"detections\":[";

        for (size_t i = 0; i < detections.size(); i++) {
            const auto& box = detections[i];
            json << "{";
            json << "\"x1\":" << std::fixed << std::setprecision(1) << box.x1 << ",";
            json << "\"y1\":" << box.y1 << ",";
            json << "\"x2\":" << box.x2 << ",";
            json << "\"y2\":" << box.y2 << ",";
            json << "\"score\":" << std::setprecision(4) << box.score << ",";
            json << "\"class_id\":" << box.class_id << ",";
            json << "\"class_name\":\"" << box.class_name << "\"";
            json << "}";
            if (i < detections.size() - 1) {
                json << ",";
            }
        }

        json << "],";
        json << "\"count\":" << detections.size() << ",";
        json << "\"inference_time_ms\":" << inference_time << ",";
        json << "\"image_width\":" << width << ",";
        json << "\"image_height\":" << height;
        json << "}";

        return json.str();
    }).get().c_str());
}

// Free allocated string memory
extern "C" __attribute__((visibility("default")))
void freeString(char* str) {
    if (str) {
        free(str);
    }
}

// Get version info
extern "C" __attribute__((visibility("default")))
const char* getVersion() {
    return "1.0.0";
}
