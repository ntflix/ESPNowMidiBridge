public struct ActiveNote {
    let sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    let channel: UInt8
    let note: UInt8
    var startedMs: UInt32
}

public final class NoteTracker {
    private let timeoutMs: UInt32
    private var activeNotes: [ActiveNote] = []

    public init(timeoutMs: UInt32) {
        self.timeoutMs = timeoutMs
    }

    public func processIncoming(_ event: MIDIEventFrame, currentTimeMs: UInt32) {
        guard timeoutMs > 0 else { return }

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

    public func collectExpiredNoteOffs(currentTimeMs: UInt32) -> [MIDIEventFrame] {
        guard timeoutMs > 0 else { return [] }

        var noteOffs: [MIDIEventFrame] = []
        var kept: [ActiveNote] = []
        kept.reserveCapacity(activeNotes.count)

        for active in activeNotes {
            if currentTimeMs &- active.startedMs >= timeoutMs {
                protocolSafeLogWarn(
                    "Auto note-off: src=\(formatMACAddress(active.sourceMac)) ch=\(active.channel) note=\(active.note) ageMs=\(currentTimeMs &- active.startedMs)\n"
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
                return
            }
        }

        activeNotes.append(
            ActiveNote(
                sourceMac: sourceMac,
                channel: channel,
                note: note,
                startedMs: currentTimeMs
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
