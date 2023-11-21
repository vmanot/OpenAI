//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Foundation
import Merge
import NetworkKit
import Swallow

extension OpenAI {
    public final class ChatCompletionSession: Logging {
        private let taskQueue = TaskQueue()
        private let client: APIClient
        private let session: URLSession
        private let sessionDelegate = _URLSessionDataDelegate()
                
        public init(client: APIClient) {
            self.client = client

            session = URLSession(
                configuration: URLSessionConfiguration.default,
                delegate: sessionDelegate,
                delegateQueue: nil
            )
        }
    }
}

extension OpenAI.ChatCompletionSession {
    public func complete(
        messages: [OpenAI.ChatMessage],
        model: OpenAI.Model,
        parameters: OpenAI.APIClient.ChatCompletionParameters
    ) async throws -> AsyncThrowingStream<OpenAI.ChatCompletionSession.Message, Error> {
        try await _sendMessageAndStreamResponse(
            messages: messages,
            model: model,
            parameters: parameters
        )
    }
}

extension OpenAI.ChatCompletionSession {
    private static let encoder = JSONEncoder(keyEncodingStrategy: .convertToSnakeCase)
    private static let decoder = JSONDecoder(keyDecodingStrategy: .convertFromSnakeCase)._polymorphic()
    
    private var key: String {
        get throws {
            try client.interface.configuration.apiKey.unwrap()
        }
    }
    
    private func makeURLRequest(data: Data) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = data
        
        return request
    }
    
    private func _complete(
        messages: [OpenAI.ChatMessage],
        model: OpenAI.Model,
        parameters: OpenAI.APIClient.ChatCompletionParameters
    ) async throws -> URLSession.AsyncBytes {
        let chatRequest = OpenAI.API.RequestBodies.CreateChatCompletion(
            messages: messages,
            model: model,
            parameters: parameters,
            stream: true
        )
        
        let data = try Self.encoder.encode(chatRequest)
        let request = try makeURLRequest(data: data)
        
        let (bytes, response) = try await Task.retrying(maxRetryCount: 1) {
            try await Task(timeout: .seconds(3)) {
                try await self.session.bytes(for: request, delegate: self.sessionDelegate)
            }
            .value
        }
        .value
        
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw _Error.responseError
        }
        
        return bytes
    }
    
    public func _sendMessageAndStreamResponse(
        messages: [OpenAI.ChatMessage],
        model: OpenAI.Model,
        parameters: OpenAI.APIClient.ChatCompletionParameters
    ) async throws -> AsyncThrowingStream<Message, Error> {
        let bytes = try await _complete(
            messages: messages,
            model: model,
            parameters: parameters
        )
        
        var responseMessage = Message(
            id: .random(),
            role: .assistant,
            content: ""
        )
        
        return _stream(bytes: bytes) { response in
            let delta = try response.choices.first.unwrap().delta
            
            if let deltaContent = delta.content {
                responseMessage.content += deltaContent
            }
            
            return responseMessage
        }
    }
    
    private func _stream<T>(
        bytes: URLSession.AsyncBytes,
        onEvent: @escaping (OpenAI.ChatCompletionChunk) throws -> T
    ) -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.starts(with: "data: [DONE]") {
                            continuation.finish()
                            
                            return
                        } else if line.starts(with: "data: ") {
                            let rest = line.index(line.startIndex, offsetBy: 6)
                            let data: Data = line[rest...].data(using: .utf8)!
                            
                            do {
                                let response = try Self.decoder.decode(OpenAI.ChatCompletionChunk.self, from: data)
                                
                                continuation.yield(try onEvent(response))
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        } else {
                            continuation.finish(throwing: _Error.streamIsInvalid)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
                
                throw _Error.streamIsInvalid
            }
        }
    }
}

extension OpenAI.ChatCompletionSession {
    public struct Message: Codable, Hashable, Identifiable {
        public typealias ID = _TypeAssociatedID<Self, UUID>
        
        public enum SenderRole: String, Codable, Hashable {
            case user
            case assistant
        }
        
        public var id: ID
        public var role: OpenAI.ChatRole
        public var content: String
        
        public init(id: ID, role: OpenAI.ChatRole, content: String) {
            self.id = id
            self.role = role
            self.content = content
        }
        
        public static func system(
            content: String
        ) -> Self {
            Self(id: .random(), role: .system, content: content)
        }
        
        public static func user(
            id: ID,
            content: String
        ) -> Self {
            Self(id: id, role: .user, content: content)
        }
    }
}

extension OpenAI.ChatCompletionSession {
    fileprivate class _URLSessionDataDelegate: NSObject, Foundation.URLSessionDataDelegate {
        public func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive data: Data
        ) {
            
        }
        
        public func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse
        ) async -> URLSession.ResponseDisposition {
            .allow
        }
    }
}

extension OpenAI.ChatCompletionSession {
    public enum _Error: Error {
        case responseError
        case streamIsInvalid
    }
}
