#ifndef UTILS_H
#define UTILS_H

#include <utility>
#include <iostream>
#include <chrono>
#include <tuple>
#include <vector>
#include <map>
#include <string>
#include <opencv2/dnn.hpp>
#include <opencv2/opencv.hpp>
#include <onnxruntime_cxx_api.h>

using std::map;
using std::pair;
using std::string;
using std::to_string;
using std::vector;
using std::ifstream;
using std::runtime_error;
using std::endl;
using std::max;
using std::min;
using std::get;
using std::sort;
using std::round;
using std::cerr;
using std::cout;
using namespace std::chrono;

// PP-DocLayout preprocess: resize to target size and return scale factors
std::pair<cv::Mat, std::vector<float>> preprocessImage(const cv::Mat& img, int target_width = 640, int target_height = 640);

// Convert image to blob for ONNX inference
cv::Mat imageToBlob(const cv::Mat& img);

#endif
