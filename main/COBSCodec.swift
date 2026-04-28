/// Consistent Overhead Byte Stuffing (COBS) codec
/// Encodes data to be transparent to 0x00 sentinel byte

public struct COBSCodec {
    /// Encode data using COBS
    /// The encoded data will not contain any 0x00 bytes except as delimiters
    public static func encode(_ data: [UInt8]) -> [UInt8] {
        var encoded: [UInt8] = []
        var blockStart = 0
        var blockLen: UInt8 = 1

        for i in 0..<data.count {
            if data[i] == 0x00 {
                // Found a zero byte; write the block header
                encoded.append(blockLen)
                encoded.append(contentsOf: data[blockStart..<i])
                blockStart = i + 1
                blockLen = 1
            } else {
                blockLen += 1
                if blockLen == 0xFF {
                    // Block is full; write it
                    encoded.append(0xFF)
                    encoded.append(contentsOf: data[blockStart..<(i + 1)])
                    blockStart = i + 1
                    blockLen = 1
                }
            }
        }

        // Write final block
        encoded.append(blockLen)
        encoded.append(contentsOf: data[blockStart...])

        return encoded
    }

    /// Decode COBS-encoded data
    /// Assumes data is properly framed (no sentinel included)
    public static func decode(_ data: [UInt8]) -> [UInt8]? {
        guard !data.isEmpty else { return nil }

        var decoded: [UInt8] = []
        var pos = 0

        while pos < data.count {
            let blockLen = Int(data[pos])
            pos += 1

            if blockLen == 0 {
                // Invalid: block length cannot be 0
                return nil
            }

            let blockEnd = min(pos + blockLen - 1, data.count)
            let actualBlockLen = blockEnd - pos
            if actualBlockLen < blockLen - 1 {
                // Invalid: not enough data for block
                return nil
            }

            decoded.append(contentsOf: data[pos..<blockEnd])

            if blockLen < 0xFF {
                // Insert zero byte between blocks
                if pos + (blockLen - 1) < data.count {
                    decoded.append(0x00)
                }
            }

            pos = blockEnd
        }

        return decoded
    }
}
