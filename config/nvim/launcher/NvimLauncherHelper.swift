import CryptoKit
import Darwin
import Foundation

private let protocolVersion = 1
private let reservationLifetime: TimeInterval = 15
private let readinessTimeout: TimeInterval = 5
private let clientTimeout: TimeInterval = 2
private let closeRequestLifetime: TimeInterval = 30
private let closeWaitTimeout: time_t = 10
private let launcherBundleIdentifier = "com.usmon.nvim-launcher"

private enum LauncherError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private struct Reservation: Codable {
    var protocolVersion: Int
    var reusable: Bool
    var root: String
    var rootHash: String
    var socketPath: String
    var recordPath: String
    var nvimPath: String
    var token: String
    var createdAt: TimeInterval
    var pendingPaths: [String]
}

private struct Session: Codable {
    var protocolVersion: Int
    var root: String
    var rootHash: String
    var socketPath: String
    var token: String
    var processID: Int32
    var ghosttyWindowID: String
    var ghosttyTabID: String
    var ghosttyTerminalID: String
    var createdAt: TimeInterval
}

private struct ServerIdentity: Decodable {
    let protocolVersion: Int
    let root: String
    let token: String
    let processID: Int32

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol"
        case root
        case token
        case processID = "pid"
    }
}

private struct CloseRequest: Codable {
    var protocolVersion: Int
    var token: String
    var ghosttyWindowID: String
    var ghosttyTabID: String
    var ghosttyTerminalID: String
    var createdAt: TimeInterval
}

private struct CanonicalItem {
    let path: String
    let isDirectory: Bool
}

private struct ProcessResult {
    let status: Int32
    let stdout: Data
    let stderr: Data
    let timedOut: Bool
}

private final class StateStore {
    let root: String
    let sessionsDirectory: String
    let reservationsDirectory: String
    let socketsDirectory: String
    let closeRequestsDirectory: String
    private let lockPath: String

    init() throws {
        let environment = ProcessInfo.processInfo.environment
        if environment["NVIM_LAUNCHER_TESTING"] == "1",
           let override = environment["NVIM_LAUNCHER_STATE_DIR"],
           override.hasPrefix("/") {
            root = override
        } else {
            root = "/tmp/com.usmon.nvim-launcher-\(getuid())"
        }

        sessionsDirectory = root + "/sessions"
        reservationsDirectory = root + "/reservations"
        socketsDirectory = root + "/sockets"
        closeRequestsDirectory = root + "/close-requests"
        lockPath = root + "/lock"

        try ensureSecureDirectory(root)
        try ensureSecureDirectory(sessionsDirectory)
        try ensureSecureDirectory(reservationsDirectory)
        try ensureSecureDirectory(socketsDirectory)
        try ensureSecureDirectory(closeRequestsDirectory)
    }

