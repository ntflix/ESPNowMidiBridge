public var shouldPrint = false

public func protocolSafePrint(_ message: String) {
    if shouldPrint {
        print(message)
    }
}

public func protocolSafeLogInfo(_ message: String) {
    if shouldPrint {
        swift_log_info(message)
    }
}

public func protocolSafeLogWarn(_ message: String) {
    if shouldPrint {
        swift_log_warn(message)
    }
}

public func protocolSafeLogError(_ message: String) {
    if shouldPrint {
        swift_log_error(message)
    }
}

public func protocolSafeLogDebug(_ message: String) {
    if shouldPrint {
        swift_log_debug(message)
    }
}
