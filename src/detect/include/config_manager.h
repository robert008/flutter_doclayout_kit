#ifndef CONFIG_MANAGER_H
#define CONFIG_MANAGER_H

#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

class ConfigManager {
public:
    static ConfigManager& GetInstance();

    void Init(const std::string& model_path);
    void SetImgPath(const std::string& img_path);

    std::string IMG_PATH;

#ifdef _WIN32
    std::wstring MODEL_PATH;

    static std::wstring ConvertToWstring(const std::string& str) {
        int len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
        if (len <= 0) return L"";
        std::wstring wstr(len - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wstr[0], len);
        return wstr;
    }
#else
    std::string MODEL_PATH;
#endif

private:
    ConfigManager() = default;
    ConfigManager(const ConfigManager&) = delete;
    ConfigManager& operator=(const ConfigManager&) = delete;
};

#endif  // CONFIG_MANAGER_H
