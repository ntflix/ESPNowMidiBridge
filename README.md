# ESPNOWMIDIBridge: ESP32-C6 Embedded Swift Firmware

This is the firmware component for the ESP-NOW to ALSA MIDI bridge. Runs great on an ESP32-C6 microcontroller.

## Overview

The ESPNOWMIDIBridge receives ESP-NOW frames from wireless sensor/controller nodes, translates them to MIDI events according to a configurable mapping table, and forwards the events to a host running ALSAMIDISource over USB CDC-ACM. ALSAMIDISource then injects these MIDI events into the ALSA sequencer.

### Architecture

The firmware is organized into three loosely coupled components:

- **Radio**: ESP-NOW initialization, peer management, frame reception
- **Translator**: Mapping ESP-NOW payloads to MIDI events
- **SerialTransport**: COBS encoding and USB CDC-ACM transmission

## Configuration

### Compile-Time Configuration

Edit [main/Kconfig.projbuild](main/Kconfig.projbuild) or use `idf.py menuconfig`:

- **Room ID**: Bridge identifier for peer discovery (default: 0x01)
- **WiFi Channel**: ESP-NOW channel (default: 1)
- **Advertisement Interval**: How often bridge announces itself (default: 5000 ms)
- **Peer Timeout**: When to remove inactive peers (default: 30000 ms)
- **Max Peers**: Peer table size (default: 10)

### Mapping Rules

Edit [main/Translator.swift](main/Translator.swift) in the `MappingConfig.rules` array to define how ESP-NOW payloads map to MIDI events.

Each rule specifies:

- Payload byte(s) to match (offset, mask, expected value)
- Optional sender MAC filter
- Target MIDI channel and event type
- How to derive MIDI data bytes (from payload, MAC, or fixed literals)
- Optional SysEx payload mapping

Example mapping from payload byte 0 == 0x10 to Note On:

```swift
MappingRule(
    matchOffset: 0,
    matchMask: 0xFF,
    matchValue: 0x10,
    senderMacFilter: nil,
    midiChannel: 0,
    midiEventType: .noteOn,
    data1Source: .payloadByte(1),     // Note number
    data2Source: .payloadByte(2),     // Velocity
    sysExPayloadStart: nil,
    sysExPayloadLen: nil
)
```

## Wire Protocol

The bridge communicates with the host using COBS-framed MIDI event frames over USB CDC-ACM at 921600 baud.

### Frame Structure

```
[COBS-encoded MIDIEventFrame] 0x00
```

Each frame contains:

- Sender MAC address (6 bytes)
- MIDI channel (1 byte)
- MIDI event type (1 byte)
- Data byte 1 (1 byte)
- Data byte 2 (1 byte)
- SysEx length and data (variable)

## Testing

The firmware can be tested using the [Tildagon MIDI Controller](https://github.com/ntflix/TildagonMIDIController).

See the ALSAMIDISource package for host-side usage.
