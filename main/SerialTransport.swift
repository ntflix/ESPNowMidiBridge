// MARK: - SerialTransport Component
public class SerialTransport {
    // USB Serial/JTAG configuration
    private let BAUD_RATE: UInt32 = 921600
    private var isInitialised: Bool = false

    public init() {
        // Initialise in a separate call
    }

    /// Initialise USB Serial/JTAG
    public func initialise() -> Bool {
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
    public func sendFrame(_ frame: MIDIEventFrame) throws(SerialTransportError) {
        guard isInitialised else {
            protocolSafeLogWarn("SerialTransport not Initialised\n")
            throw SerialTransportError.notInitialised
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
            throw SerialTransportError.decodeReturnedNil
        }

        if decodedBytes != frameBytes {
            protocolSafeLogError("COBS self-test failed: round-trip mismatch\n")
            protocolSafeLogError("Raw: \(frameBytes)\n")
            protocolSafeLogError("Encoded: \(encodedBytes)\n")
            protocolSafeLogError("Decoded: \(decodedBytes)\n")
            throw SerialTransportError.roundTripMismatch
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
        } else if writeLen > 0 {
            protocolSafeLogWarn("Wrote \(writeLen) bytes out of \(transmitBuffer.count)\n")
        } else {
            protocolSafeLogWarn("Failed to write to USB\n")
        }
    }

    /// DeInitialise the transport
    public func deInitialise() {
        if isInitialised {
            swift_usb_serial_deinit()
            isInitialised = false
        }
    }
}
