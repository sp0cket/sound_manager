#import "SoundManagerPlugin.h"
#import <sound_manager/sound_manager-Swift.h>

@implementation SoundManagerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftSoundManagerPlugin registerWithRegistrar:registrar];
}
@end
