cmake_minimum_required(VERSION 3.29)

set(SWIFT_FLAGS
    "-enable-experimental-feature" "Embedded"
    "-wmo"
    "-Osize"
    "-parse-as-library"
)

set(C_SETTINGS
    "-DCOBS_ONLY"
)

set(LINKER_FLAGS
    "-Xlinker" "--no-entry"
)

# Find Swift compiler
find_program(SWIFT_COMPILER swiftc REQUIRED)

# Get Swift module name (same as component name)
set(COMPONENT_NAME main)
set(SWIFT_MODULE ${COMPONENT_NAME})

# Collect Swift source files
file(GLOB_RECURSE SWIFT_SOURCES "*.swift")

# Compile Swift to object files
set(SWIFT_OBJECT_FILE ${CMAKE_CURRENT_BINARY_DIR}/${SWIFT_MODULE}.o)
set(SWIFT_MODULE_FILE ${CMAKE_CURRENT_BINARY_DIR}/${SWIFT_MODULE}.swiftmodule)

if(NOT CMAKE_SCRIPT_MODE_FILE)
    # Derive the ESP RISC-V toolchain root so Swift can see the same C headers as the C build.
    get_filename_component(RISCV_TOOLCHAIN_BIN_DIR ${CMAKE_C_COMPILER} DIRECTORY)
    get_filename_component(RISCV_TOOLCHAIN_ROOT ${RISCV_TOOLCHAIN_BIN_DIR} DIRECTORY)

    add_custom_command(
        OUTPUT ${SWIFT_OBJECT_FILE}
        COMMAND ${SWIFT_COMPILER}
            -target riscv32-none-none-eabi
            -Xcc -isystem -Xcc ${CMAKE_BINARY_DIR}/config
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/config/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/config/include/freertos
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/config/riscv/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/FreeRTOS-Kernel/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/FreeRTOS-Kernel/portable/riscv/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/FreeRTOS-Kernel/portable/riscv/include/freertos
            -Xcc -isystem -Xcc ${IDF_PATH}/components/freertos/esp_additions/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_libc/platform_include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_common/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_rom/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_rom/esp32c6/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_rom/esp32c6/include/esp32c6
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_rom/esp32c6
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_hw_support/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_hw_support/include/soc
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_hw_support/port/esp32c6/.
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_hw_support/port/esp32c6/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_hw_support/port/esp32c6/private_include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/hal/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_event/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_log/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_netif/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_wifi/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_now/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/driver/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_timer/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/nvs_flash/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/soc/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/soc/esp32c6
            -Xcc -isystem -Xcc ${IDF_PATH}/components/soc/esp32c6/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/soc/esp32c6/register
            -Xcc -isystem -Xcc ${IDF_PATH}/components/riscv/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_system/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_system/port/soc
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_system/port/include/riscv
            -Xcc -isystem -Xcc ${IDF_PATH}/components/esp_system/port/include/private
            -Xcc -isystem -Xcc ${IDF_PATH}/components/heap/include
            -Xcc -isystem -Xcc ${IDF_PATH}/components/heap/tlsf
            -Xcc -isystem -Xcc ${RISCV_TOOLCHAIN_ROOT}/riscv32-esp-elf/include
            -Xcc -isystem -Xcc ${RISCV_TOOLCHAIN_ROOT}/riscv32-esp-elf/sys-include
            -Xcc -isystem -Xcc ${CMAKE_CURRENT_SOURCE_DIR}
            -import-bridging-header ${CMAKE_CURRENT_SOURCE_DIR}/BridgingHeader.h
            ${SWIFT_FLAGS}
            -c ${SWIFT_SOURCES}
            -o ${SWIFT_OBJECT_FILE}
        DEPENDS ${SWIFT_SOURCES} BridgingHeader.h
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(swift_compile ALL DEPENDS ${SWIFT_OBJECT_FILE})
endif()

# Register component with the compiled Swift object file
idf_component_register(
    SRCS ${SWIFT_OBJECT_FILE} "ESPIDFShim.c"
    PRIV_REQUIRES nvs_flash esp_event esp_netif esp_wifi driver esp_timer esp_driver_usb_serial_jtag
    INCLUDE_DIRS "."
    LDFRAGMENTS "swift_sections.lf"
)

if(TARGET swift_compile)
    add_dependencies(${COMPONENT_LIB} swift_compile)
endif()
