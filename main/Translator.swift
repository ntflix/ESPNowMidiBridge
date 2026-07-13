// MARK: - Mapping Rule Value Source
/// Where a MIDI data byte comes from
public enum ValueSource {
    case literal(UInt8)  // Fixed value
    case payloadByte(Int)  // Byte at offset in payload
    case payloadNibble(Int, nibble: Bool)  // Nibble (high=false, low=true)
    case senderMacByte(Int)  // Byte from sender MAC
    case unused  // Not used
}

// MARK: - Mapping Rule
/// A single mapping rule from ESP-NOW payload to MIDI event
public struct MappingRule {
    // Match criteria
    let matchOffset: Int
    let matchMask: UInt8
    let matchValue: UInt8
    let senderMacFilter: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)?  // Optional

    // Target MIDI
    let midiChannel: UInt8  // 0-15
    let midiEventType: MidiEventType

    // Data byte derivation
    let data1Source: ValueSource
    let data2Source: ValueSource

    // SysEx payload (if applicable)
    let sysExPayloadStart: Int?  // Offset into payload for SysEx data
    let sysExPayloadLen: Int?  // Length of SysEx data

    /// Check if this rule matches the given frame
    func matches(frame: ESPNOWFrame) -> Bool {
        // Check payload match criteria
        guard frame.payload.count > matchOffset else { return false }
        if (frame.payload[matchOffset] & matchMask) != matchValue {
            return false
        }

        // Check sender MAC filter if present
        if let filter = senderMacFilter {
            if frame.senderMac != filter {
                return false
            }
        }

        return true
    }

    /// Apply this rule to produce a MIDI event frame
    func apply(frame: ESPNOWFrame) -> MIDIEventFrame {
        let data1 = deriveValue(source: data1Source, frame: frame)
        let data2 = deriveValue(source: data2Source, frame: frame)

        var sysExData: [UInt8] = []
        if let start = sysExPayloadStart, let len = sysExPayloadLen {
            let end = min(start + len, frame.payload.count)
            if start < frame.payload.count {
                sysExData = Array(frame.payload[start..<end])
            }
        }

        return MIDIEventFrame(
            sourceMac: frame.senderMac,
            channel: midiChannel,
            eventType: midiEventType,
            data1: data1,
            data2: data2,
            sysExData: sysExData
        )
    }

    /// Derive a single data byte value
    private func deriveValue(source: ValueSource, frame: ESPNOWFrame) -> UInt8 {
        switch source {
        case .literal(let value):
            return value

        case .payloadByte(let offset):
            guard offset < frame.payload.count else { return 0 }
            return frame.payload[offset]

        case .payloadNibble(let offset, let isLow):
            guard offset < frame.payload.count else { return 0 }
            let nibble =
                isLow ? (frame.payload[offset] & 0x0F) : ((frame.payload[offset] >> 4) & 0x0F)
            return nibble

        case .senderMacByte(let macOffset):
            switch macOffset {
            case 0: return frame.senderMac.0
            case 1: return frame.senderMac.1
            case 2: return frame.senderMac.2
            case 3: return frame.senderMac.3
            case 4: return frame.senderMac.4
            case 5: return frame.senderMac.5
            default: return 0
            }

        case .unused:
            return 0
        }
    }
}

// MARK: - Translator Component
public class Translator {
    public init() {}

    /// Process an incoming frame and produce a MIDI event if matched
    /// For NOTE_KEEPALIVE, returns nil (caller handles via dedicated method)
    public func translate(frame: ESPNOWFrame) -> MIDIEventFrame? {
        // Only process DATA frames
        guard frame.messageType == .data else {
            protocolSafeLogWarn("Translator ignoring non-DATA frame\n")
            return nil
        }

        protocolSafeLogInfo("Translator input payload: \(frame.payload)\n")

        do {
            let event = try translateFixedMIDIEvent(frame: frame)
            protocolSafeLogInfo("Translator parsed fixed MIDI event: \(event.describe())\n")
            return event
        } catch let error {
            protocolSafeLogWarn("Translator fixed-format parse failed: \(error)\n")
        }

        protocolSafeLogWarn("Translator found no matching rule\n")
        return nil
    }

    /// Extract keepalive data from NOTE_KEEPALIVE frame
    /// Payload format: [channel, note]
    /// Returns (sourceMac, channel, note) or nil if invalid
    public func extractKeepalive(frame: ESPNOWFrame) -> (channel: UInt8, note: UInt8)? {
        guard frame.messageType == .noteKeepalive else {
            return nil
        }

        guard frame.payload.count >= 2 else {
            protocolSafeLogWarn("Translator: NOTE_KEEPALIVE payload too short\n")
            return nil
        }

        let channel = frame.payload[0]
        let note = frame.payload[1]

        protocolSafeLogDebug(
            "Translator: NOTE_KEEPALIVE ch=\(channel) note=\(note) from \(formatMACAddress(frame.senderMac))\n"
        )

        return (channel: channel, note: note)
    }

    private func translateFixedMIDIEvent(frame: ESPNOWFrame) throws(TranslatorError)
        -> MIDIEventFrame
    {
        /*
        Structure:
            0-3:    MAGIC
            4:      version
            5:      event type (status)
            6:      channel
            7:      data1
            8:      data2
        */

        let p = frame.payload

        guard p.count >= 9 else {
            throw TranslatorError.payloadTooShort
        }

        let expectedMagic = FrameConstants.MAGIC_BYTE_STRING.utf8CString.prefix(4).map {
            UInt8(bitPattern: $0)
        }

        guard Array(p[0..<4]) == expectedMagic else {
            throw TranslatorError.invalidMagicBytes
        }

        let version = p[4]
        let eventType = p[5]
        let channel = p[6] & 0x0F
        let data1 = p[7]
        let data2 = p[8]

        // Only support version 1 for now
        guard version == 1 else { throw TranslatorError.unsupportedVersion }

        switch eventType {

        case MidiEventType.noteOff.rawValue,
            MidiEventType.noteOn.rawValue,
            MidiEventType.controlChange.rawValue:

            return MIDIEventFrame(
                sourceMac: frame.senderMac,
                channel: channel,
                eventType: MidiEventType(rawValue: eventType),
                data1: data1,
                data2: data2,
                sysExData: []
            )

        case MidiEventType.pitchBend.rawValue:  // PITCH_BEND
            // bend is signed 16-bit little-endian
            let lo = UInt16(data1)
            let hi = UInt16(data2)
            let combined = lo | (hi << 8)
            let bendRaw = Int16(bitPattern: combined)
            // convert signed bend to unsigned 14-bit value centered at 8192
            let raw14 = Int(bendRaw) + 8192
            let lsb = UInt8(raw14 & 0x7F)
            let msb = UInt8((raw14 >> 7) & 0x7F)
            return MIDIEventFrame(
                sourceMac: frame.senderMac,
                channel: channel,
                eventType: MidiEventType(rawValue: eventType),
                data1: lsb,
                data2: msb,
                sysExData: []
            )

        default:
            throw TranslatorError.unknownPacketType
        }
    }
}
