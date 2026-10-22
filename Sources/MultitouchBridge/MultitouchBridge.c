#include "MultitouchBridge.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <math.h>
#include <pthread.h>
#include <string.h>

/* Private ABI declarations, cross-checked against the TrackMagic header:
 * https://github.com/calftrail/TrackMagic/blob/master/MultitouchSupport.h
 * Keep raw ABI isolated here. Nothing outside this target depends on it. */
typedef const void *MTDevice;
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    uint32_t state;
    int32_t finger_id, hand_id;
    MTVector normalized;
    float size;
    int32_t reserved1;
    float angle, major_axis, minor_axis;
    MTVector absolute;
    int32_t reserved2, reserved3;
    float density;
} MTRawContact;

_Static_assert(sizeof(MTRawContact) == 96, "Unexpected multitouch ABI stride");
_Static_assert(offsetof(MTRawContact, normalized) == 32, "Unexpected position offset");
_Static_assert(offsetof(MTRawContact, size) == 48, "Unexpected contact size offset");

typedef void (*MTFrameCallback)(MTDevice, MTRawContact *, size_t, double, size_t);
static struct {
    void *library;
    CFArrayRef (*create_list)(void);
    void (*register_callback)(MTDevice, MTFrameCallback);
    void (*unregister_callback)(MTDevice, MTFrameCallback);
    int32_t (*start)(MTDevice, int32_t);
    int32_t (*stop)(MTDevice);
    io_service_t (*get_service)(MTDevice);
    int32_t (*get_device_id)(MTDevice, uint64_t *);
} api;

static pthread_mutex_t callback_lock = PTHREAD_MUTEX_INITIALIZER;
static MTDevice selected_device;
static CFArrayRef device_list;
static bool accepting_frames;
static PDMTFrameCallback client_callback;
static void *client_context;
static PDMTDeviceInfo selected_info;
static uint64_t selected_driver_id;
static CFTypeRef (*copy_hid_event)(CGEventRef);
static uint64_t (*get_sender_id)(CFTypeRef);
static pthread_once_t event_identity_once = PTHREAD_ONCE_INIT;

static void load_event_identity(void) {
    /* Signatures verified in LinearMouse's public source:
     * https://github.com/linearmouse/linearmouse/blob/main/LinearMouse/LinearMouse-Bridging-Header.h
     * These frameworks are also linked by this target; keep missing SPI optional. */
    *(void **)(&copy_hid_event) = dlsym(RTLD_DEFAULT, "CGEventCopyIOHIDEvent");
    *(void **)(&get_sender_id) = dlsym(RTLD_DEFAULT, "IOHIDEventGetSenderID");
}

static uint64_t trackpad_driver_id(MTDevice device) {
    io_service_t service = api.get_service(device);
    io_registry_entry_t parent = IO_OBJECT_NULL;
    uint64_t identifier = 0;
    if (service && IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS) {
        /* Only this immediate, trackpad-specific driver is an accepted alias.
         * Do not accept shared USB/Bluetooth ancestors or other HID siblings. */
        if (IOObjectConformsTo(parent, "AppleMultitouchTrackpadHIDEventDriver")) {
            IORegistryEntryGetRegistryEntryID(parent, &identifier);
        }
        IOObjectRelease(parent);
    }
    return identifier;
}

static PDMTStatus load_framework(void) {
    if (!api.library) {
        api.library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
                            RTLD_LOCAL | RTLD_NOW);
    }
    if (!api.library) return PDMTStatusFrameworkUnavailable;

    /* Never unload: a late framework callback must retain a valid code image. */
#define LOAD(field, symbol) do { \
    *(void **)(&api.field) = dlsym(api.library, symbol); \
    if (!api.field) return PDMTStatusSymbolUnavailable; \
} while (0)
    LOAD(create_list, "MTDeviceCreateList");
    LOAD(register_callback, "MTRegisterContactFrameCallback");
    LOAD(unregister_callback, "MTUnregisterContactFrameCallback");
    LOAD(start, "MTDeviceStart");
    LOAD(stop, "MTDeviceStop");
    LOAD(get_service, "MTDeviceGetService");
    LOAD(get_device_id, "MTDeviceGetDeviceID");
