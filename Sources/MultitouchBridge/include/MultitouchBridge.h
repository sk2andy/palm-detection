#ifndef MULTITOUCH_BRIDGE_H
#define MULTITOUCH_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum {
    PDMTStatusOK = 0,
    PDMTStatusFrameworkUnavailable = 1,
    PDMTStatusSymbolUnavailable = 2,
    PDMTStatusNoTrackpad = 3,
    PDMTStatusStartFailed = 4,
    PDMTStatusInvalidArgument = 5
} PDMTStatus;

typedef struct {
    int32_t identifier;
    uint32_t state;
    float x;
    float y;
    float size;
    float major_axis;
    float minor_axis;
} PDMTContact;

typedef struct {
    uint64_t registry_id;
    uint64_t multitouch_id;
    bool is_builtin;
    int32_t available_trackpads;
    char name[128];
} PDMTDeviceInfo;

/* Contacts are copied from private framework memory, valid only during callback.
 * Coordinates are normalized, with (0,0) at the trackpad's bottom-left.
 * Callback runs on a framework thread. Do not call start/stop from it. */
typedef void (*PDMTFrameCallback)(uint64_t device_id,
                                const PDMTContact *contacts,
                                size_t count,
                                double timestamp,
                                void *context);

/* Call start/stop on one serialized owner thread. Selects one external trackpad,
 * or a built-in trackpad only when explicitly allowed and no external exists. */
PDMTStatus pd_mt_start(bool include_builtin, PDMTFrameCallback callback, void *context);
/* Waits for an in-flight client callback, then prevents further delivery. */
void pd_mt_stop(void);
/* Thread-safe snapshot. Returns false when monitoring is stopped. */
bool pd_mt_get_info(PDMTDeviceInfo *info);
const char *pd_mt_status_message(PDMTStatus status);
/* Active selected driver's native tap-to-click setting: -1 unknown, 0 off, 1 on.
 * Call on the serialized owner thread, never inside a frame callback. */
int pd_mt_native_tap_setting(void);

#endif
