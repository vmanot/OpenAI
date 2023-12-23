//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import Diagnostics
import Foundation
import Merge
import NetworkKit
import Swallow

extension OpenAI {
    public final class ChatCompletionSession: Logging {
        private let taskQueue = TaskQueue()
        private let client: APIClient
        private var eventSource: SSE.EventSource?
        
        public init(client: APIClient) {
            self.client = client
        }
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
    
    public func complete(
        messages: [OpenAI.ChatMessage],
        model: OpenAI.Model,
        parameters: OpenAI.APIClient.ChatCompletionParameters
    ) async throws -> AsyncThrowingStream<OpenAI.ChatMessage, Error> {
        let chatRequest = OpenAI.API.RequestBodies.CreateChatCompletion(
            messages: messages,
            model: model,
            parameters: parameters,
            stream: true
        )
        
        let data = try Self.encoder.encode(chatRequest)
        let request = try makeURLRequest(data: data)
        
        let responseMessage = _LockedState(
            initialState: OpenAI.ChatMessage(
                role: .assistant,
                content: ""
            )
        )
        
        let eventSource = SSE.EventSource(request: request)
        
        self.eventSource = eventSource
        
        defer {
            eventSource.connect()
        }
        
        return eventSource.tryMap({ event -> OpenAI.ChatMessage? in
            switch event {
                case .open:
                    return nil
                case .message(let message):
                    if let data = message.data?.data(using: .utf8) {
                        let completion = try Self.decoder.decode(OpenAI.ChatCompletionChunk.self, from: data)
                        let delta = try completion.choices.toCollectionOfOne().first.delta
                        
                        if let deltaContent = delta.content {
                           try responseMessage.withLock {
                                try $0.body += deltaContent
                            }
                        }
                        
                        return responseMessage.withLock({ $0 })
                    } else {
                        assertionFailure()
                        
                        return nil
                    }
                case .error(let error):
                    runtimeIssue(error)
                    
                    return nil
                case .closed:
                    return nil
            }
        })
        .compactMap({ $0 })
        .values
        .eraseToThrowingStream()
    }
}