    func withLock<T>(_ body: () throws -> T) throws -> T {
        let descriptor = open(lockPath, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else {
            throw LauncherError.message("Cannot open launcher state lock: \(errnoMessage())")
        }
        defer {
            _ = lockf(descriptor, F_ULOCK, 0)
            close(descriptor)
        }

        var info = stat()
        guard fstat(descriptor, &info) == 0,
              info.st_uid == getuid(),
              info.st_mode & S_IFMT == S_IFREG,
              info.st_mode & 0o077 == 0 else {
            throw LauncherError.message("Launcher state lock is not a secure user-owned file")
        }
        guard lockf(descriptor, F_LOCK, 0) == 0 else {
            throw LauncherError.message("Cannot lock launcher state: \(errnoMessage())")
        }
        return try body()
    }

    func sessionPath(_ rootHash: String) -> String {
        sessionsDirectory + "/" + rootHash + ".json"
    }

    func reservationPath(_ rootHash: String) -> String {
        reservationsDirectory + "/" + rootHash + ".json"
    }

    func socketPath(_ rootHash: String) -> String {
        socketsDirectory + "/" + rootHash + ".sock"
    }

    func closeRequestPath(_ token: String) -> String {
        closeRequestsDirectory + "/" + token + ".json"
    }

    func readSession(_ rootHash: String) throws -> Session? {
        try readJSON(Session.self, at: sessionPath(rootHash))
    }

    func readReservation(_ rootHash: String) throws -> Reservation? {
        try readJSON(Reservation.self, at: reservationPath(rootHash))
    }

    func writeSession(_ session: Session) throws {
        try writeJSON(session, to: sessionPath(session.rootHash))
    }

    func writeReservation(_ reservation: Reservation) throws {
        try writeJSON(reservation, to: reservationPath(reservation.rootHash))
    }

    func createCloseRequest(
        windowID: String,
        tabID: String,
        terminalID: String
    ) throws -> String {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let request = CloseRequest(
            protocolVersion: protocolVersion,
            token: token,
            ghosttyWindowID: windowID,
            ghosttyTabID: tabID,
            ghosttyTerminalID: terminalID,
            createdAt: Date().timeIntervalSince1970
        )
        try withLock {
            try cleanupCloseRequestsLocked()
            try writeJSON(request, to: closeRequestPath(token))
        }
        return token
    }

    func consumeCloseRequest(_ token: String) throws -> CloseRequest {
        try withLock {
            let path = closeRequestPath(token)
            guard let request = try readJSON(CloseRequest.self, at: path),
                  request.protocolVersion == protocolVersion,
                  request.token == token,
                  Date().timeIntervalSince1970 - request.createdAt <= closeRequestLifetime else {
                try removeSecureFile(path, expectedType: S_IFREG)
                throw LauncherError.message("The Ghostty close request is missing or expired")
            }
            try removeSecureFile(path, expectedType: S_IFREG)
            return request
        }
    }

    func allSessions() throws -> [Session] {
        try loadDirectory(Session.self, from: sessionsDirectory) { session, name in
            session.rootHash + ".json" == name
                && session.rootHash == rootHash(session.root)
                && session.socketPath == self.socketPath(session.rootHash)
        }
    }

    func allReservations() throws -> [Reservation] {
        try loadDirectory(Reservation.self, from: reservationsDirectory) { reservation, name in
            reservation.rootHash + ".json" == name
                && reservation.rootHash == rootHash(reservation.root)
                && reservation.socketPath == self.socketPath(reservation.rootHash)
                && reservation.recordPath
                    == (reservation.reusable
                        ? self.sessionPath(reservation.rootHash)
                        : self.reservationPath(reservation.rootHash))
        }
    }

    func removeSession(_ session: Session) throws {
        try withLock {
            guard let current = try readSession(session.rootHash),
                  current.token == session.token else {
                return
            }
            try removeSecureFile(sessionPath(session.rootHash), expectedType: S_IFREG)
            try removeOwnedSocket(session.socketPath)
        }
    }

    func removeReservation(_ reservation: Reservation) throws {
        try withLock {
            guard let current = try readReservation(reservation.rootHash),
                  current.token == reservation.token else {
                return
            }
            try removeSecureFile(reservationPath(reservation.rootHash), expectedType: S_IFREG)
            try removeOwnedSocket(reservation.socketPath)
        }
    }

    func cleanupExpiredReservations() throws {
        let now = Date().timeIntervalSince1970
        for reservation in try allReservations()
        where reservation.protocolVersion != protocolVersion
            || now - reservation.createdAt > reservationLifetime {
            try removeReservation(reservation)
        }
    }

    func removeOwnedSocket(_ path: String) throws {
        guard path.hasPrefix(socketsDirectory + "/") else {
            throw LauncherError.message("Refusing to remove a socket outside launcher state")
        }

        var info = stat()
        if lstat(path, &info) != 0 {
            if errno == ENOENT {
                return
            }
            throw LauncherError.message("Cannot inspect launcher socket: \(errnoMessage())")
        }
        guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK else {
            throw LauncherError.message("Refusing to remove a socket not owned by this launcher")
        }
        guard unlink(path) == 0 || errno == ENOENT else {
            throw LauncherError.message("Cannot remove stale launcher socket: \(errnoMessage())")
        }
    }

    func validateSocket(_ path: String) -> Bool {
        guard path.hasPrefix(socketsDirectory + "/") else {
            return false
        }
        var info = stat()
        return lstat(path, &info) == 0
            && info.st_uid == getuid()
            && info.st_mode & S_IFMT == S_IFSOCK
            && info.st_mode & 0o022 == 0
    }

    func removeReservationRecordLocked(rootHash: String, token: String) throws {
        guard let reservation = try readReservation(rootHash),
              reservation.token == token else {
            throw LauncherError.message("Rooted Neovim launch reservation disappeared")
        }
        try removeSecureFile(reservationPath(rootHash), expectedType: S_IFREG)
    }

    private func cleanupCloseRequestsLocked() throws {
        let now = Date().timeIntervalSince1970
        for name in try FileManager.default.contentsOfDirectory(atPath: closeRequestsDirectory)
        where isStateFilename(name) {
            let path = closeRequestsDirectory + "/" + name
            guard let request = try? readJSON(CloseRequest.self, at: path),
                  request.protocolVersion == protocolVersion,
                  request.token + ".json" == name,
                  now - request.createdAt <= closeRequestLifetime else {
                try removeSecureFile(path, expectedType: S_IFREG)
                continue
            }
        }
    }

    private func ensureSecureDirectory(_ path: String) throws {
        if mkdir(path, 0o700) != 0 && errno != EEXIST {
            throw LauncherError.message("Cannot create launcher state directory \(path): \(errnoMessage())")
        }

        var info = stat()
        guard lstat(path, &info) == 0,
              info.st_uid == getuid(),
              info.st_mode & S_IFMT == S_IFDIR,
              info.st_mode & 0o077 == 0 else {
            throw LauncherError.message("Launcher state directory is not a secure user-owned directory: \(path)")
        }
    }

    private func loadDirectory<T: Decodable>(
        _ type: T.Type,
        from directory: String,
        validate: (T, String) -> Bool
    ) throws -> [T] {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory)
        return try names.compactMap { name in
            guard isStateFilename(name) else {
                return nil
            }
            let path = directory + "/" + name
            do {
                guard let value = try readJSON(type, at: path),
                      validate(value, name) else {
                    try removeSecureFile(path, expectedType: S_IFREG)
                    return nil
                }
                return value
            } catch {
                var info = stat()
                guard lstat(path, &info) == 0,
                      info.st_uid == getuid(),
                      info.st_mode & S_IFMT == S_IFREG,
                      info.st_mode & 0o077 == 0 else {
                    throw error
                }
                try removeSecureFile(path, expectedType: S_IFREG)
                return nil
            }
        }
    }

