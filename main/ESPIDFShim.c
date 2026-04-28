#include "BridgingHeader.h"

#include <stdint.h>
#include <string.h>

#include "driver/usb_serial_jtag.h"
#include "esp_err.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_mac.h"
#include "esp_system.h"
#include "esp_now.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "nvs_flash.h"

static QueueHandle_t g_espnow_rx_queue = NULL;

static void espnow_recv_callback(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
    if (g_espnow_rx_queue == NULL || recv_info == NULL || data == NULL || len <= 0) {
        return;
    }

    BaseType_t task_woken = pdFALSE;
    espnow_rx_frame_t frame;
    memset(&frame, 0, sizeof(frame));

    if (len > MAX_ESPNOW_PAYLOAD) {
        len = MAX_ESPNOW_PAYLOAD;
    }

    memcpy(frame.payload, data, (size_t)len);
    frame.payload_len = (uint8_t)len;

    if (recv_info->src_addr != NULL) {
        memcpy(frame.src_addr, recv_info->src_addr, ESP_NOW_ETH_ALEN);
    }

    xQueueSendFromISR(g_espnow_rx_queue, &frame, &task_woken);

    if (task_woken) {
        portYIELD_FROM_ISR();
    }
}

SwiftQueueHandle swift_queue_create(uint32_t item_size, uint32_t queue_length) {
    return (SwiftQueueHandle)xQueueCreate(queue_length, item_size);
}

int32_t swift_queue_receive(SwiftQueueHandle queue, void *buffer, uint32_t ticks_to_wait) {
    return (int32_t)xQueueReceive((QueueHandle_t)queue, buffer, ticks_to_wait);
}

void swift_queue_delete(SwiftQueueHandle queue) {
    vQueueDelete((QueueHandle_t)queue);
}

void swift_task_delay(uint32_t ticks_to_delay) {
    vTaskDelay(ticks_to_delay);
}

uint32_t swift_get_time_ms(void) {
    return (uint32_t)(esp_timer_get_time() / 1000);
}

void swift_register_espnow_callback(void) {
    if (g_espnow_rx_queue == NULL) {
        g_espnow_rx_queue = xQueueCreate(RX_RING_BUFFER_SIZE, sizeof(espnow_rx_frame_t));
        if (g_espnow_rx_queue != NULL) {
            esp_now_register_recv_cb(espnow_recv_callback);
        }
    }
}

SwiftQueueHandle swift_get_espnow_rx_queue(void) {
    return (SwiftQueueHandle)g_espnow_rx_queue;
}


bool add_broadcast_peer(void) {
    const uint8_t broadcast_mac[ESP_NOW_ETH_ALEN] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
    esp_now_peer_info_t peer_info = {0};

    memcpy(peer_info.peer_addr, broadcast_mac, ESP_NOW_ETH_ALEN);
    peer_info.channel = 0; // Use current WiFi channel
    peer_info.ifidx = WIFI_IF_STA;
    peer_info.encrypt = false;

    esp_err_t err = esp_now_add_peer(&peer_info);
    if (err == ESP_ERR_ESPNOW_EXIST) {
        return true; // Peer already exists, treat as success
    }
    return err == ESP_OK;
}

bool swift_radio_stack_init(void) {
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        if (nvs_flash_erase() != ESP_OK) {
            return false;
        }
        err = nvs_flash_init();
    }
    if (err != ESP_OK) {
        return false;
    }

    if (esp_netif_init() != ESP_OK) {
        return false;
    }

    err = esp_event_loop_create_default();
    if (err != ESP_OK && err != ESP_ERR_INVALID_STATE) {
        return false;
    }

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    if (esp_wifi_init(&cfg) != ESP_OK) {
        return false;
    }

    if (esp_wifi_set_mode(WIFI_MODE_STA) != ESP_OK) {
        return false;
    }

    if (esp_wifi_set_ps(WIFI_PS_NONE) != ESP_OK) {
        return false;
    }

    if (esp_wifi_start() != ESP_OK) {
        return false;
    }

    if (esp_now_init() != ESP_OK) {
        return false;
    }

    if (!add_broadcast_peer()) {
        return false;
    }

    swift_register_espnow_callback();
    return true;
}

bool swift_espnow_add_peer(const uint8_t *mac) {
    if (!mac) return false;
    
    esp_now_peer_info_t peer = {0};
    memcpy(peer.peer_addr, mac, ESP_NOW_ETH_ALEN);
    
    peer.channel = 0; // current WiFi channel
    peer.ifidx   = WIFI_IF_STA;
    peer.encrypt = false;

    esp_err_t err = esp_now_add_peer(&peer);
    return (err == ESP_OK || err == ESP_ERR_ESPNOW_EXIST);
}

bool swift_espnow_del_peer(const uint8_t *mac) {
    if (!mac) return false;
    esp_err_t err = esp_now_del_peer(mac);
    return (err == ESP_OK || err == ESP_ERR_ESPNOW_NOT_FOUND);
}

bool swift_espnow_set_pmk(const uint8_t *pmk, uint32_t pmk_len) {
    if (pmk == NULL || pmk_len != ESP_NOW_KEY_LEN) {
        return false;
    }

    return esp_now_set_pmk(pmk) == ESP_OK;
}

bool swift_espnow_send(const uint8_t *mac, const uint8_t *data, uint8_t len) {
    if (mac == NULL || data == NULL || len == 0) {
        return false;
    }

    return esp_now_send(mac, data, len) == ESP_OK;
}

bool swift_get_wifi_sta_mac(uint8_t mac[6]) {
    if (mac == NULL) {
        return false;
    }
    return esp_read_mac(mac, ESP_MAC_WIFI_STA) == ESP_OK;
}

bool swift_get_base_mac(uint8_t mac[6]) {
    if (mac == NULL) {
        return false;
    }
    return esp_efuse_mac_get_default(mac) == ESP_OK;
}

bool swift_usb_serial_init(uint32_t rx_buffer_size, uint32_t tx_buffer_size) {
    usb_serial_jtag_driver_config_t cfg = {
        .rx_buffer_size = rx_buffer_size,
        .tx_buffer_size = tx_buffer_size,
    };

    return usb_serial_jtag_driver_install(&cfg) == ESP_OK;
}

int32_t swift_usb_serial_write(const uint8_t *data, uint32_t len, uint32_t timeout_ms) {
    if (data == NULL || len == 0) {
        return 0;
    }

    return usb_serial_jtag_write_bytes(data, len, timeout_ms);
}

void swift_usb_serial_flush(void) {
    // Note: usb_serial_jtag_tx_flush() is not available in this ESP-IDF version
    // Flushing is handled automatically by the driver
}

void swift_usb_serial_deinit(void) {
    usb_serial_jtag_driver_uninstall();
}

void swift_log_info(const char *message) {
    esp_log_write(ESP_LOG_INFO, LOG_TAG, "%s", message);
}

void swift_log_warn(const char *message) {
    esp_log_write(ESP_LOG_WARN, LOG_TAG, "%s", message);
}

void swift_log_error(const char *message) {
    esp_log_write(ESP_LOG_ERROR, LOG_TAG, "%s", message);
}

void swift_log_debug(const char *message) {
    esp_log_write(ESP_LOG_DEBUG, LOG_TAG, "%s", message);
}

void swift_log_frames_processed(uint32_t frame_count) {
    esp_log_write(ESP_LOG_INFO, LOG_TAG, "Frames processed: %lu\n", frame_count);
}
