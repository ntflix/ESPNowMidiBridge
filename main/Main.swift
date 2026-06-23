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
    let radio = Radio()
    let translator = Translator()
    let serialTransport = SerialTransport()
    let stuckNoteTimeoutMs = swift_get_stuck_note_timeout_ms()
    let noteTracker = NoteTracker(timeoutMs: stuckNoteTimeoutMs)

    // Store global references for use in callbacks
    setGlobalRadio(radio)
    setGlobalSerialTransport(serialTransport)

    // Initialise Radio
    guard radio.Initialise() else {
        protocolSafeLogError("Radio Initialisation failed\n")
        return
    }

    // Initialise SerialTransport
    guard serialTransport.Initialise() else {
        protocolSafeLogError("SerialTransport Initialisation failed\n")
        return
    }
    gProtocolMode = true

    if stuckNoteTimeoutMs == 0 {
        protocolSafeLogInfo("Stuck note protection disabled\n")
    } else {
        protocolSafeLogInfo("Stuck note timeout: \(stuckNoteTimeoutMs) ms\n")
    }

    // Start radio advertisement
    radio.startAdvertisement()

    protocolSafeLogInfo("All components Initialised\n")
    var frameCount: UInt32 = 0
    var lastLogMs = swift_get_time_ms()

    while true {
        let currentTimeMs = swift_get_time_ms()

        // Check for incoming ESP-NOW frames
        if let frame = radio.pollFrames() {
            protocolSafeLogInfo(
                "RX frame: type=\(frame.messageType) sender=\(formatMACAddress(frame.senderMac)) payloadLen=\(frame.payload.count)\n"
            )
            protocolSafeLogInfo("RX payload hex: \(hexBytes(frame.payload))\n")

            if let midiEvent = translator.translate(frame: frame) {
                protocolSafeLogInfo("Translated MIDIEventFrame: \(midiEvent.describe())\n")
                protocolSafeLogInfo("Translated raw bytes: \(midiEvent.hexBytes())\n")

                if serialTransport.sendFrame(midiEvent) {
                    frameCount += 1
                }

                noteTracker.processIncoming(midiEvent, currentTimeMs: currentTimeMs)
            } else {
                protocolSafeLogWarn("Translator returned nil for frame payload\n")
            }
        }

        // Safety net: release notes that were never followed by Note Off.
        let expiredNoteOffs = noteTracker.collectExpiredNoteOffs(currentTimeMs: currentTimeMs)
        for noteOff in expiredNoteOffs {
            if serialTransport.sendFrame(noteOff) {
                frameCount += 1
            }
        }

        // Send periodic advertisements
        radio.sendAdvertisement(currentTimeMs: currentTimeMs)

        // Log stats periodically (every 10 seconds)
        if currentTimeMs - lastLogMs >= 10000 {
            protocolSafeLogInfo("Frames processed: \(frameCount)\n")
            lastLogMs = currentTimeMs
        }

        // Yield to FreeRTOS scheduler (1 tick = ~10ms)
        swift_task_delay(1)
    }
}