    private func readJSON<T: Decodable>(_ type: T.Type, at path: String) throws -> T? {
        let descriptor = open(path, O_RDONLY | O_NOFOLLOW)
        if descriptor < 0 {
            if errno == ENOENT {
                return nil
            }
            throw LauncherError.message("Cannot open launcher state file: \(errnoMessage())")
        }
        defer { close(descriptor) }

        var info = stat()
        guard fstat(descriptor, &info) == 0,
              info.st_uid == getuid(),
              info.st_mode & S_IFMT == S_IFREG,
              info.st_mode & 0o077 == 0 else {
            throw LauncherError.message("Launcher state file is not a secure user-owned file: \(path)")
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 {
                break
            }
            if count < 0 {
                throw LauncherError.message("Cannot read launcher state file: \(errnoMessage())")
            }
            data.append(buffer, count: count)
            if data.count > 1_048_576 {
                throw LauncherError.message("Launcher state file is unexpectedly large: \(path)")
            }
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LauncherError.message("Launcher state file is invalid: \(path)")
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        let temporaryPath = path + "." + UUID().uuidString + ".tmp"
        let descriptor = open(temporaryPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else {
            throw LauncherError.message("Cannot create temporary launcher state: \(errnoMessage())")
        }

        var writeError: Error?
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if written <= 0 {
                    writeError = LauncherError.message("Cannot write launcher state: \(errnoMessage())")
                    return
                }
                offset += written
            }
        }

        if writeError == nil && fsync(descriptor) != 0 {
            writeError = LauncherError.message("Cannot flush launcher state: \(errnoMessage())")
        }
        close(descriptor)

        if let writeError {
            _ = unlink(temporaryPath)
            throw writeError
        }
        guard rename(temporaryPath, path) == 0 else {
            _ = unlink(temporaryPath)
            throw LauncherError.message("Cannot publish launcher state atomically: \(errnoMessage())")
        }
    }

    private func removeSecureFile(_ path: String, expectedType: mode_t) throws {
        var info = stat()
        if lstat(path, &info) != 0 {
            if errno == ENOENT {
                return
            }
            throw LauncherError.message("Cannot inspect launcher state file: \(errnoMessage())")
        }
        guard info.st_uid == getuid(), info.st_mode & S_IFMT == expectedType else {
            throw LauncherError.message("Refusing to remove an unsafe launcher state file")
        }
        guard unlink(path) == 0 || errno == ENOENT else {
            throw LauncherError.message("Cannot remove launcher state file: \(errnoMessage())")
        }
    }
}

private func errnoMessage() -> String {
    String(cString: strerror(errno))
}

private func isStateFilename(_ name: String) -> Bool {
    guard name.count == 37, name.hasSuffix(".json") else {
        return false
    }
    return name.dropLast(5).allSatisfy { character in
        character.isNumber || "abcdef".contains(character)
    }
}

private func isRootHash(_ value: String) -> Bool {
    value.count == 32 && value.allSatisfy { $0.isNumber || "abcdef".contains($0) }
}

private func rootHash(_ root: String) -> String {
    SHA256.hash(data: Data(root.utf8))
        .prefix(16)
        .map { String(format: "%02x", $0) }
        .joined()
}

private func canonicalItem(_ path: String) throws -> CanonicalItem {
    guard path.hasPrefix("/") else {
        throw LauncherError.message("Launcher paths must be absolute: \(path)")
    }

    let canonicalPointer = path.withCString { realpath($0, nil) }
    guard let canonicalPointer else {
        throw LauncherError.message("Cannot canonicalize \(path): \(errnoMessage())")
    }
    defer { free(canonicalPointer) }
    let canonicalPath = String(cString: canonicalPointer)

    var info = stat()
    guard stat(canonicalPath, &info) == 0 else {
        throw LauncherError.message("Cannot inspect \(canonicalPath): \(errnoMessage())")
    }
    return CanonicalItem(path: canonicalPath, isDirectory: info.st_mode & S_IFMT == S_IFDIR)
}

private func containsPath(root: String, path: String) -> Bool {
    root == "/" || path == root || path.hasPrefix(root + "/")
}

private func bestRootIndex(path: String, roots: [String]) -> Int? {
    roots.enumerated()
        .filter { containsPath(root: $0.element, path: path) }
        .max { left, right in
            left.element.utf8.count < right.element.utf8.count
        }?
        .offset
}

private func executable(_ path: String) -> Bool {
    path.hasPrefix("/") && access(path, X_OK) == 0
}

private func currentExecutablePath() throws -> String {
    var size: UInt32 = 0
    _ = _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size))
    guard _NSGetExecutablePath(&buffer, &size) == 0 else {
        throw LauncherError.message("Cannot resolve the launcher helper executable path")
    }
    return try canonicalItem(String(cString: buffer)).path
}

private func runProcess(
    executablePath: String,
    arguments: [String],
    timeout: TimeInterval = clientTimeout
) throws -> ProcessResult {
    guard executable(executablePath) else {
        throw LauncherError.message("Neovim client is not executable: \(executablePath)")
    }

    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let semaphore = DispatchSemaphore(value: 0)
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.terminationHandler = { _ in semaphore.signal() }

    try process.run()
    let timedOut = semaphore.wait(timeout: .now() + timeout) == .timedOut
    if timedOut {
        process.terminate()
        if semaphore.wait(timeout: .now() + 0.2) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = semaphore.wait(timeout: .now() + 0.2)
        }
    }

    return ProcessResult(
        status: process.isRunning ? -1 : process.terminationStatus,
        stdout: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
        stderr: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
        timedOut: timedOut
    )
}

private let identityExpression = """
json_encode({'protocol': get(get(g:, 'usmon_nvim_launcher', {}), 'protocol', 0), 'root': get(get(g:, 'usmon_nvim_launcher', {}), 'root', ''), 'token': get(get(g:, 'usmon_nvim_launcher', {}), 'token', ''), 'pid': getpid()})
"""

