import Foundation
import MCP

#if canImport(System)
import System
#else
import SystemPackage
#endif

enum MCPClientEndpoint: Sendable {
    case stdio(
        command: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryPath: String? = nil
    )
    case http(url: URL, streaming: Bool = true)
}

struct MCPServerSnapshot: Sendable {
    let initializeResult: Initialize.Result
    let tools: [Tool]
}

protocol MCPClientServing {
    func withClient<T: Sendable>(
        endpoint: MCPClientEndpoint,
        operation: @Sendable (Client) async throws -> T
    ) async throws -> T

    func listTools(endpoint: MCPClientEndpoint) async throws -> [Tool]

    func fetchServerSnapshot(endpoint: MCPClientEndpoint) async throws -> MCPServerSnapshot

    func callTool(
        endpoint: MCPClientEndpoint,
        name: String,
        arguments: [String: Value]
    ) async throws -> CallTool.Result
}

struct MCPClientService: MCPClientServing {
    let clientName: String
    let clientVersion: String

    init(
        clientName: String = "MCPSpanCLI",
        clientVersion: String = BuildInfo.version
    ) {
        self.clientName = clientName
        self.clientVersion = clientVersion
    }

    func withClient<T: Sendable>(
        endpoint: MCPClientEndpoint,
        operation: @Sendable (Client) async throws -> T
    ) async throws -> T {
        let session = try await openSession(for: endpoint)

        do {
            let result = try await operation(session.client)
            await session.close()
            return result
        } catch {
            await session.close()
            throw error
        }
    }

    func listTools(endpoint: MCPClientEndpoint) async throws -> [Tool] {
        try await withClient(endpoint: endpoint) { client in
            let (tools, _) = try await client.listTools()
            return tools
        }
    }

    func fetchServerSnapshot(endpoint: MCPClientEndpoint) async throws -> MCPServerSnapshot {
        let connection = try await openConnection(for: endpoint)

        do {
            let (tools, _) = try await connection.session.client.listTools()
            let snapshot = MCPServerSnapshot(
                initializeResult: connection.initializeResult,
                tools: tools
            )
            await connection.session.close()
            return snapshot
        } catch {
            await connection.session.close()
            throw error
        }
    }

    func callTool(
        endpoint: MCPClientEndpoint,
        name: String,
        arguments: [String: Value] = [:]
    ) async throws -> CallTool.Result {
        try await withClient(endpoint: endpoint) { client in
            let (content, isError) = try await client.callTool(
                name: name,
                arguments: arguments
            )
            return .init(content: content, isError: isError)
        }
    }

    private func openSession(for endpoint: MCPClientEndpoint) async throws -> MCPClientSession {
        let connection = try await openConnection(for: endpoint)
        return connection.session
    }

    private func openConnection(for endpoint: MCPClientEndpoint) async throws -> MCPClientConnection {
        let client = Client(name: clientName, version: clientVersion)

        switch endpoint {
        case let .http(url, streaming):
            let transport = HTTPClientTransport(endpoint: url, streaming: streaming)
            let initializeResult = try await client.connect(transport: transport)

            return MCPClientConnection(
                session: MCPClientSession(
                    client: client,
                    transport: transport
                ),
                initializeResult: initializeResult
            )

        case let .stdio(command, arguments, environment, currentDirectoryPath):
            let process = Process()
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            if command.contains("/") {
                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [command] + arguments
            }

            if !environment.isEmpty {
                process.environment = ProcessInfo.processInfo.environment.merging(environment) {
                    _, new in new
                }
            }

            if let currentDirectoryPath {
                process.currentDirectoryURL = URL(
                    fileURLWithPath: currentDirectoryPath,
                    isDirectory: true
                )
            }

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            let transport = StdioTransport(
                input: FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor),
                output: FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
            )

            let initializeResult = try await client.connect(transport: transport)

            return MCPClientConnection(
                session: MCPClientSession(
                    client: client,
                    transport: transport,
                    process: process,
                    inputPipe: inputPipe,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe
                ),
                initializeResult: initializeResult
            )
        }
    }
}

private struct MCPClientConnection {
    let session: MCPClientSession
    let initializeResult: Initialize.Result
}

private struct MCPClientSession {
    let client: Client
    let transport: any Transport
    let process: Process?
    let inputPipe: Pipe?
    let outputPipe: Pipe?
    let errorPipe: Pipe?

    init(
        client: Client,
        transport: any Transport,
        process: Process? = nil,
        inputPipe: Pipe? = nil,
        outputPipe: Pipe? = nil,
        errorPipe: Pipe? = nil
    ) {
        self.client = client
        self.transport = transport
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
    }

    func close() async {
        await transport.disconnect()
        closePipes()
        stopProcess()
    }

    private func closePipes() {
        inputPipe?.fileHandleForReading.closeFile()
        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.closeFile()
        outputPipe?.fileHandleForWriting.closeFile()
        errorPipe?.fileHandleForReading.closeFile()
        errorPipe?.fileHandleForWriting.closeFile()
    }

    private func stopProcess() {
        guard let process else {
            return
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }
}
