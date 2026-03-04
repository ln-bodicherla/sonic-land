import Foundation
import Network

/// Unix domain socket IPC server for communication with sonicctl.
final class IPCServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let socketPath = "/tmp/com.sonicland.sock"

    var commandHandler: ((IPCCommand) -> IPCResponse)?

    func start() {
        // Remove stale socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        do {
            let params = NWParameters()
            params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
            params.requiredLocalEndpoint = NWEndpoint.unix(path: socketPath)

            listener = try NWListener(using: params)

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    NSLog("[SonicLand] IPC server listening on \(self.socketPath)")
                case .failed(let error):
                    NSLog("[SonicLand] IPC server failed: \(error)")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.start(queue: .main)
        } catch {
            NSLog("[SonicLand] Failed to create IPC listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        try? FileManager.default.removeItem(atPath: socketPath)
        NSLog("[SonicLand] IPC server stopped.")
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                self?.connections.removeAll { $0 === connection }
            }
        }

        connection.start(queue: .main)
        receiveData(from: connection)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.processData(data, on: connection)
            }

            if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveData(from: connection)
            }
        }
    }

    private func processData(_ data: Data, on connection: NWConnection) {
        // Support newline-delimited JSON
        guard let string = String(data: data, encoding: .utf8) else { return }

        let lines = string.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let command = IPCCommand.parse(from: lineData) else {
                let errorResponse = IPCResponse(status: .error, message: "Invalid command")
                sendResponse(errorResponse, on: connection)
                continue
            }

            let response = commandHandler?(command) ?? IPCResponse(status: .error, message: "No handler")
            sendResponse(response, on: connection)
        }
    }

    private func sendResponse(_ response: IPCResponse, on connection: NWConnection) {
        do {
            var data = try JSONEncoder().encode(response)
            data.append(contentsOf: "\n".utf8)
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    NSLog("[SonicLand] Failed to send IPC response: \(error)")
                }
            })
        } catch {
            NSLog("[SonicLand] Failed to encode IPC response: \(error)")
        }
    }
}