private func queryIdentity(
    nvimPath: String,
    socketPath: String,
    store: StateStore
) -> ServerIdentity? {
    guard store.validateSocket(socketPath) else {
        return nil
    }
    guard let result = try? runProcess(
        executablePath: nvimPath,
        arguments: ["--server", socketPath, "--remote-expr", identityExpression]
    ), !result.timedOut, result.status == 0 else {
        return nil
    }
    return try? JSONDecoder().decode(ServerIdentity.self, from: result.stdout)
}

private func validate(_ session: Session, nvimPath: String, store: StateStore) -> Bool {
    guard let root = try? canonicalItem(session.root),
          root.isDirectory,
          root.path == session.root,
          session.protocolVersion == protocolVersion,
          let identity = queryIdentity(nvimPath: nvimPath, socketPath: session.socketPath, store: store) else {
        return false
    }
    return identity.protocolVersion == protocolVersion
        && identity.root == session.root
        && identity.token == session.token
        && identity.processID == session.processID
}

private func validate(
    _ reservation: Reservation,
    identity: ServerIdentity
) -> Bool {
    reservation.protocolVersion == protocolVersion
        && identity.protocolVersion == protocolVersion
        && identity.root == reservation.root
        && identity.token == reservation.token
        && identity.processID > 0
}

private func liveSessions(nvimPath: String, store: StateStore) throws -> [Session] {
    var result: [Session] = []
    for session in try store.allSessions() {
        if validate(session, nvimPath: nvimPath, store: store) {
            result.append(session)
        } else {
            try store.removeSession(session)
        }
    }
    return result
}

private func liveReservations(store: StateStore) throws -> [Reservation] {
    try store.cleanupExpiredReservations()
    return try store.allReservations().filter {
        $0.reusable
            && $0.protocolVersion == protocolVersion
            && Date().timeIntervalSince1970 - $0.createdAt <= reservationLifetime
    }
}

