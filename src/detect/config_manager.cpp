#include "include/config_manager.h"

ConfigManager& ConfigManager::GetInstance() {
    static ConfigManager instance;
    return instance;
}

void ConfigManager::SetImgPath(const std::string& img_path) {
    IMG_PATH = img_path;
}

void ConfigManager::Init(const std::string& model_path) {
#ifdef _WIN32
    MODEL_PATH = ConvertToWstring(model_path);
#else
    MODEL_PATH = model_path;
#endif
}
