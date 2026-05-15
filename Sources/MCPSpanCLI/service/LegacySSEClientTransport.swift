import EventSource
import Foundation
import Logging
import MCP

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor LegacySSEClientTransport: Transport {
    let endpoint: URL
    nonisolated let logger: Logger

    private let session: URLSession
    private let headers: [String: String]
    private var isConnected = false
    private var eventTask: Task<Void, Never>?
    private var endpointTimeoutTask: Task<Void, Never>?
    private var messageEndpoint: URL?
    private var endpointWaiters: [CheckedContinuation<URL, Error>] = []
    private let endpointTimeout: Duration
    private let messageStream: AsyncThrowingStream<Data, Swift.Error>
    private let messageContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation

    init(
        endpoint: URL,
        headers: [String: String] = [:],
        endpointTimeout: Duration = .seconds(10),
        logger: Logger? = nil
    ) {
        self.endpoint = endpoint
        self.session = URLSession(configuration: .default)
        self.headers = headers
        self.endpointTimeout = endpointTimeout
        self.logger =
            logger
            ?? Logger(
                label: "mcp.transport.legacy-sse.client",
                factory: { _ in SwiftLogNoOpLogHandler() }
            )

        var continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    func connect() async throws {
        guard !isConnected else {
            return
        }

        isConnected = true
        eventTask = Task { await readEventStream() }
        endpointTimeoutTask = Task { [endpointTimeout] in
            try? await Task.sleep(for: endpointTimeout)
            failEndpointWaitersIfNeeded()
        }

        do {
            _ = try await waitForMessageEndpointSignal()
            endpointTimeoutTask?.cancel()
            endpointTimeoutTask = nil
        } catch {
            await disconnect()
            throw error
        }
    }

    func disconnect() async {
        guard isConnected else {
            return
        }

        isConnected = false
        eventTask?.cancel()
        eventTask = nil
        endpointTimeoutTask?.cancel()
        endpointTimeoutTask = nil
        session.invalidateAndCancel()
        messageContinuation.finish()
        resumeEndpointWaiters(
            throwing: MCPError.internalError("Legacy SSE transport disconnected")
        )
    }

    func send(_ data: Data) async throws {
        guard isConnected else {
            throw MCPError.internalError("Transport not connected")
        }

        let postURL = try await waitForMessageEndpointSignal()
        var request = URLRequest(url: postURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        applyHeaders(to: &request)
        request.httpBody = data

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.internalError("Invalid legacy SSE POST response")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw MCPError.internalError(
                "Legacy SSE POST failed: HTTP \(httpResponse.statusCode)"
            )
        }
    }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        messageStream
    }

    private func readEventStream() async {
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
            applyHeaders(to: &request)

            let (stream, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw MCPError.internalError("Invalid legacy SSE response")
            }

            guard httpResponse.statusCode == 200 else {
                throw MCPError.internalError(
                    "Legacy SSE connection failed: HTTP \(httpResponse.statusCode)"
                )
            }

            for try await event in stream.events {
                if Task.isCancelled {
                    break
                }

                handle(event: event)
            }

            if !Task.isCancelled {
                throw MCPError.internalError("Legacy SSE stream closed")
            }
        } catch {
            if !Task.isCancelled {
                messageContinuation.finish(throwing: error)
                resumeEndpointWaiters(throwing: error)
            }
        }
    }

    private func handle(event: EventSource.Event) {
        if event.event == "endpoint" {
            guard let url = resolveMessageEndpoint(event.data) else {
                resumeEndpointWaiters(
                    throwing: MCPError.internalError(
                        "Legacy SSE server sent an invalid message endpoint: \(event.data)"
                    )
                )
                return
            }

            messageEndpoint = url
            resumeEndpointWaiters(returning: url)
            return
        }

        guard !event.data.isEmpty, let data = event.data.data(using: .utf8) else {
            return
        }

        messageContinuation.yield(data)
    }

    private func resolveMessageEndpoint(_ value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmedValue), url.scheme != nil {
            return url
        }

        return URL(string: trimmedValue, relativeTo: endpoint)?.absoluteURL
    }

    private func waitForMessageEndpointSignal() async throws -> URL {
        if let messageEndpoint {
            return messageEndpoint
        }

        return try await withCheckedThrowingContinuation { continuation in
            endpointWaiters.append(continuation)
        }
    }

    private func failEndpointWaitersIfNeeded() {
        guard messageEndpoint == nil, !endpointWaiters.isEmpty else {
            return
        }

        resumeEndpointWaiters(
            throwing: MCPError.internalError("Timed out waiting for legacy SSE message endpoint")
        )
    }

    private func resumeEndpointWaiters(returning url: URL) {
        let waiters = endpointWaiters
        endpointWaiters.removeAll()

        for waiter in waiters {
            waiter.resume(returning: url)
        }
    }

    private func resumeEndpointWaiters(throwing error: Error) {
        let waiters = endpointWaiters
        endpointWaiters.removeAll()

        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }

    private func applyHeaders(to request: inout URLRequest) {
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }
}
