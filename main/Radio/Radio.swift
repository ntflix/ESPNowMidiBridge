public class Radio {

    // Peer table (statically allocated)
    var peers: [PeerEntry] = Array(
        repeating: PeerEntry(
            mac: (0, 0, 0, 0, 0, 0),
            lastHeardMs: 0,
            isActive: false
        ),
        count: 10
    )

    // Queue handle for ESP-NOW frames
    private var rxQueueHandle: UInt = 0

    // Stats
    private var droppedFrameCount: UInt32 = 0
    private var lastAdvertisementMs: UInt32 = 0

    public init() {
        // Initialised in app_main
    }

    /// Initialise WiFi and ESP-NOW
    public func Initialise() -> Bool {
        if !swift_radio_stack_init() {
            protocolSafeLogError("Radio stack init failed\n")
            return false
        }

        swift_register_espnow_callback()
        rxQueueHandle = swift_get_espnow_rx_queue()

        protocolSafeLogInfo("Radio Initialised\n")
        return true
    }

    /// Start the radio advertisement task
    public func startAdvertisement() {
        lastAdvertisementMs = swift_get_time_ms()
    }

    /// Call this from your main loop to prune idle peers.
    public func maintain() {
        pruneIdlePeers()
    }

    /// Process incoming frames from the queue
    public func pollFrames() -> ESPNOWFrame? {
        guard rxQueueHandle != 0 else { return nil }

        var frame = EspnowRxFrame(
            payload: (
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0)
            ),
            payloadLen: 0,
            srcAddr: (0, 0, 0, 0, 0, 0)
        )

        let result = swift_queue_receive(rxQueueHandle, &frame, 0)
        if result != 1 {
            if result != 0 {
                droppedFrameCount &+= 1
                protocolSafeLogError("Dropped frame: queue receive failed, result=\(result)\n")
            }
            return nil
        }

        let payloadArray = extractPayloadBytes(
            from: frame.payload,
            count: Int(frame.payloadLen)
        )

        protocolSafeLogDebug(
            "Received frame from MAC: \(formatMACAddress(frame.srcAddr)) "
                + "len=\(frame.payloadLen)\n"
        )

        // Validate magic bytes
        guard payloadArray.count >= 5 else { return nil }
        guard payloadArray[0] == FrameConstants.MAGIC_BYTE_0,
            payloadArray[1] == FrameConstants.MAGIC_BYTE_1,
            payloadArray[2] == FrameConstants.MAGIC_BYTE_2,
            payloadArray[3] == FrameConstants.MAGIC_BYTE_3
        else {
            return nil
        }

        let messageTypeByte = payloadArray[4]
        let payloadData = Array(payloadArray.dropFirst(5))

        guard let msgType = ESPNOWMessageType(rawValue: messageTypeByte) else {
            return nil
        }

        // Update peer table and ensure ESP-NOW peer exists
        updatePeerTable(mac: frame.srcAddr)

        // Handle JOIN/LEAVE/JOINED control messages
        handleControlMessage(
            type: msgType,
            from: frame.srcAddr,
            payload: payloadData
        )

        return ESPNOWFrame(
            senderMac: frame.srcAddr,
            messageType: msgType,
            payload: payloadData
        )
    }

    /// Broadcast advertisement frame
    public func sendAdvertisement(currentTimeMs: UInt32) {
        if (currentTimeMs - lastAdvertisementMs) < FrameConstants.ADVERTISEMENT_INTERVAL_MS {
            protocolSafeLogDebug("Skipping advertisement; interval not reached\n")
            return
        }

        self.maintain()  // Prune idle peers before advertising

        lastAdvertisementMs = currentTimeMs

        var adFrame: [UInt8] = []
        adFrame.append(FrameConstants.MAGIC_BYTE_0)
        adFrame.append(FrameConstants.MAGIC_BYTE_1)
        adFrame.append(FrameConstants.MAGIC_BYTE_2)
        adFrame.append(FrameConstants.MAGIC_BYTE_3)
        adFrame.append(ESPNOWMessageType.advertisement.rawValue)
        adFrame.append(FrameConstants.ROOM_ID)

        let broadcastMac: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        broadcastMac.withUnsafeBufferPointer { macPtr in
            adFrame.withUnsafeBufferPointer { dataPtr in
                let ok = swift_espnow_send(
                    macPtr.baseAddress,
                    dataPtr.baseAddress,
                    UInt8(adFrame.count)
                )
                if ok {
                    protocolSafeLogInfo("Sent advertisement frame\n")
                } else {
                    protocolSafeLogError("Failed to send advertisement frame\n")
                }
            }
        }

        let activePeers = peers.filter { $0.isActive }.count
        protocolSafeLogInfo("Peers: \(activePeers)\n")
    }
}

// MARK: - Global instance

private var gRadio: Radio? = nil

func setGlobalRadio(_ radio: Radio) {
    gRadio = radio
}

func getGlobalRadio() -> Radio? {
    return gRadio
}