private func remoteTab(
    path: String,
    session: Session,
    nvimPath: String
) throws {
    let arguments: [String]
    if path.contains("\n") || path.contains("\r") {
        let encodedPath = try JSONEncoder().encode(Array(path.utf8))
        guard let byteArray = String(data: encodedPath, encoding: .utf8) else {
            throw LauncherError.message("Cannot encode a file path for Neovim RPC")
        }
        let expression = """
        luaeval("(function(bytes) local chars = {}; for index, byte in ipairs(bytes) do chars[index] = string.char(byte) end; local path = table.concat(chars); vim.cmd.tabnew(); local buffer = vim.fn.bufadd(path); vim.fn.bufload(buffer); vim.api.nvim_win_set_buf(0, buffer); return true end)(_A)", \(byteArray))
        """
        arguments = ["--server", session.socketPath, "--remote-expr", expression]
    } else {
        arguments = ["--server", session.socketPath, "--remote-tab", path]
    }

    let result = try runProcess(
        executablePath: nvimPath,
        arguments: arguments
    )
    guard !result.timedOut, result.status == 0 else {
        let detail = String(data: result.stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        throw LauncherError.message(
            "Neovim RPC could not open \(path)"
                + ((detail?.isEmpty == false) ? ": \(detail!)" : "")
        )
    }
}

private func configureExitClosure(
    session: Session,
    nvimPath: String
) throws {
    let identifiers = [
        Array(session.ghosttyWindowID.utf8),
        Array(session.ghosttyTabID.utf8),
        Array(session.ghosttyTerminalID.utf8),
    ]
    let encodedIdentifiers = try JSONEncoder().encode(identifiers)
    guard let identifierArray = String(data: encodedIdentifiers, encoding: .utf8) else {
        throw LauncherError.message("Cannot encode Ghostty identities for Neovim")
    }
    let expression = """
    luaeval("(function(values) local function decode(bytes) local chars = {}; for index, byte in ipairs(bytes) do chars[index] = string.char(byte) end; return table.concat(chars) end; local state = vim.g.usmon_nvim_launcher; state.ghostty_window_id = decode(values[1]); state.ghostty_tab_id = decode(values[2]); state.ghostty_terminal_id = decode(values[3]); vim.g.usmon_nvim_launcher = state; return true end)(_A)", \(identifierArray))
    """
    let result = try runProcess(
        executablePath: nvimPath,
        arguments: ["--server", session.socketPath, "--remote-expr", expression]
    )
    guard !result.timedOut, result.status == 0 else {
        throw LauncherError.message("Neovim RPC could not configure Ghostty surface cleanup")
    }
}

private func outputFocus(_ session: Session) {
    print(
        "FOCUS\t\(session.ghosttyWindowID)\t\(session.ghosttyTabID)"
            + "\t\(session.ghosttyTerminalID)"
    )
}

private func route(nvimPath: String, paths: [String], store: StateStore) throws {
    let items = try paths.map(canonicalItem)
    let sessions = try liveSessions(nvimPath: nvimPath, store: store)
    let reservations = try liveReservations(store: store)
    var sessionAssignments: [Int: Session] = [:]
    var reservationAssignments: [Int: Reservation] = [:]
    var unmatched: [Int] = []

    for (index, item) in items.enumerated() {
        let candidates: [(root: String, session: Session?, reservation: Reservation?)] =
            sessions.map { ($0.root, $0, nil) }
                + reservations.map { ($0.root, nil, $0) }
        guard let bestIndex = bestRootIndex(
            path: item.path,
            roots: candidates.map(\.root)
        ) else {
            unmatched.append(index)
            continue
        }
        let candidate = candidates[bestIndex]
        if let session = candidate.session {
            sessionAssignments[index] = session
        } else if let reservation = candidate.reservation {
            reservationAssignments[index] = reservation
        }
    }

    for (index, reservation) in Array(reservationAssignments) {
        let queued = try store.withLock {
            guard var current = try store.readReservation(reservation.rootHash),
                  current.token == reservation.token else {
                return false
            }
            let path = items[index].path
            if !current.pendingPaths.contains(path) {
                current.pendingPaths.append(path)
                try store.writeReservation(current)
            }
            return true
        }
        if !queued {
            reservationAssignments.removeValue(forKey: index)
            if let session = try store.readSession(reservation.rootHash),
               validate(session, nvimPath: nvimPath, store: store) {
                sessionAssignments[index] = session
            } else {
                unmatched.append(index)
            }
        }
    }

    var pendingHashes = Set(reservationAssignments.values.map(\.rootHash))
    let deadline = Date().addingTimeInterval(readinessTimeout)
    while !pendingHashes.isEmpty && Date() < deadline {
        usleep(50_000)
        for rootHash in Array(pendingHashes) {
            if let session = try store.readSession(rootHash),
               validate(session, nvimPath: nvimPath, store: store) {
                for (index, reservation) in reservationAssignments
                where reservation.rootHash == rootHash {
                    sessionAssignments[index] = session
                }
                pendingHashes.remove(rootHash)
            } else if try store.readReservation(rootHash) == nil {
                for (index, reservation) in Array(reservationAssignments)
                where reservation.rootHash == rootHash {
                    reservationAssignments.removeValue(forKey: index)
                    unmatched.append(index)
                }
                pendingHashes.remove(rootHash)
            }
        }
    }

    let grouped = Dictionary(grouping: sessionAssignments.keys.sorted()) {
        sessionAssignments[$0]!.rootHash
    }
    var focusedHashes = Set<String>()
    for indices in grouped.values.sorted(by: { ($0.max() ?? 0) < ($1.max() ?? 0) }) {
        guard let firstIndex = indices.first,
              let session = sessionAssignments[firstIndex] else {
            continue
        }

        let wasPending = indices.contains { reservationAssignments[$0] != nil }
        if !wasPending {
            for index in indices {
                let item = items[index]
                if !(item.isDirectory && item.path == session.root) {
                    do {
                        try remoteTab(path: item.path, session: session, nvimPath: nvimPath)
                    } catch {
                        if !validate(session, nvimPath: nvimPath, store: store) {
                            try store.removeSession(session)
                            unmatched.append(index)
                            continue
                        }
                        throw error
                    }
                }
            }
        }

        if !focusedHashes.contains(session.rootHash) {
            outputFocus(session)
            focusedHashes.insert(session.rootHash)
        }
    }

    for rootHash in pendingHashes {
        print("QUEUED\t\(rootHash)")
    }
    for index in Set(unmatched).sorted() {
        print("UNMATCHED\t\(index)")
    }
}

private func waitForSession(
    rootHash: String,
    token: String,
    nvimPath: String,
    store: StateStore
) throws -> Session? {
    let deadline = Date().addingTimeInterval(readinessTimeout)
    repeat {
        if let session = try store.readSession(rootHash),
           session.token == token,
           validate(session, nvimPath: nvimPath, store: store) {
            return session
        }
        if try store.readReservation(rootHash) == nil {
            return nil
        }
        usleep(50_000)
    } while Date() < deadline
    return nil
}

private func reserveRoot(nvimPath: String, path: String, store: StateStore) throws {
    guard executable(nvimPath) else {
        throw LauncherError.message("Neovim is not executable: \(nvimPath)")
    }
    let item = try canonicalItem(path)
    guard item.isDirectory else {
        throw LauncherError.message("A launcher root must be a directory")
    }
    let hash = rootHash(item.path)

    if let session = try liveSessions(nvimPath: nvimPath, store: store).first(where: {
        $0.rootHash == hash && $0.root == item.path
    }) {
        outputFocus(session)
        return
    }

    try store.cleanupExpiredReservations()
    if var reservation = try store.readReservation(hash),
       reservation.root == item.path {
        try store.withLock {
            guard var current = try store.readReservation(hash),
                  current.token == reservation.token else {
                return
            }
            if !current.pendingPaths.contains(item.path) {
                current.pendingPaths.append(item.path)
                try store.writeReservation(current)
            }
            reservation = current
        }
        if let session = try waitForSession(
            rootHash: hash,
            token: reservation.token,
            nvimPath: nvimPath,
            store: store
        ) {
            outputFocus(session)
        } else {
            print("QUEUED\t\(hash)")
        }
        return
    }

    let reservation = Reservation(
        protocolVersion: protocolVersion,
        reusable: true,
        root: item.path,
        rootHash: hash,
        socketPath: store.socketPath(hash),
        recordPath: store.sessionPath(hash),
        nvimPath: nvimPath,
        token: UUID().uuidString,
        createdAt: Date().timeIntervalSince1970,
        pendingPaths: []
    )

    let created = try store.withLock {
        if try store.readReservation(hash) != nil {
            return false
        }
        if let existing = try store.readSession(hash),
           existing.root == item.path {
            return false
        }
        try store.removeOwnedSocket(reservation.socketPath)
        try store.writeReservation(reservation)
        return true
    }

    if created {
        print("NEW\t\(hash)\t\(reservation.token)")
    } else {
        try reserveRoot(nvimPath: nvimPath, path: item.path, store: store)
    }
}

private func readySession(
    reservation: Reservation,
    windowID: String,
    tabID: String,
    terminalID: String,
    store: StateStore
) throws -> Session {
    for identifier in [windowID, tabID, terminalID] {
        guard validGhosttyIdentifier(identifier) else {
            throw LauncherError.message("Ghostty returned an invalid object identity")
        }
    }

    let deadline = Date().addingTimeInterval(readinessTimeout)
    var identity: ServerIdentity?
    repeat {
        identity = queryIdentity(
            nvimPath: reservation.nvimPath,
            socketPath: reservation.socketPath,
            store: store
        )
        if let identity, validate(reservation, identity: identity) {
            break
        }
        usleep(50_000)
    } while Date() < deadline
    guard let identity, validate(reservation, identity: identity) else {
        try store.removeReservation(reservation)
        throw LauncherError.message(
            "Neovim exited or did not expose its launcher RPC server within \(Int(readinessTimeout)) seconds"
        )
    }

    let session = Session(
        protocolVersion: protocolVersion,
        root: reservation.root,
        rootHash: reservation.rootHash,
        socketPath: reservation.socketPath,
        token: reservation.token,
        processID: identity.processID,
        ghosttyWindowID: windowID,
        ghosttyTabID: tabID,
        ghosttyTerminalID: terminalID,
        createdAt: Date().timeIntervalSince1970
    )
    try configureExitClosure(session: session, nvimPath: reservation.nvimPath)
    return session
}

private func publish(
    rootHash: String,
    token: String,
    windowID: String,
    tabID: String,
    terminalID: String,
    store: StateStore
) throws {
    guard let reservation = try store.readReservation(rootHash),
          reservation.token == token,
          reservation.reusable else {
        throw LauncherError.message("Rooted Neovim launch reservation expired")
    }
    let session = try readySession(
        reservation: reservation,
        windowID: windowID,
        tabID: tabID,
        terminalID: terminalID,
        store: store
    )

    while true {
        let pendingPaths: [String] = try store.withLock {
            guard var current = try store.readReservation(rootHash),
                  current.token == token else {
                throw LauncherError.message("Rooted Neovim launch reservation disappeared")
            }
            let pending = current.pendingPaths
            current.pendingPaths = []
            try store.writeReservation(current)
            return pending
        }

        for path in pendingPaths where path != session.root {
            try remoteTab(path: path, session: session, nvimPath: reservation.nvimPath)
        }

        let finished = try store.withLock {
            guard let current = try store.readReservation(rootHash),
                  current.token == token else {
                throw LauncherError.message("Rooted Neovim launch reservation disappeared")
            }
            if !current.pendingPaths.isEmpty {
                return false
            }
            try store.writeSession(session)
            try store.removeReservationRecordLocked(rootHash: rootHash, token: token)
            return true
        }
        if finished {
            break
        }
    }

    print("READY")
}

private func cancel(rootHash: String, token: String, store: StateStore) throws {
    guard let reservation = try store.readReservation(rootHash),
          reservation.token == token else {
        return
    }
    try store.removeReservation(reservation)
}

private func loadReservation(
    rootHash: String,
    token: String,
    store: StateStore
) throws -> Reservation {
    guard let reservation = try store.readReservation(rootHash),
          reservation.token == token,
          reservation.protocolVersion == protocolVersion else {
        throw LauncherError.message("Rooted Neovim launch reservation is missing or stale")
    }
    return reservation
}

private func prepareOnce(nvimPath: String, paths: [String], store: StateStore) throws {
    guard executable(nvimPath) else {
        throw LauncherError.message("Neovim is not executable: \(nvimPath)")
    }
    try store.cleanupExpiredReservations()
    let canonicalPaths = try paths.map { try canonicalItem($0).path }
    let token = UUID().uuidString
    let identity = "oneshot:" + token
    let hash = rootHash(identity)
    let reservation = Reservation(
        protocolVersion: protocolVersion,
        reusable: false,
        root: identity,
        rootHash: hash,
        socketPath: store.socketPath(hash),
        recordPath: store.reservationPath(hash),
        nvimPath: nvimPath,
        token: token,
        createdAt: Date().timeIntervalSince1970,
        pendingPaths: canonicalPaths
    )
    try store.withLock {
        try store.removeOwnedSocket(reservation.socketPath)
        try store.writeReservation(reservation)
    }
    print("NEW\t\(hash)\t\(token)")
}

private func execNeovim(path: String, arguments: [String], environment: [String: String]) throws -> Never {
    guard executable(path) else {
        throw LauncherError.message("Neovim is not executable: \(path)")
    }
    for (name, value) in environment {
        guard setenv(name, value, 1) == 0 else {
            throw LauncherError.message("Cannot prepare Neovim environment: \(errnoMessage())")
        }
    }
    _ = umask(0o077)

    let allArguments = [path] + arguments
    let duplicated = allArguments.map { strdup($0) }
    defer {
        for pointer in duplicated {
            free(pointer)
        }
    }
    var pointers = duplicated + [nil]
    execv(path, &pointers)
    throw LauncherError.message("Cannot start Neovim: \(errnoMessage())")
}

private let cleanupCommand = """
    lua vim.api.nvim_create_autocmd('VimLeavePre', { once = true, callback = function() local state = vim.g.usmon_nvim_launcher or {}; vim.fn.delete(vim.env.USMON_NVIM_LAUNCHER_RECORD); if vim.env.NVIM_LAUNCHER_TESTING ~= '1' and state.ghostty_window_id and state.ghostty_tab_id and state.ghostty_terminal_id then vim.fn.jobstart({ vim.env.USMON_NVIM_LAUNCHER_HELPER, 'close-after-exit', tostring(vim.fn.getpid()), state.ghostty_window_id, state.ghostty_tab_id, state.ghostty_terminal_id }, { detach = true }) end end })
"""

private func runReservation(
    _ reservation: Reservation,
    arguments: [String]
) throws -> Never {
    let metadataCommand = """
    let g:usmon_nvim_launcher = {'protocol': str2nr($USMON_NVIM_LAUNCHER_PROTOCOL), 'root': $USMON_NVIM_LAUNCHER_ROOT, 'token': $USMON_NVIM_LAUNCHER_TOKEN}
    """
    let serverArguments = [
        "--listen", reservation.socketPath,
        "--cmd", metadataCommand,
        "--cmd", cleanupCommand,
    ] + arguments
    try execNeovim(
        path: reservation.nvimPath,
        arguments: serverArguments,
        environment: [
            "USMON_NVIM_LAUNCHER_PROTOCOL": String(protocolVersion),
            "USMON_NVIM_LAUNCHER_ROOT": reservation.root,
            "USMON_NVIM_LAUNCHER_TOKEN": reservation.token,
            "USMON_NVIM_LAUNCHER_RECORD": reservation.recordPath,
            "USMON_NVIM_LAUNCHER_HELPER": try currentExecutablePath(),
        ]
    )
}

private func runRoot(rootHash: String, token: String, store: StateStore) throws -> Never {
    let reservation = try loadReservation(rootHash: rootHash, token: token, store: store)
    guard reservation.reusable else {
        throw LauncherError.message("The launch reservation is not a reusable root")
    }
    try runReservation(reservation, arguments: ["--", reservation.root])
}

private func runOnce(rootHash: String, token: String, store: StateStore) throws -> Never {
    let reservation = try loadReservation(rootHash: rootHash, token: token, store: store)
    guard !reservation.reusable else {
        throw LauncherError.message("The launch reservation is not a one-shot session")
    }
    let arguments = reservation.pendingPaths.isEmpty ? [] : ["--"] + reservation.pendingPaths
    try runReservation(reservation, arguments: arguments)
}

private func publishOnce(
    rootHash: String,
    token: String,
    windowID: String,
    tabID: String,
    terminalID: String,
    store: StateStore
) throws {
    guard let reservation = try store.readReservation(rootHash),
          reservation.token == token,
          !reservation.reusable else {
        throw LauncherError.message("One-shot Neovim launch reservation expired")
    }
    _ = try readySession(
        reservation: reservation,
        windowID: windowID,
        tabID: tabID,
        terminalID: terminalID,
        store: store
    )
    try store.withLock {
        try store.removeReservationRecordLocked(rootHash: rootHash, token: token)
    }
    print("READY")
}

private func validGhosttyIdentifier(_ value: String) -> Bool {
    !value.isEmpty
        && value.utf8.count <= 128
        && value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-"
        }
}