#undef LOAD
    return PDMTStatusOK;
}

static CFTypeRef property(io_service_t service, CFStringRef key) {
    return IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
}

static bool inspect_device(MTDevice device, PDMTDeviceInfo *info) {
    io_service_t service = api.get_service(device);
    if (!service) return false;

    /* Trackpads expose this driver property. This also excludes Magic Mouse
     * and Touch Bar without guessing private hardware family numbers. */
    CFTypeRef acceleration = property(service, CFSTR("HIDPointerAccelerationType"));
    bool is_trackpad = acceleration && CFGetTypeID(acceleration) == CFStringGetTypeID()
        && CFEqual(acceleration, CFSTR("HIDTrackpadAcceleration"));
    if (acceleration) CFRelease(acceleration);
    if (!is_trackpad) return false;

    memset(info, 0, sizeof(*info));
    if (IORegistryEntryGetRegistryEntryID(service, &info->registry_id) != KERN_SUCCESS) return false;
    (void)api.get_device_id(device, &info->multitouch_id);

    CFTypeRef builtin = property(service, CFSTR("MT Built-In"));
    /* An unknown built-in state is not safe to treat as an external device. */
    if (!builtin || CFGetTypeID(builtin) != CFBooleanGetTypeID()) {
        if (builtin) CFRelease(builtin);
        return false;
    }
    info->is_builtin = CFBooleanGetValue((CFBooleanRef)builtin);
    CFRelease(builtin);

    CFTypeRef product = property(service, CFSTR("Product"));
    if (product && CFGetTypeID(product) == CFStringGetTypeID()) {
        CFStringGetCString((CFStringRef)product, info->name, sizeof(info->name), kCFStringEncodingUTF8);
    }
    if (product) CFRelease(product);
    if (!info->name[0]) strcpy(info->name, "Trackpad");
    return true;
}

static void receive_frame(MTDevice device, MTRawContact *raw, size_t count,
                          double timestamp, size_t frame) {
    (void)frame;
    /* Reject ABI-corrupt frames; never silently turn them into a release. */
    if (count > 32 || (count > 0 && !raw) || !isfinite(timestamp)) return;
    PDMTContact contacts[32];
    for (size_t index = 0; index < count; index++) {
        const MTRawContact *touch = &raw[index];
        if (!isfinite(touch->normalized.position.x) || !isfinite(touch->normalized.position.y)
            || !isfinite(touch->size) || !isfinite(touch->major_axis) || !isfinite(touch->minor_axis)
            || touch->state > 7) return;
        contacts[index] = (PDMTContact) {
            .identifier = touch->identifier,
            .state = touch->state,
            .x = touch->normalized.position.x,
            .y = touch->normalized.position.y,
            .size = touch->size,
            .major_axis = touch->major_axis,
            .minor_axis = touch->minor_axis
        };
    }

    pthread_mutex_lock(&callback_lock);
    if (accepting_frames && device == selected_device && client_callback) {
        /* Keeping the lock through delivery makes stop's callback barrier real.
         * Client must copy data quickly and schedule UI work asynchronously. */
        client_callback(selected_info.registry_id, contacts, count, timestamp, client_context);
    }
    pthread_mutex_unlock(&callback_lock);
}

