// Private CoreBluetooth API, tested on macOS 26.4. No restricted entitlements.
// CBClassicManager approach investigated using:
// https://github.com/dchersey/air-defense/blob/main/macos/ControlPanel/Sources/ADBluetooth/ADListeningMode.m
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreAudio/CoreAudio.h>
#import <dlfcn.h>

@interface NSObject (AirPodsClassic)
- (id)initWithQueue:(dispatch_queue_t)queue options:(NSDictionary *)options;
- (void)sendLocalDeviceStateRequest;
- (void)performTCCCheck;
- (BOOL)tccApproved;
- (void)setTccApproved:(BOOL)approved;
- (NSArray *)retrievePairedPeersWithOptions:(NSDictionary *)options;
- (NSString *)name;
- (unsigned char)listeningMode;
- (void)setListeningMode:(unsigned char)mode;
@end

static void fail(NSString *message) {
    fprintf(stderr, "%s\n", message.UTF8String);
    exit(1);
}

static NSString *outputName(void) {
    AudioDeviceID device = 0;
    UInt32 size = sizeof(device);
    AudioObjectPropertyAddress property = {kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, &size, &device))
        fail(@"Impossible de lire la sortie audio.");
    CFStringRef name = NULL;
    size = sizeof(name);
    property.mSelector = kAudioObjectPropertyName;
    if (!device || AudioObjectGetPropertyData(device, &property, 0, NULL, &size, &name) || !name)
        fail(@"Aucune sortie audio disponible.");
    return CFBridgingRelease(name);
}

static NSString *modeName(unsigned char mode) {
    switch (mode) {
        case 1: return @"off";
        case 2: return @"anc";
        case 3: return @"transparency";
        case 4: return @"adaptive";
        default: return @"unknown";
    }
}

@interface AirPodsControl : NSObject <CBCentralManagerDelegate>
@property(nonatomic, strong) CBCentralManager *central;
@property(nonatomic, strong) id classic;
@property(nonatomic, copy) NSString *action;
@property(nonatomic, copy) NSString *targetName;
@property(nonatomic) BOOL started;
@end

@implementation AirPodsControl
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStateUnauthorized)
        fail(@"Autorise le Bluetooth pour Raycast dans Réglages Système > Confidentialité et sécurité > Bluetooth.");
    if (central.state == CBManagerStatePoweredOff) fail(@"Le Bluetooth est désactivé.");
    if (central.state == CBManagerStateUnsupported) fail(@"Bluetooth non pris en charge.");
    if (central.state != CBManagerStatePoweredOn || self.started) return;
    self.started = YES;
    Class cls = NSClassFromString(@"CBClassicManager");
    for (NSString *selector in @[@"initWithQueue:options:", @"sendLocalDeviceStateRequest", @"performTCCCheck",
                                 @"tccApproved", @"setTccApproved:", @"retrievePairedPeersWithOptions:"]) {
        if (![cls instancesRespondToSelector:NSSelectorFromString(selector)])
            fail(@"L'API Bluetooth privée a changé dans cette version de macOS.");
    }
    self.classic = [[cls alloc] initWithQueue:dispatch_get_main_queue() options:nil];
    [self.classic sendLocalDeviceStateRequest];
    [self.classic performTCCCheck];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        // The real CBCentralManager has reached poweredOn through normal TCC.
        // This private manager fails to update its separate in-process flag.
        // This does not alter the system TCC database or grant system permission.
        if (![self.classic tccApproved]) [self.classic setTccApproved:YES];
        void *handle = dlopen("/System/Library/Frameworks/CoreBluetooth.framework/CoreBluetooth", RTLD_LAZY);
        void **symbol = handle ? dlsym(handle, "CBClassicManagerOptionPairedKey") : NULL;
        NSString *key = symbol ? (__bridge NSString *)*symbol : nil;
        NSArray *peers = [self.classic retrievePairedPeersWithOptions:key ? @{key:@YES} : @{}];
        NSMutableArray *matches = [NSMutableArray array];
        for (id peer in peers) if ([[peer name] isEqual:self.targetName]) [matches addObject:peer];
        if (matches.count != 1) fail(@"AirPods introuvables ou nom ambigu. Connecte-les et sélectionne-les comme sortie audio.");
        id peer = matches.firstObject;
        if (![peer respondsToSelector:@selector(listeningMode)] || ![peer respondsToSelector:@selector(setListeningMode:)])
            fail(@"Le contrôle du bruit est indisponible.");
        unsigned char mode = [peer listeningMode];
        if (mode < 1 || mode > 4) fail(@"Mode actuel indisponible. Reconnecte les AirPods.");
        if (![self.action isEqual:@"status"]) {
            if (![outputName() isEqual:self.targetName]) fail(@"La sortie audio a changé pendant la commande.");
            mode = [self.action isEqual:@"adaptive"] ? 4 :
                [self.action isEqual:@"transparency"] ? 3 :
                [self.action isEqual:@"toggle"] && mode == 2 ? 3 : 2;
            [peer setListeningMode:mode];
        }
        // The shell wrapper checks the result in a fresh process, avoiding a
        // false confirmation from this peer object's cached property.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            printf("%s: %s\n", self.targetName.UTF8String, modeName(mode).UTF8String);
            exit(0);
        });
    });
}
@end

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSString *action = argc > 1 ? @(argv[1]) : @"toggle";
        if ([action isEqual:@"--help"]) {
            puts("Usage: airpods-noise-control [toggle|anc|transparency|adaptive|status]");
            return 0;
        }
        if (argc > 2 || ![@[@"toggle", @"anc", @"transparency", @"adaptive", @"status"] containsObject:action]) {
            fprintf(stderr, "Usage: airpods-noise-control [toggle|anc|transparency|adaptive|status]\n");
            return 2;
        }
        AirPodsControl *control = [AirPodsControl new];
        control.action = action;
        control.targetName = outputName();
        // Some ordinary paired speakers report mode 3 too. Never target them.
        if ([control.targetName rangeOfString:@"AirPods" options:NSCaseInsensitiveSearch].location == NSNotFound)
            fail(@"Sélectionne tes AirPods comme sortie audio. Leur nom doit contenir AirPods.");
        control.central = [[CBCentralManager alloc] initWithDelegate:control queue:dispatch_get_main_queue()];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            fail(@"Délai Bluetooth dépassé. Vérifie l'autorisation Bluetooth puis relance la commande.");
        });
        [[NSRunLoop mainRunLoop] run];
    }
}