private func waitForProcessExit(_ processID: Int32) throws {
    let queue = kqueue()
    guard queue >= 0 else {
        throw LauncherError.message("Cannot observe Neovim process exit: \(errnoMessage())")
    }
    defer { close(queue) }

    var change = kevent(
        ident: UInt(processID),
        filter: Int16(EVFILT_PROC),
        flags: UInt16(EV_ADD | EV_ONESHOT),
        fflags: UInt32(NOTE_EXIT),
        data: 0,
        udata: nil
    )
    var event = kevent()
    var timeout = timespec(tv_sec: closeWaitTimeout, tv_nsec: 0)
    let result = kevent(queue, &change, 1, &event, 1, &timeout)
    guard result == 1 else {
        if result == 0 {
            throw LauncherError.message("Neovim did not fully exit before surface cleanup timed out")
        }
        throw LauncherError.message("Cannot observe Neovim process exit: \(errnoMessage())")
    }
    if event.flags & UInt16(EV_ERROR) != 0 {
        if event.data == ESRCH {
            return
        }
        throw LauncherError.message(
            "Cannot observe Neovim process exit: \(String(cString: strerror(Int32(event.data))))"
        )
    }
}

private func requestApplicationClose(token: String) throws {
    if ProcessInfo.processInfo.environment["NVIM_LAUNCHER_TESTING"] == "1" {
        print("CLOSE_REQUEST\t\(token)")
        return
    }
    let result = try runProcess(
        executablePath: "/usr/bin/open",
        arguments: [
            "-g",
            "-b",
            launcherBundleIdentifier,
            "nvim-launcher://close/\(token)",
        ]
    )
    guard !result.timedOut, result.status == 0 else {
        throw LauncherError.message("Launch Services could not deliver Ghostty surface cleanup")
    }
}

