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
    /// Mapping rules
    private let mappingRules: [MappingRule]

    public init() {
        // Define mapping rules here
        // This is where we can configure behavior
        mappingRules = MappingConfig.rules
    }

    /// Process an incoming frame and produce a MIDI event if matched
    public func translate(frame: ESPNOWFrame) -> MIDIEventFrame? {
        // Only process DATA frames
        guard frame.messageType == .data else {
            protocolSafeLogWarn("Translator ignoring non-DATA frame\n")
            return nil
        }

        protocolSafeLogInfo("Translator input payload: \(frame.payload)\n")

        // 1) Try fixed-format ESPNOWMIDIClient layout
        if let evt = translateFixedMIDIEvent(frame: frame) {
            protocolSafeLogInfo("Translator parsed fixed MIDI event: \(evt.describe())\n")
            return evt
        }

        // 2) Fallback to rule-based mappings (for other devices)
        for rule in mappingRules {
            if rule.matches(frame: frame) {
                let result = rule.apply(frame: frame)
                protocolSafeLogInfo("Translator matched rule; result: \(result.describe())\n")
                return result
            }
        }

        protocolSafeLogWarn("Translator found no matching rule\n")
        return nil
    }

    private func translateFixedMIDIEvent(frame: ESPNOWFrame) -> MIDIEventFrame? {
        let p = frame.payload
        guard p.count >= 11 else { return nil }

        let srcMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
            p[0], p[1], p[2], p[3], p[4], p[5]
        )
        let channel = p[6] & 0x0F
        let status = p[7]
        let data1 = p[8]
        let data2 = p[9]
        let sysexLen = Int(p[10])

        var sysexData: [UInt8] = []
        if sysexLen > 0 {
            let end = min(11 + sysexLen, p.count)
            sysexData = Array(p[11..<end])
        }

        let eventType = MidiEventType(rawValue: status)

        return MIDIEventFrame(
            sourceMac: srcMac,
            channel: channel,
            eventType: eventType,
            data1: data1,
            data2: data2,
            sysExData: sysexData
        )
    }
}

// MARK: - Mapping Configuration
/// mapping rules
public struct MappingConfig {
    static let rules: [MappingRule] = [
        // Example rule 1: Note On from payload byte 1
        // Matches: payload[0] == 0x10
        MappingRule(
            matchOffset: 0,
            matchMask: 0xFF,
            matchValue: 0x10,
            senderMacFilter: nil,
            midiChannel: 0,
            midiEventType: .noteOn,
            data1Source: .payloadByte(1),  // Note number from payload[1]
            data2Source: .payloadByte(2),  // Velocity from payload[2]
            sysExPayloadStart: nil,
            sysExPayloadLen: nil
        ),

        // Example rule 2: Control Change from payload byte 1
        // Matches: payload[0] == 0x20
        MappingRule(
            matchOffset: 0,
            matchMask: 0xFF,
            matchValue: 0x20,
            senderMacFilter: nil,
            midiChannel: 1,
            midiEventType: .controlChange,
            data1Source: .payloadByte(1),  // CC number
            data2Source: .payloadByte(2),  // CC value
            sysExPayloadStart: nil,
            sysExPayloadLen: nil
        ),

        // Example rule 3: Program Change
        // Matches: payload[0] == 0x30
        MappingRule(
            matchOffset: 0,
            matchMask: 0xFF,
            matchValue: 0x30,
            senderMacFilter: nil,
            midiChannel: 0,
            midiEventType: .programChange,
            data1Source: .payloadByte(1),  // Program number
            data2Source: .unused,
            sysExPayloadStart: nil,
            sysExPayloadLen: nil
        ),

        // Example rule: Note from ESPNOWMIDIClient
        MappingRule(
            matchOffset: 0,
            matchMask: 0xFF,
            matchValue: 0x10,  // our “note event” tag
            senderMacFilter: nil,  // or the client MAC if you want
            midiChannel: 0,  // or something configured
            midiEventType: .noteOn,  // noteOn / noteOff inferred later if needed
            data1Source: .payloadByte(1),  // note
            data2Source: .payloadByte(2),  // velocity
            sysExPayloadStart: nil,
            sysExPayloadLen: nil
        ),
    ]
}
