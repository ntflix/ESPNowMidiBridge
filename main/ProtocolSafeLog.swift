public var gProtocolMode = false

public func protocolSafePrint(_ message: String) {
    if !gProtocolMode {
        print(message)
    }
}

public func protocolSafeLogInfo(_ message: String) {
    if !gProtocolMode {
        swift_log_info(message)
    }
}

public func protocolSafeLogWarn(_ message: String) {
    if !gProtocolMode {
        swift_log_warn(message)
    }
}

public func protocolSafeLogError(_ message: String) {
    if !gProtocolMode {
        swift_log_error(message)
    }
}

public func protocolSafeLogDebug(_ message: String) {
    if !gProtocolMode {
        swift_log_debug(message)
    }
}
