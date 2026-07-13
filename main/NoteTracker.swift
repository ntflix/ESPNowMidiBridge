public struct ActiveNote {
    let sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    let channel: UInt8
    let note: UInt8
    var startedMs: UInt32
    var lastKeepaliveCheckMs: UInt32  // Time of last keepalive timeout check
    var consecutiveMissedKeepalives: UInt32  // Count of consecutive missed keepalives
}

public final class NoteTracker {
    private let stuckNoteTimeoutMs: UInt32  // Timeout for stuck notes (no NOTE_OFF)
    private let keepaliveTimeoutMs: UInt32  // Timeout for each keepalive check
    private let keepaliveMissThreshold: UInt32  // Number of consecutive misses allowed
    private var activeNotes: [ActiveNote] = []

    public init(
        stuckNoteTimeoutMs: UInt32,
        keepaliveTimeoutMs: UInt32,
        keepaliveMissThreshold: UInt32
    ) {
        self.stuckNoteTimeoutMs = stuckNoteTimeoutMs
        self.keepaliveTimeoutMs = keepaliveTimeoutMs
        self.keepaliveMissThreshold = keepaliveMissThreshold
    }

    public func processIncoming(_ event: MIDIEventFrame, currentTimeMs: UInt32) {
        guard stuckNoteTimeoutMs > 0 else { return }

        if isNoteOn(event) {
            addOrRefresh(
                sourceMac: event.sourceMac,
                channel: event.channel,
                note: event.data1,
                currentTimeMs: currentTimeMs
            )
            return
        }

        if isNoteOff(event) {
            remove(sourceMac: event.sourceMac, channel: event.channel, note: event.data1)
        }
    }

    /// Refresh the keepalive timestamp for a note (called when NOTE_KEEPALIVE received)
    public func refreshKeepalive(
        sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        channel: UInt8,
        note: UInt8,
        currentTimeMs: UInt32
    ) {
        for i in 0..<activeNotes.count {
            if isSameKey(activeNotes[i], sourceMac: sourceMac, channel: channel, noteValue: note) {
                // Reset the miss counter when a keepalive is received
                activeNotes[i].consecutiveMissedKeepalives = 0
                activeNotes[i].lastKeepaliveCheckMs = currentTimeMs
                protocolSafeLogDebug(
                    "Keepalive received: src=\(formatMACAddress(sourceMac)) ch=\(channel) note=\(note)\n"
                )
                return
            }
        }
    }

    /// Collect NOTE_OFF for stuck notes (excessive consecutive missed keepalives or stuck timeout)
    public func collectExpiredNoteOffs(currentTimeMs: UInt32) -> [MIDIEventFrame] {
        var noteOffs: [MIDIEventFrame] = []
        var kept: [ActiveNote] = []
        kept.reserveCapacity(activeNotes.count)

        for active in activeNotes {
            var shouldRemove = false
            var reason: String = ""

            // Check stuck note timeout (note never received NOTE_OFF)
            if stuckNoteTimeoutMs > 0 && currentTimeMs &- active.startedMs >= stuckNoteTimeoutMs {
                shouldRemove = true
                reason = "stuck (no NOTE_OFF sent)"
            }
            // Check keepalive timeout and miss threshold
            else if keepaliveTimeoutMs > 0
                && currentTimeMs &- active.lastKeepaliveCheckMs >= keepaliveTimeoutMs
            {
                // Update the miss counter and check threshold
                var updatedNote = active
                updatedNote.consecutiveMissedKeepalives += 1
                updatedNote.lastKeepaliveCheckMs = currentTimeMs

                if updatedNote.consecutiveMissedKeepalives >= keepaliveMissThreshold {
                    shouldRemove = true
                    reason =
                        "keepalive threshold exceeded (\(updatedNote.consecutiveMissedKeepalives) misses)"
                } else {
                    // Keep the note but with incremented miss counter
                    kept.append(updatedNote)
                    protocolSafeLogDebug(
                        "Keepalive miss: src=\(formatMACAddress(active.sourceMac)) ch=\(active.channel) note=\(active.note) misses=\(updatedNote.consecutiveMissedKeepalives)/\(keepaliveMissThreshold)\n"
                    )
                    continue
                }
            }

            if shouldRemove {
                protocolSafeLogWarn(
                    "Auto note-off: src=\(formatMACAddress(active.sourceMac)) ch=\(active.channel) note=\(active.note) reason=\(reason) ageMs=\(currentTimeMs &- active.startedMs)\n"
                )
                noteOffs.append(
                    MIDIEventFrame(
                        sourceMac: active.sourceMac,
                        channel: active.channel,
                        eventType: .noteOff,
                        data1: active.note,
                        data2: 0,
                        sysExData: []
                    )
                )
            } else {
                kept.append(active)
            }
        }

        activeNotes = kept
        return noteOffs
    }

    private func isSameKey(
        _ note: ActiveNote,
        sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        channel: UInt8,
        noteValue: UInt8
    ) -> Bool {
        note.sourceMac == sourceMac && note.channel == channel && note.note == noteValue
    }

    private func addOrRefresh(
        sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        channel: UInt8,
        note: UInt8,
        currentTimeMs: UInt32
    ) {
        for i in 0..<activeNotes.count {
            if isSameKey(activeNotes[i], sourceMac: sourceMac, channel: channel, noteValue: note) {
                activeNotes[i].startedMs = currentTimeMs
                activeNotes[i].lastKeepaliveCheckMs = currentTimeMs
                activeNotes[i].consecutiveMissedKeepalives = 0
                return
            }
        }

        activeNotes.append(
            ActiveNote(
                sourceMac: sourceMac,
                channel: channel,
                note: note,
                startedMs: currentTimeMs,
                lastKeepaliveCheckMs: currentTimeMs,
                consecutiveMissedKeepalives: 0
            )
        )
    }

    private func remove(
        sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        channel: UInt8,
        note: UInt8
    ) {
        var i = 0
        while i < activeNotes.count {
            if isSameKey(activeNotes[i], sourceMac: sourceMac, channel: channel, noteValue: note) {
                activeNotes.remove(at: i)
                return
            }
            i += 1
        }
    }

    private func isNoteOn(_ event: MIDIEventFrame) -> Bool {
        event.eventType == .noteOn && event.data2 > 0
    }

    private func isNoteOff(_ event: MIDIEventFrame) -> Bool {
        if event.eventType == .noteOff { return true }
        if event.eventType == .noteOn && event.data2 == 0 { return true }
        return false
    }
}
