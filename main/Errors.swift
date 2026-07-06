public enum RadioError: Error {
    case failedToInitialise
}
public enum SerialTransportError: Error {
    case notInitialised
    case decodeReturnedNil
    case roundTripMismatch
}