PDMTStatus pd_mt_start(bool include_builtin, PDMTFrameCallback callback, void *context) {
    if (!callback) return PDMTStatusInvalidArgument;
    pd_mt_stop();
    PDMTStatus status = load_framework();
    if (status != PDMTStatusOK) return status;
    pthread_once(&event_identity_once, load_event_identity);
    CFArrayRef list = api.create_list();
    if (!list) return PDMTStatusNoTrackpad;

    MTDevice chosen = NULL;
    PDMTDeviceInfo chosen_info = {0};
    int32_t available = 0;
    for (CFIndex index = 0; index < CFArrayGetCount(list); index++) {
        MTDevice device = CFArrayGetValueAtIndex(list, index);
        PDMTDeviceInfo info;
        if (!device || !inspect_device(device, &info)) continue;
        available++;
        if (info.is_builtin && !include_builtin) continue;
        if (!chosen || (chosen_info.is_builtin && !info.is_builtin)) {
            chosen = device;
            chosen_info = info;
        }
    }
    if (!chosen) {
        CFRelease(list);
        return PDMTStatusNoTrackpad;
    }
    chosen_info.available_trackpads = available;
    uint64_t driver_id = trackpad_driver_id(chosen);

    pthread_mutex_lock(&callback_lock);
    device_list = list; /* Keep every handle alive until unregister + stop. */
    selected_device = chosen;
    selected_info = chosen_info;
    selected_driver_id = driver_id;
    client_callback = callback;
    client_context = context;
    accepting_frames = false;
    pthread_mutex_unlock(&callback_lock);

    api.register_callback(chosen, receive_frame);
    if (api.start(chosen, 0) != 0) {
        pd_mt_stop();
        return PDMTStatusStartFailed;
    }
    pthread_mutex_lock(&callback_lock);
    accepting_frames = true;
    pthread_mutex_unlock(&callback_lock);
    return PDMTStatusOK;
}

void pd_mt_stop(void) {
    pthread_mutex_lock(&callback_lock);
    accepting_frames = false;
    client_callback = NULL;
    client_context = NULL;
    MTDevice device = selected_device;
    CFArrayRef list = device_list;
    selected_device = NULL;
    device_list = NULL;
    memset(&selected_info, 0, sizeof(selected_info));
    selected_driver_id = 0;
    pthread_mutex_unlock(&callback_lock);

    /* Framework calls can themselves wait for callbacks. Never hold our lock. */
    if (device) {
        api.unregister_callback(device, receive_frame);
        api.stop(device);
    }
    if (list) CFRelease(list);
}

bool pd_mt_get_info(PDMTDeviceInfo *info) {
    if (!info) return false;
    pthread_mutex_lock(&callback_lock);
    *info = selected_info;
    bool running = accepting_frames;
    pthread_mutex_unlock(&callback_lock);
    return running;
}

const char *pd_mt_status_message(PDMTStatus status) {
    switch (status) {
        case PDMTStatusOK: return "Trackpad connected";
        case PDMTStatusFrameworkUnavailable: return "Multitouch framework unavailable";
        case PDMTStatusSymbolUnavailable: return "Multitouch API unavailable on this macOS version";
        case PDMTStatusNoTrackpad: return "No eligible trackpad connected";
        case PDMTStatusStartFailed: return "Trackpad monitoring could not start";
        case PDMTStatusInvalidArgument: return "Missing frame callback";
    }
    return "Unknown trackpad error";
}

bool pd_mt_event_identity_supported(void) {
    return copy_hid_event != NULL && get_sender_id != NULL;
}

uint64_t pd_mt_event_sender_id(CGEventRef event) {
    if (!event || !pd_mt_event_identity_supported()) return 0;
    CGEventType type = CGEventGetType(event);
    /* Copying HID payloads for keyboard events can be unsafe on some versions.
     * Restrict inspection to pointer presses, releases and their drags. */
    if (type != kCGEventLeftMouseDown && type != kCGEventLeftMouseUp
        && type != kCGEventRightMouseDown && type != kCGEventRightMouseUp
        && type != kCGEventLeftMouseDragged && type != kCGEventRightMouseDragged) return 0;
    CFTypeRef hid_event = copy_hid_event(event);
    if (!hid_event) return 0;
    uint64_t sender = get_sender_id(hid_event);
    CFRelease(hid_event);
    return sender;
}

bool pd_mt_event_matches_device(CGEventRef event) {
    uint64_t sender = pd_mt_event_sender_id(event);
    if (!sender) return false;
    pthread_mutex_lock(&callback_lock);
    bool matches = accepting_frames
        && (sender == selected_info.registry_id || sender == selected_driver_id);
    pthread_mutex_unlock(&callback_lock);
    return matches;
}
