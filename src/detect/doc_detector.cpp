#include "include/doc_detector.h"
#include <sstream>
#include <iomanip>

#define LOGD(...) do {} while(0)

std::vector<DetectionBox> detectDocLayout(const cv::Mat& image, float conf_threshold) {
    std::vector<DetectionBox> results;

    LOGD("detectDocLayout called, image size: %dx%d, threshold: %.2f", image.cols, image.rows, conf_threshold);

    if (image.empty()) {
        LOGD("Error: Empty image");
        return results;
    }

    try {
        // 1. Initialize ONNX Runtime (static, only once)
        LOGD("Creating ONNX session...");
        static Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "DocLayout");
        static Ort::SessionOptions session_options;
        static Ort::Session session(env, ConfigManager::GetInstance().MODEL_PATH.c_str(), session_options);
        LOGD("ONNX session created");

        // 2. Get input/output info
        static Ort::AllocatorWithDefaultOptions allocator;
        static auto input_name = session.GetInputNameAllocated(0, allocator);

        // Get number of inputs and outputs
        size_t num_inputs = session.GetInputCount();
        size_t num_outputs = session.GetOutputCount();
        LOGD("Model has %zu inputs and %zu outputs", num_inputs, num_outputs);

        // Log input names
        for (size_t i = 0; i < num_inputs; i++) {
            auto name = session.GetInputNameAllocated(i, allocator);
            LOGD("Input %zu: %s", i, name.get());
        }

        // Log output names
        for (size_t i = 0; i < num_outputs; i++) {
            auto name = session.GetOutputNameAllocated(i, allocator);
            LOGD("Output %zu: %s", i, name.get());
        }

        static auto output_name_0 = session.GetOutputNameAllocated(0, allocator);
        static auto output_name_1 = (num_outputs > 1) ? session.GetOutputNameAllocated(1, allocator) : session.GetOutputNameAllocated(0, allocator);

        // 3. Preprocess image
        int target_width = 640;
        int target_height = 640;
        LOGD("Preprocessing image to %dx%d", target_width, target_height);
        auto [resized_img, scale_factor] = preprocessImage(image, target_width, target_height);
        LOGD("Scale factors: x=%.4f, y=%.4f", scale_factor[0], scale_factor[1]);

        // 4. Convert to blob
        cv::Mat blob = imageToBlob(resized_img);
        LOGD("Blob created, total elements: %zu", blob.total());

        // 5. Prepare input tensors
        std::vector<int64_t> image_shape = {1, 3, target_height, target_width};
        std::vector<int64_t> scale_shape = {1, 2};

        Ort::MemoryInfo memory_info = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);

        Ort::Value image_tensor = Ort::Value::CreateTensor<float>(
            memory_info, blob.ptr<float>(), blob.total(),
            image_shape.data(), image_shape.size());

        Ort::Value scale_tensor = Ort::Value::CreateTensor<float>(
            memory_info, scale_factor.data(), scale_factor.size(),
            scale_shape.data(), scale_shape.size());

        // 6. Run inference - auto detect model type (M: 2 inputs, L: 3 inputs)
        LOGD("Running inference with %zu inputs...", num_inputs);
        std::vector<Ort::Value> outputs;
        std::vector<const char*> input_names;
        std::vector<Ort::Value> input_tensors;
        std::vector<const char*> output_names = {output_name_0.get()};

        // Track if we're using L model
        bool is_l_model = (num_inputs == 3);

        // Prepare im_shape for L model (original image size)
        std::vector<float> im_shape_data = {static_cast<float>(image.rows), static_cast<float>(image.cols)};
        std::vector<int64_t> im_shape_shape = {1, 2};

        // L model scale_factor = [1.0, 1.0] (must be declared here to extend lifetime)
        std::vector<float> l_scale_factor = {1.0f, 1.0f};

        if (is_l_model) {
            // L model: im_shape, image, scale_factor
            // im_shape = original image size [h, w]
            // scale_factor = [1.0, 1.0] - L model uses im_shape internally to output original coords
            Ort::Value im_shape_tensor = Ort::Value::CreateTensor<float>(
                memory_info, im_shape_data.data(), im_shape_data.size(),
                im_shape_shape.data(), im_shape_shape.size());

            Ort::Value l_scale_tensor = Ort::Value::CreateTensor<float>(
                memory_info, l_scale_factor.data(), l_scale_factor.size(),
                scale_shape.data(), scale_shape.size());

            input_names = {"im_shape", "image", "scale_factor"};
            input_tensors.push_back(std::move(im_shape_tensor));
            input_tensors.push_back(std::move(image_tensor));
            input_tensors.push_back(std::move(l_scale_tensor));
            LOGD("Using L model format (3 inputs), im_shape=[%.0f, %.0f], scale_factor=[1.0, 1.0]", im_shape_data[0], im_shape_data[1]);
        } else {
            // M model: image, scale_factor
            input_names = {"image", "scale_factor"};
            input_tensors.push_back(std::move(image_tensor));
            input_tensors.push_back(std::move(scale_tensor));
            LOGD("Using M model format (2 inputs)");
        }

        outputs = session.Run(
            Ort::RunOptions{nullptr},
            input_names.data(), input_tensors.data(), input_tensors.size(),
            output_names.data(), output_names.size());

        LOGD("Inference complete");

        // 7. Parse output: [N, 6] = [x1, y1, x2, y2, score, class_id]
        auto output_shape = outputs[0].GetTensorTypeAndShapeInfo().GetShape();
        LOGD("Output shape: dims=%zu", output_shape.size());
        for (size_t i = 0; i < output_shape.size(); i++) {
            LOGD("  dim[%zu] = %lld", i, output_shape[i]);
        }

        int num_detections = static_cast<int>(output_shape[0]);
        LOGD("Number of raw detections: %d", num_detections);

        float* output_data = outputs[0].GetTensorMutableData<float>();

        // PP-DocLayout output format: [class_id, score, x1, y1, x2, y2]
        // Log first few raw outputs
        int log_count = std::min(5, num_detections);
        for (int i = 0; i < log_count; i++) {
            LOGD("Raw detection %d: class=%.0f, score=%.4f, x1=%.2f, y1=%.2f, x2=%.2f, y2=%.2f",
                i, output_data[i*6+0], output_data[i*6+1], output_data[i*6+2],
                output_data[i*6+3], output_data[i*6+4], output_data[i*6+5]);
        }

        // 8. Convert to DetectionBox and restore to original image coordinates
        // M model: output in 640 space, need to scale back to original
        // L model: output already in original space (scale_factor=[1,1]), no scaling needed
        float inv_scale_x = is_l_model ? 1.0f : (1.0f / scale_factor[0]);
        float inv_scale_y = is_l_model ? 1.0f : (1.0f / scale_factor[1]);
        LOGD("Inverse scale: x=%.4f, y=%.4f (L model: %s)", inv_scale_x, inv_scale_y, is_l_model ? "yes" : "no");

        int passed_count = 0;
        for (int i = 0; i < num_detections; i++) {
            // Format: [class_id, score, x1, y1, x2, y2]
            int class_id = static_cast<int>(output_data[i * 6 + 0]);
            float score = output_data[i * 6 + 1];
            float x1 = output_data[i * 6 + 2];
            float y1 = output_data[i * 6 + 3];
            float x2 = output_data[i * 6 + 4];
            float y2 = output_data[i * 6 + 5];

            if (score >= conf_threshold && class_id >= 0 && class_id < static_cast<int>(DOC_CLASSES.size())) {
                DetectionBox box;
                box.x1 = x1 * inv_scale_x;
                box.y1 = y1 * inv_scale_y;
                box.x2 = x2 * inv_scale_x;
                box.y2 = y2 * inv_scale_y;

                // Clamp coordinates to image bounds
                box.x1 = std::max(0.0f, std::min(box.x1, static_cast<float>(image.cols)));
                box.y1 = std::max(0.0f, std::min(box.y1, static_cast<float>(image.rows)));
                box.x2 = std::max(0.0f, std::min(box.x2, static_cast<float>(image.cols)));
                box.y2 = std::max(0.0f, std::min(box.y2, static_cast<float>(image.rows)));

                box.score = score;
                box.class_id = class_id;
                box.class_name = DOC_CLASSES[class_id];
                results.push_back(box);
                passed_count++;
                LOGD("Passed: class=%d (%s), score=%.4f, box=[%.1f,%.1f,%.1f,%.1f]",
                    class_id, box.class_name.c_str(), score, box.x1, box.y1, box.x2, box.y2);
            }
        }
        LOGD("Detections passed threshold: %d", passed_count);

    } catch (const Ort::Exception& e) {
        (void)e;
    } catch (const cv::Exception& e) {
        (void)e;
    } catch (const std::exception& e) {
        (void)e;
    }

    return results;
}

std::string detectionsToJson(const std::vector<DetectionBox>& detections) {
    std::ostringstream json;
    json << "{\"detections\":[";

    for (size_t i = 0; i < detections.size(); i++) {
        const auto& box = detections[i];
        json << "{";
        json << "\"x1\":" << std::fixed << std::setprecision(2) << box.x1 << ",";
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

    json << "],\"count\":" << detections.size() << "}";
    return json.str();
}