private func closeAfterExit(
    processID: Int32,
    windowID: String,
    tabID: String,
    terminalID: String,
    store: StateStore
) throws {
    guard processID > 1,
          validGhosttyIdentifier(windowID),
          validGhosttyIdentifier(tabID),
          validGhosttyIdentifier(terminalID) else {
        throw LauncherError.message("close-after-exit received invalid process or Ghostty identities")
    }

    try waitForProcessExit(processID)
    let token = try store.createCloseRequest(
        windowID: windowID,
        tabID: tabID,
        terminalID: terminalID
    )
    try requestApplicationClose(token: token)
}

private func usage() {
    FileHandle.standardError.write(Data("""
    Usage:
      nvim-launcher-helper route <nvim> [path ...]
      nvim-launcher-helper reserve <nvim> <root>
      nvim-launcher-helper publish <root-hash> <token> <window-id> <tab-id> <terminal-id>
      nvim-launcher-helper prepare-once <nvim> [path ...]
      nvim-launcher-helper publish-once <root-hash> <token> <window-id> <tab-id> <terminal-id>
      nvim-launcher-helper cancel <root-hash> <token>
      nvim-launcher-helper run-root <root-hash> <token>
      nvim-launcher-helper run-once <root-hash> <token>
      nvim-launcher-helper close-after-exit <pid> <window-id> <tab-id> <terminal-id>
      nvim-launcher-helper consume-close <token>
      nvim-launcher-helper canonicalize <path>
      nvim-launcher-helper match-root <path> <root ...>
    """.utf8))
}

