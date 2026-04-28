private let PEER_TIMEOUT_MS: UInt32 = 60_000  // 60 seconds

extension Radio {

    /// Ensure a peer exists in the ESP-NOW peer list (C side).
    func ensurePeer(mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        let arr: [UInt8] = [mac.0, mac.1, mac.2, mac.3, mac.4, mac.5]
        arr.withUnsafeBufferPointer { macPtr in
            let ok = swift_espnow_add_peer(macPtr.baseAddress)
            if ok {
                protocolSafeLogDebug("ESP-NOW peer ensured\n")
            } else {
                protocolSafeLogError("Failed to add ESP-NOW peer\n")
            }
        }
    }

    /// Update peer table and refresh lastHeardMs, auto-adding new peers.
    func updatePeerTable(mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        let currentTimeMs = swift_get_time_ms()

        for i in 0..<peers.count {
            if peers[i].isActive, peers[i].mac == mac {
                peers[i].lastHeardMs = currentTimeMs
                return
            }
        }

        // Not found: add into a free slot
        for i in 0..<peers.count {
            if !peers[i].isActive {
                peers[i].mac = mac
                peers[i].lastHeardMs = currentTimeMs
                peers[i].isActive = true
                ensurePeer(mac: mac)
                protocolSafeLogDebug("Added peer\n")
                return
            }
        }

        protocolSafeLogWarn("Peer table full; cannot add new peer\n")
    }

    /// Call periodically (e.g. once per main loop tick) to evict idle peers.
    func pruneIdlePeers() {
        let now = swift_get_time_ms()

        for i in 0..<peers.count where peers[i].isActive {
            let last = peers[i].lastHeardMs
            if now &- last > PEER_TIMEOUT_MS {
                let mac = peers[i].mac
                let arr: [UInt8] = [mac.0, mac.1, mac.2, mac.3, mac.4, mac.5]
                arr.withUnsafeBufferPointer { macPtr in
                    self.sendFrame(to: mac, type: .leave, payload: [])
                    let ok = swift_espnow_del_peer(macPtr.baseAddress)
                    if ok {
                        protocolSafeLogInfo("Removed idle peer \(formatMACAddress(mac))\n")
                    } else {
                        protocolSafeLogWarn("Failed to delete idle peer \(formatMACAddress(mac))\n")
                    }
                }
                peers[i].isActive = false
            }
        }
    }
}
