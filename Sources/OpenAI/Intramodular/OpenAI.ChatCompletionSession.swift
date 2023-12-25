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
        private let queue = DispatchQueue()
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
    
    private func makeURLRequest(
        data: Data
    ) throws -> URLRequest {
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
    ) async throws -> AnyPublisher<OpenAI.ChatMessage, Error> {
        var _self: OpenAI.ChatCompletionSession! = self
        
        let chatRequest = OpenAI.API.RequestBodies.CreateChatCompletion(
            messages: messages,
            model: model,
            parameters: parameters,
            stream: true
        )
        
        let data: Data = try Self.encoder.encode(chatRequest)
        let request: URLRequest = try makeURLRequest(data: data)
        
        let responseMessage = _LockedState(
            initialState: OpenAI.ChatMessage(
                role: .assistant,
                content: ""
            )
        )
        
        let eventSource = SSE.EventSource(request: request)
          
        self.eventSource = eventSource
                
        return eventSource
            .receive(on: queue)
            .tryMap({ event -> ChatCompletionEvent? in
                switch event {
                    case .open:
                        return nil
                    case .message(let message):
                        if let data: Data = message.data?.data(using: .utf8) {
                            guard message.data != "[DONE]" else {
                                _self.eventSource?.shutdown()
                                
                                return .stop
                            }
                            
                            let completion = try Self.decoder.decode(OpenAI.ChatCompletionChunk.self, from: data)
                            let choice: OpenAI.ChatCompletionChunk.Choice = try completion.choices.toCollectionOfOne().first
                            let delta = choice.delta
                            
                            if let deltaContent = delta.content {
                                try responseMessage.withLock {
                                    try $0.body += deltaContent
                                }
                            }
                            
                            return ChatCompletionEvent.message(responseMessage.withLock({ $0 }))
                        } else {
                            assertionFailure()
                            
                            return nil
                        }
                    case .error(let error):
                        runtimeIssue(error)
                        
                        _self.eventSource = nil
                        
                        return nil
                    case .closed:
                        _self.eventSource = nil
                        _self = nil
                        
                        return nil
                }
            })
            .compactMap({ (value: ChatCompletionEvent?) -> ChatCompletionEvent? in
                value
            })
            .tryMap({ try $0.message.unwrap() })
            .onSubscribe(perform: eventSource.connect)
            .eraseToAnyPublisher()
    }
    
    enum ChatCompletionEvent: Hashable {
        case message(OpenAI.ChatMessage)
        case stop
        
        var message: OpenAI.ChatMessage? {
            guard case .message(let message) = self else {
                return nil
            }
            
            return message
        }
    }
}
