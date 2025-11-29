#include "include/utils.h"

std::pair<cv::Mat, std::vector<float>> preprocessImage(const cv::Mat& img, int target_width, int target_height) {
    // PP-DocLayout: keep_ratio = false, direct resize
    int orig_height = img.rows;
    int orig_width = img.cols;

    // Calculate scale factors for restoring coordinates
    float scale_x = static_cast<float>(target_width) / orig_width;
    float scale_y = static_cast<float>(target_height) / orig_height;
    std::vector<float> scale_factor = {scale_x, scale_y};

    // Convert BGR to RGB (OpenCV loads as BGR)
    cv::Mat img_rgb;
    cv::cvtColor(img, img_rgb, cv::COLOR_BGR2RGB);

    // Resize to target size (direct stretch, no padding)
    cv::Mat resized;
    cv::resize(img_rgb, resized, cv::Size(target_width, target_height), 0, 0, cv::INTER_LINEAR);

    return {resized, scale_factor};
}

cv::Mat imageToBlob(const cv::Mat& img) {
    // PP-DocLayout: mean=[0,0,0], std=[1,1,1] (no normalization, just scale to float)
    // Input: HWC RGB uint8 -> Output: NCHW float32 [0, 255]
    cv::Mat blob = cv::dnn::blobFromImage(
        img,
        1.0 / 255.0,  // Scale to [0, 1]
        cv::Size(),   // Keep size
        cv::Scalar(0, 0, 0),  // No mean subtraction
        false,        // swapRB: already RGB
        false,        // crop
        CV_32F
    );
    return blob;
}
