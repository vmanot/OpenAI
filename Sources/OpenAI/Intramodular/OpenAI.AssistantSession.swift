//
// Copyright (c) Vatsal Manot
//

import NetworkKit
import Swallow

extension OpenAI {
    public final class AssistantChatSession: ObservableObject {
        private let taskQueue = ThrowingTaskQueue()
        
        public let client: APIClient
        public let assistantID: String
        
        @MainActor
        @Published private(set) var _thread: OpenAI.Thread?
        
        @MainActor
        public var thread: OpenAI.Thread {
            get async throws {
                if let _thread {
                    return _thread
                } else {
                    return try await taskQueue.perform {
                        try await _createThread(messages: [])
                    }
                }
            }
        }
        
        @MainActor
        @Published public private(set) var messages: [OpenAI.Message] = []
        
        public init(
            client: APIClient,
            assistantID: String
        ) {
            self.client = client
            self.assistantID = assistantID
            
            taskQueue.addTask {
                try await self._fetchAllMessages()
            }
        }
    }
}

extension OpenAI.AssistantChatSession {
    public func send(
        _ message: OpenAI.ChatMessage
    ) async throws {
        try await self.taskQueue.perform {
            try await self._createMessageAndSend(message)
        }
    }
    
    public func send(
        _ message: String
    ) async throws {
        try await self.send(OpenAI.ChatMessage(role: .user, body: message))
    }
    
    public func update() async throws {
        try await self._fetchAllMessages()
    }
}

extension OpenAI.AssistantChatSession {
    @MainActor
    private func _createThread(
        messages: [OpenAI.ChatMessage]
    ) async throws -> OpenAI.Thread {
        assert(messages.isEmpty)
        
        let thread = try await client.run(\.createThread, with: .init(messages: messages, metadata: [:]))
        
        self._thread = thread
        
        return thread
    }
    
    @MainActor
    public func _createMessageAndSend(
        _ message: OpenAI.ChatMessage
    ) async throws {
        if _thread != nil && messages.isEmpty {
            try await _fetchAllMessages()
        }
        
        let thread = try await self.thread
        let message = try await client.run(\.createMessageForThread, with: (thread: thread.id, requestBody: .init(from: message)))
        
        self.messages.append(message)
    }
    
    @MainActor
    private func _fetchAllMessages() async throws {
        guard _thread != nil else {
            return
        }
        
        let listMessagesResponse = try await self.client.run(
            \.listMessagesForThread,
             with: thread.id
        )
        
        assert(listMessagesResponse.hasMore == false)
        
        self.messages = listMessagesResponse.data.sorted(by: { $0.createdAt < $1.createdAt })
    }
}
