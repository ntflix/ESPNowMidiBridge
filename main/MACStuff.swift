func readWiFiMAC() -> [UInt8]? {
    var mac = [UInt8](repeating: 0, count: 6)
    let ok = mac.withUnsafeMutableBufferPointer { buf in
        swift_get_wifi_sta_mac(buf.baseAddress)
    }
    return ok ? mac : nil
}

func readBaseMAC() -> [UInt8]? {
    var mac = [UInt8](repeating: 0, count: 6)
    let ok = mac.withUnsafeMutableBufferPointer { buf in
        swift_get_base_mac(buf.baseAddress)
    }
    return ok ? mac : nil
}

func formatMACAddress(_ mac: [UInt8]) -> String {
    let hexDigits: [UInt8] = Array("0123456789ABCDEF".utf8)
    let separator: UInt8 = 58  // ASCII ":"
    let macLength = 6
    let outputLength = 17  // "XX:XX:XX:XX:XX:XX"

    var output = [UInt8](repeating: 0, count: outputLength)
    var outputIndex = 0

    for byteIndex in 0..<macLength {
        let byte = mac[byteIndex]

        output[outputIndex] = hexDigits[Int(byte >> 4)]
        output[outputIndex + 1] = hexDigits[Int(byte & 0x0F)]

        if byteIndex < macLength - 1 {
            output[outputIndex + 2] = separator
            outputIndex += 3
        } else {
            outputIndex += 2
        }
    }

    return String(decoding: output, as: UTF8.self)
}

func formatMACAddress(_ mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> String {
    let bytes = [mac.0, mac.1, mac.2, mac.3, mac.4, mac.5]
    return formatMACAddress(bytes)
}
