#import "DocLayoutKitPlugin.h"

extern void initModel(const char* model_path);
extern char* detectLayout(const char* img_path, float conf_threshold);
extern char* detectLayoutFromBytes(const unsigned char* image_data, int width, int height, int channels, float conf_threshold);
extern void freeString(char* str);
extern const char* getVersion(void);

@implementation DocLayoutKitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSLog(@"DocLayoutKit registered with Flutter");
}

+ (void)load {
    NSLog(@"DocLayoutKit: +load method called");

    volatile const char* version = getVersion();
    NSLog(@"DocLayoutKit: Version check completed: %s", version);

    // Force symbols to be retained by referencing them
    // These calls use invalid parameters so they won't actually execute
    if (version == NULL) {
        initModel("/nonexistent");
        detectLayout("/nonexistent", 0.0f);
        detectLayoutFromBytes(NULL, 0, 0, 0, 0.0f);
        freeString(NULL);
    }
    NSLog(@"DocLayoutKit: All symbols retained");
}
@end