private func runMain() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else {
        usage()
        throw LauncherError.message("Missing helper command")
    }
    let store = try StateStore()
    if command == "close-after-exit" {
        guard arguments.count == 5,
              let processID = Int32(arguments[1]) else {
            throw LauncherError.message(
                "close-after-exit requires a process ID and window, tab, and terminal IDs"
            )
        }
        try closeAfterExit(
            processID: processID,
            windowID: arguments[2],
            tabID: arguments[3],
            terminalID: arguments[4],
            store: store
        )
        return
    }
    if command == "consume-close" {
        guard arguments.count == 2, isRootHash(arguments[1]) else {
            throw LauncherError.message("consume-close requires a valid one-time token")
        }
        let request = try store.consumeCloseRequest(arguments[1])
        print(
            "CLOSE\t\(request.ghosttyWindowID)\t\(request.ghosttyTabID)"
                + "\t\(request.ghosttyTerminalID)"
        )
        return
    }

    switch command {
    case "route":
        guard arguments.count >= 2 else {
            throw LauncherError.message("route requires a Neovim path")
        }
        try route(nvimPath: arguments[1], paths: Array(arguments.dropFirst(2)), store: store)
    case "reserve":
        guard arguments.count == 3 else {
            throw LauncherError.message("reserve requires a Neovim path and root")
        }
        try reserveRoot(nvimPath: arguments[1], path: arguments[2], store: store)
    case "prepare-once":
        guard arguments.count >= 2 else {
            throw LauncherError.message("prepare-once requires a Neovim path")
        }
        try prepareOnce(
            nvimPath: arguments[1],
            paths: Array(arguments.dropFirst(2)),
            store: store
        )
    case "publish":
        guard arguments.count == 6 else {
            throw LauncherError.message("publish requires root hash, token, window, tab, and terminal IDs")
        }
        guard isRootHash(arguments[1]) else {
            throw LauncherError.message("publish received an invalid root hash")
        }
        try publish(
            rootHash: arguments[1],
            token: arguments[2],
            windowID: arguments[3],
            tabID: arguments[4],
            terminalID: arguments[5],
            store: store
        )
    case "publish-once":
        guard arguments.count == 6 else {
            throw LauncherError.message(
                "publish-once requires root hash, token, window, tab, and terminal IDs"
            )
        }
        guard isRootHash(arguments[1]) else {
            throw LauncherError.message("publish-once received an invalid root hash")
        }
        try publishOnce(
            rootHash: arguments[1],
            token: arguments[2],
            windowID: arguments[3],
            tabID: arguments[4],
            terminalID: arguments[5],
            store: store
        )
    case "cancel":
        guard arguments.count == 3 else {
            throw LauncherError.message("cancel requires root hash and token")
        }
        guard isRootHash(arguments[1]) else {
            throw LauncherError.message("cancel received an invalid root hash")
        }
        try cancel(rootHash: arguments[1], token: arguments[2], store: store)
    case "run-root":
        guard arguments.count == 3 else {
            throw LauncherError.message("run-root requires root hash and token")
        }
        guard isRootHash(arguments[1]) else {
            throw LauncherError.message("run-root received an invalid root hash")
        }
        try runRoot(rootHash: arguments[1], token: arguments[2], store: store)
    case "run-once":
        guard arguments.count == 3 else {
            throw LauncherError.message("run-once requires root hash and token")
        }
        guard isRootHash(arguments[1]) else {
            throw LauncherError.message("run-once received an invalid root hash")
        }
        try runOnce(rootHash: arguments[1], token: arguments[2], store: store)
    case "canonicalize":
        guard arguments.count == 2 else {
            throw LauncherError.message("canonicalize requires one path")
        }
        print(Data(try canonicalItem(arguments[1]).path.utf8).base64EncodedString())
    case "match-root":
        guard arguments.count >= 3 else {
            throw LauncherError.message("match-root requires a path and at least one root")
        }
        let path = try canonicalItem(arguments[1]).path
        let roots = try arguments.dropFirst(2).map { try canonicalItem($0).path }
        print(bestRootIndex(path: path, roots: roots) ?? -1)
    default:
        usage()
        throw LauncherError.message("Unknown helper command: \(command)")
    }
}

@main
private enum LauncherMain {
    static func main() {
        do {
            try runMain()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            FileHandle.standardError.write(Data(("nvim-launcher-helper: " + message + "\n").utf8))
            exit(1)
        }
    }
}
