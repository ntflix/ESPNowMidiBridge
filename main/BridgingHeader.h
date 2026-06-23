#ifndef BRIDGING_HEADER_H
#define BRIDGING_HEADER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// ESP-IDF C API declarations for Swift bridging
#ifdef __cplusplus
extern "C" {
#endif

// Keep low-level ESP-IDF APIs inside the C shim implementation.
// Swift imports only the shim functions declared below.

// (Low-level ESP-IDF types and APIs are used inside the C shim implementation.)
// Swift should only see the lightweight shim APIs declared below.

// FreeRTOS types (may need shim)
// TaskHandle_t is defined in FreeRTOS headers, don't forward declare
typedef struct xQueueHandle xQueueHandle;
typedef struct xSemaphoreHandle xSemaphoreHandle;

#ifdef __cplusplus
} // extern "C"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define LOG_TAG "ESPNOWMIDIBridge"
#define ESP_NOW_ETH_ALEN 6
#define MAX_PEERS 10
#define RX_RING_BUFFER_SIZE 32
#define MAX_ESPNOW_PAYLOAD 250

typedef uintptr_t SwiftQueueHandle;

typedef struct {
  uint8_t payload[MAX_ESPNOW_PAYLOAD];
  uint8_t payload_len;
  uint8_t src_addr[ESP_NOW_ETH_ALEN];
} espnow_rx_frame_t;

SwiftQueueHandle swift_queue_create(uint32_t item_size, uint32_t queue_length);
int32_t swift_queue_receive(SwiftQueueHandle queue, void *buffer,
                            uint32_t ticks_to_wait);
void swift_queue_delete(SwiftQueueHandle queue);

void swift_task_delay(uint32_t ticks_to_delay);
uint32_t swift_get_time_ms(void);
uint32_t swift_get_stuck_note_timeout_ms(void);

void swift_register_espnow_callback(void);
SwiftQueueHandle swift_get_espnow_rx_queue(void);

bool swift_radio_stack_init(void);
bool swift_espnow_add_peer(const uint8_t *mac);
bool swift_espnow_del_peer(const uint8_t *mac);

bool swift_espnow_set_pmk(const uint8_t *pmk, uint32_t pmk_len);
bool swift_espnow_send(const uint8_t *mac, const uint8_t *data, uint8_t len);

bool swift_get_wifi_sta_mac(uint8_t mac[6]);
bool swift_get_base_mac(uint8_t mac[6]);

bool swift_usb_serial_init(uint32_t rx_buffer_size, uint32_t tx_buffer_size);
int32_t swift_usb_serial_write(const uint8_t *data, uint32_t len,
                               uint32_t timeout_ms);
void swift_usb_serial_flush(void);
void swift_usb_serial_deinit(void);

void swift_log_info(const char *message);
void swift_log_warn(const char *message);
void swift_log_error(const char *message);
void swift_log_debug(const char *message);
void swift_log_frames_processed(uint32_t frame_count);

#ifdef __cplusplus
}
#endif

#endif
