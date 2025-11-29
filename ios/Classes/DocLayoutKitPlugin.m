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
}
@end
