#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(RoroNative, NSObject)
RCT_EXTERN_METHOD(prepare:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(execute:(NSString *)command payload:(NSDictionary *)payload resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
@end
