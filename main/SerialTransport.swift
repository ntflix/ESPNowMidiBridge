// MARK: - SerialTransport Component
public class SerialTransport {
    // USB Serial/JTAG configuration
    private let BAUD_RATE: UInt32 = 921600
    private var isInitialised: Bool = false

    public init() {
        // Initialise in a separate call
    }

    /// Initialise USB Serial/JTAG
    public func Initialise() -> Bool {
        // Use Swift shim to Initialise USB Serial/JTAG buffers
        if swift_usb_serial_init(128, 256) {
            isInitialised = true
            protocolSafeLogInfo("SerialTransport Initialised\n")
            return true
        }

        protocolSafeLogError("Failed to Initialise USB Serial/JTAG\n")
        return false
    }

    /// Send a MIDI event frame over USB Serial/JTAG
    public func sendFrame(_ frame: MIDIEventFrame) -> Bool {
        guard isInitialised else {
            protocolSafeLogWarn("SerialTransport not Initialised\n")
            return false
        }

        let frameBytes = frame.toBytes()
        protocolSafeLogInfo("MIDIEventFrame: \(frame.describe())\n")
        protocolSafeLogInfo("Raw bytes (\(frameBytes.count)): \(hexBytes(frameBytes))\n")

        let encodedBytes = COBSCodec.encode(frameBytes)

        // Local self-test: decode our own encoded payload before sending
        guard let decodedBytes = COBSCodec.decode(encodedBytes) else {
            protocolSafeLogError("COBS self-test failed: decode returned nil\n")
            protocolSafeLogError("Raw: \(frameBytes)\n")
            protocolSafeLogError("Encoded: \(encodedBytes)\n")
            return false
        }

        if decodedBytes != frameBytes {
            protocolSafeLogError("COBS self-test failed: round-trip mismatch\n")
            protocolSafeLogError("Raw: \(frameBytes)\n")
            protocolSafeLogError("Encoded: \(encodedBytes)\n")
            protocolSafeLogError("Decoded: \(decodedBytes)\n")
            return false
        }

        var transmitBuffer = encodedBytes
        transmitBuffer.append(0x00)

        let writeLen = transmitBuffer.withUnsafeBytes { buf -> Int32 in
            swift_usb_serial_write(
                buf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                UInt32(transmitBuffer.count),
                100
            )
        }

        if writeLen == Int32(transmitBuffer.count) {
            swift_usb_serial_flush()
            return true
        }

        protocolSafeLogWarn("Partial write to USB\n")
        return writeLen > 0
    }

    /// DeInitialise the transport
    public func deInitialise() {
        if isInitialised {
            swift_usb_serial_deinit()
            isInitialised = false
        }
    }
}

// MARK: - Global SerialTransport Instance
private var gSerialTransport: SerialTransport? = nil

func setGlobalSerialTransport(_ transport: SerialTransport) {
    gSerialTransport = transport
}

func getGlobalSerialTransport() -> SerialTransport? {
    return gSerialTransport
}
