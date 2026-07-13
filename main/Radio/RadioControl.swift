extension Radio {

    /// Build and send a framed ESPNOW packet (MAGIC + TYPE + payload)
    func sendFrame(
        to mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        type: ESPNOWMessageType,
        payload: [UInt8]
    ) throws(RadioError) {
        var frame: [UInt8] = []
        frame.append(FrameConstants.MAGIC_BYTE_0)
        frame.append(FrameConstants.MAGIC_BYTE_1)
        frame.append(FrameConstants.MAGIC_BYTE_2)
        frame.append(FrameConstants.MAGIC_BYTE_3)
        frame.append(type.rawValue)
        frame.append(contentsOf: payload)

        let macArray = [mac.0, mac.1, mac.2, mac.3, mac.4, mac.5]
        macArray.withUnsafeBufferPointer { macPtr in
            frame.withUnsafeBufferPointer { dataPtr in
                let ok = swift_espnow_send(
                    macPtr.baseAddress,
                    dataPtr.baseAddress,
                    UInt8(frame.count)
                )
                if ok {
                    protocolSafeLogInfo("Sent frame to \(formatMACAddress(mac))\n")
                } else {
                    protocolSafeLogError("Failed to send frame to \(formatMACAddress(mac))\n")
                }
            }
        }
    }

    /// Handle control messages (JOIN/LEAVE/JOINED) inline
    func handleControlMessage(
        type: ESPNOWMessageType,
        from srcMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        payload: [UInt8]
    ) {
        switch type {
        case .join:
            let roomId = payload.first ?? 0
            protocolSafeLogInfo(
                "Received JOIN from \(formatMACAddress(srcMac)) roomId=\(roomId)\n"
            )

            // Ensure peer in ESP-NOW peer list and update our logical table
            ensurePeer(mac: srcMac)

            // Send JOINED ack; echo room id
            try? sendFrame(to: srcMac, type: .joinedAck, payload: [roomId])

        case .leave:
            protocolSafeLogInfo("Received LEAVE from \(formatMACAddress(srcMac))\n")
        // Optional: proactively mark inactive and delete at C level
        // (pruneIdlePeers will also clean up after timeout)

        case .advertisement, .data, .joinedAck, .noteKeepalive:
            // Data or non-control messages are handled at higher layers
            break

        case .instruments:
            protocolSafeLogInfo("Received INSTRUMENTS from \(formatMACAddress(srcMac))\n")
        // Handle instruments message if needed
        }
    }

    /// Tuple → bytes helper
    func extractPayloadBytes(
        from tuple: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ),
        count: Int
    ) -> [UInt8] {
        var result: [UInt8] = []
        withUnsafeBytes(of: tuple) { buffer in
            for i in 0..<min(count, 250) {
                result.append(buffer[i])
            }
        }
        return result
    }
}
