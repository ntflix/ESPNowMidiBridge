/// MIDI Event Frame structures and types
/// These are sent over the USB CDC-ACM link to the USB-connected host.

public enum MidiEventType {
    case noteOn
    case noteOff
    case controlChange
    case programChange
    case pitchBend
    case aftertouch
    case polyAftertouch
    case sysExPassthrough
    case other(status: UInt8)

    public var rawValue: UInt8 {
        switch self {
        case .noteOn:
            return 0x90
        case .noteOff:
            return 0x80
        case .controlChange:
            return 0xB0
        case .programChange:
            return 0xC0
        case .pitchBend:
            return 0xE0
        case .aftertouch:
            return 0xD0
        case .polyAftertouch:
            return 0xA0
        case .sysExPassthrough:
            return 0xF0
        case .other(let status):
            return status
        }
    }

    public init(rawValue: UInt8) {
        switch rawValue & 0xF0 {
        case 0x90:
            self = .noteOn
        case 0x80:
            self = .noteOff
        case 0xB0:
            self = .controlChange
        case 0xC0:
            self = .programChange
        case 0xE0:
            self = .pitchBend
        case 0xD0:
            self = .aftertouch
        case 0xA0:
            self = .polyAftertouch
        case 0xF0:
            self = .sysExPassthrough
        default:
            self = .other(status: rawValue)
        }
    }

    public var description: String {
        switch self {
        case .noteOn:
            return "Note On"
        case .noteOff:
            return "Note Off"
        case .controlChange:
            return "Control Change"
        case .programChange:
            return "Program Change"
        case .pitchBend:
            return "Pitch Bend"
        case .aftertouch:
            return "Aftertouch"
        case .polyAftertouch:
            return "Polyphonic Aftertouch"
        case .sysExPassthrough:
            return "SysEx Passthrough"
        case .other(let status):
            return "Other (\(status))"
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.noteOn, .noteOn), (.noteOff, .noteOff), (.controlChange, .controlChange),
            (.programChange, .programChange), (.pitchBend, .pitchBend),
            (.aftertouch, .aftertouch), (.polyAftertouch, .polyAftertouch),
            (.sysExPassthrough, .sysExPassthrough):
            return true
        case (.other(let status1), .other(let status2)):
            return status1 == status2
        default:
            return false
        }
    }
}

// MARK: - MIDI Event Frame
/// Represents a MIDI event to be sent to the USB-connected host.
/// Layout (must be kept in sync with PROTOCOL.md):
/// - Byte 0-5:   SOURCE_MAC
/// - Byte 6:     MIDI channel (0-15)
/// - Byte 7:     Event type
/// - Byte 8:     Data byte 1
/// - Byte 9:     Data byte 2
/// - Byte 10:    SysEx length
/// - Bytes 11+:  SysEx data (variable, max 246 bytes)
public struct MIDIEventFrame {
    public var sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    public var channel: UInt8  // 0-15
    public var eventType: MidiEventType
    public var data1: UInt8
    public var data2: UInt8
    public var sysExData: [UInt8]

    public init(
        sourceMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        channel: UInt8,
        eventType: MidiEventType,
        data1: UInt8,
        data2: UInt8,
        sysExData: [UInt8] = []
    ) {
        self.sourceMac = sourceMac
        self.channel = channel
        self.eventType = eventType
        self.data1 = data1
        self.data2 = data2
        self.sysExData = sysExData
    }

    /// Encode frame into bytes for COBS encoding
    public func toBytes() -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(sourceMac.0)
        bytes.append(sourceMac.1)
        bytes.append(sourceMac.2)
        bytes.append(sourceMac.3)
        bytes.append(sourceMac.4)
        bytes.append(sourceMac.5)
        bytes.append(channel & 0x0F)
        bytes.append(eventType.rawValue)
        bytes.append(data1)
        bytes.append(data2)

        if eventType == .sysExPassthrough {
            bytes.append(UInt8(min(sysExData.count, 246)))
            bytes.append(contentsOf: sysExData.prefix(246))
        }

        return bytes
    }

    /// Decode frame from bytes
    public static func fromBytes(_ bytes: [UInt8]) -> MIDIEventFrame? {
        guard bytes.count >= 10 else { return nil }

        let sourceMac = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5])
        let channel = bytes[6] & 0x0F
        let eventType = MidiEventType(rawValue: bytes[7])
        let data1 = bytes[8]
        let data2 = bytes[9]

        var sysExData: [UInt8] = []

        if eventType == .sysExPassthrough {
            guard bytes.count >= 11 else { return nil }
            let sysExLen = Int(bytes[10])
            guard bytes.count >= 11 + sysExLen else { return nil }
            sysExData = Array(bytes[11..<(11 + sysExLen)])
        }

        return MIDIEventFrame(
            sourceMac: sourceMac,
            channel: channel,
            eventType: eventType,
            data1: data1,
            data2: data2,
            sysExData: sysExData
        )
    }

    public func describe() -> String {
        "src=\(formatMACAddress(sourceMac)) ch=\(channel) type=\(eventType.description) data1=\(data1) data2=\(data2) sysExLen=\(sysExData.count)"
    }

    public func hexBytes() -> String {
        self.toBytes().map { "\($0)" }.joined(separator: " ")
    }
}

/// Raw ESP-NOW frame with sender and payload
public struct ESPNOWFrame {
    public let senderMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    public let messageType: ESPNOWMessageType
    public let payload: [UInt8]

    public init(
        senderMac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        messageType: ESPNOWMessageType,
        payload: [UInt8]
    ) {
        self.senderMac = senderMac
        self.messageType = messageType
        self.payload = payload
    }

    var dataPayload: [UInt8]? {
        guard messageType == .data else { return nil }
        return payload
    }
}

// MARK: - Frame Constants
public struct FrameConstants {
    public static let MAGIC_BYTE_STRING = "MJAM"
    public static let MAGIC_BYTE_0: UInt8 = UInt8(MAGIC_BYTE_STRING.utf8CString[0])
    public static let MAGIC_BYTE_1: UInt8 = UInt8(MAGIC_BYTE_STRING.utf8CString[1])
    public static let MAGIC_BYTE_2: UInt8 = UInt8(MAGIC_BYTE_STRING.utf8CString[2])
    public static let MAGIC_BYTE_3: UInt8 = UInt8(MAGIC_BYTE_STRING.utf8CString[3])

    public static let ROOM_ID: UInt8 = 0x01  // Compile-time constant
    public static let MAX_PAYLOAD_SIZE: Int = 250
    public static let MAX_SYSEX_SIZE: Int = 246
    public static let ADVERTISEMENT_INTERVAL_MS: UInt32 = 2500
    public static let PEER_TIMEOUT_MS: UInt32 = 5000
}

public func hexBytes(_ bytes: [UInt8]) -> String {
    bytes.map { String($0) }.joined(separator: " ")
}
