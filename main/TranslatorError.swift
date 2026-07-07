public enum TranslatorError: Error {
    case invalidPayload
    case invalidMagicBytes
    case unsupportedVersion
    case unknownPacketType
    case payloadTooShort
}
