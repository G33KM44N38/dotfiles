#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>

static void fail(NSString *message, int status) {
    fprintf(stderr, "%s\n", message.UTF8String);
    exit(status);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fail(@"Usage: bluetooth-connect ADRESSE_BLUETOOTH", 64);
        }

        NSString *address = [NSString stringWithUTF8String:argv[1]];
        IOBluetoothDevice *device = [IOBluetoothDevice deviceWithAddressString:address];
        if (device == nil) {
            fail([NSString stringWithFormat:@"Appareil Bluetooth introuvable : %@", address], 1);
        }

        NSString *name = device.name ?: address;
        if (device.isConnected) {
            printf("%s est déjà connecté.\n", name.UTF8String);
            return 0;
        }

        IOReturn result = [device openConnection];
        if (result != kIOReturnSuccess) {
            fail([NSString stringWithFormat:@"Connexion à %@ impossible (erreur 0x%08x).", name, result], 1);
        }

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10.0];
        while (!device.isConnected && deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }

        if (!device.isConnected) {
            fail([NSString stringWithFormat:@"%@ n'a pas confirmé la connexion après 10 secondes.", name], 1);
        }

        printf("%s reconnecté au Mac.\n", name.UTF8String);
        return 0;
    }
}
