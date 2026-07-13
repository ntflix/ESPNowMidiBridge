// MARK: - Application Main Entry Point
/// This is the entry point called by ESP-IDF bootloader
/// Using @_cdecl to generate a C-compatible symbol
@_cdecl("app_main")
func app_main() {
    protocolSafeLogInfo("ESPNOWMIDIBridge starting\n")

    let macAddress = formatMACAddress(readBaseMAC() ?? [0, 0, 0, 0, 0, 0])
    protocolSafeLogInfo("Base MAC Address: \(macAddress)\n")
    let wifiMacAddress = formatMACAddress(readWiFiMAC() ?? [0, 0, 0, 0, 0, 0])
    protocolSafeLogInfo("WiFi MAC Address: \(wifiMacAddress)\n")

    // Initialise components
    guard let radio = try? Radio() else {
        protocolSafeLogError("Radio Initialisation failed\n")
        return
    }
    let translator = Translator()
    let serialTransport = SerialTransport()
    let stuckNoteTimeoutMs = swift_get_stuck_note_timeout_ms()
    let keepaliveTimeoutMs = swift_get_note_keepalive_interval_ms()
    let keepaliveMissThreshold = swift_get_keepalive_miss_threshold()
    let noteTracker = NoteTracker(
        stuckNoteTimeoutMs: stuckNoteTimeoutMs,
        keepaliveTimeoutMs: keepaliveTimeoutMs,
        keepaliveMissThreshold: keepaliveMissThreshold
    )

    // Initialise SerialTransport
    guard serialTransport.initialise() else {
        protocolSafeLogError("SerialTransport Initialisation failed\n")
        return
    }

    // Log configuration
    protocolSafeLogInfo("Stuck note timeout: \(stuckNoteTimeoutMs)ms\n")
    if keepaliveTimeoutMs > 0 {
        protocolSafeLogInfo(
            "Keepalive timeout: \(keepaliveTimeoutMs)ms, miss threshold: \(keepaliveMissThreshold)\n"
        )
    } else {
        protocolSafeLogInfo("Keepalive monitoring disabled\n")
    }

    // Start radio advertisement
    radio.startAdvertisement()

    protocolSafeLogInfo("All components Initialised\n")

    while true {
        let currentTimeMs = swift_get_time_ms()

        // Check for incoming ESP-NOW frames
        if let frame = radio.pollFrames() {
            protocolSafeLogInfo(
                "RX frame: type=\(frame.messageType) sender=\(formatMACAddress(frame.senderMac)) payloadLen=\(frame.payload.count)\n"
            )
            protocolSafeLogInfo("RX payload hex: \(hexBytes(frame.payload))\n")

            // Handle NOTE_KEEPALIVE frames
            if frame.messageType == .noteKeepalive {
                if let (channel, note) = translator.extractKeepalive(frame: frame) {
                    noteTracker.refreshKeepalive(
                        sourceMac: frame.senderMac,
                        channel: channel,
                        note: note,
                        currentTimeMs: currentTimeMs
                    )
                }
            } else if let midiEvent = translator.translate(frame: frame) {
                protocolSafeLogInfo("Translated MIDIEventFrame: \(midiEvent.describe())\n")
                protocolSafeLogInfo("Translated raw bytes: \(midiEvent.hexBytes())\n")
                try? serialTransport.sendFrame(midiEvent)
                noteTracker.processIncoming(midiEvent, currentTimeMs: currentTimeMs)
            } else {
                protocolSafeLogWarn("Translator returned nil for frame payload\n")
            }
        }

        // Release notes that were never followed by Note Off or keepalive timeout
        let expiredNoteOffs = noteTracker.collectExpiredNoteOffs(currentTimeMs: currentTimeMs)
        for noteOff in expiredNoteOffs {
            try? serialTransport.sendFrame(noteOff)
        }

        // Send periodic advertisements
        if currentTimeMs - radio.lastAdvertisementMs >= 1000 {
            radio.sendAdvertisement(currentTimeMs: currentTimeMs)
        }

        // Yield to FreeRTOS scheduler (1 tick = ~10ms)
        swift_task_delay(1)
    }
}
