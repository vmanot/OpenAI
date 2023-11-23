//
// Copyright (c) Vatsal Manot
//


import Foundation

extension OpenAI {
    public struct Run: Hashable, Sendable {
        public enum Status: String, Codable, Hashable, Sendable {
            case queued
            case inProgress = "in_progress"
            case requiresAction = "requires_action"
            case cancelling
            case cancelled
            case failed
            case completed
            case expired
        }
        
        public let id: String
        public let object: OpenAI.ObjectType
        public let createdAt: Int
        public let threadID: String
        public let assistantID: String
        public let status: Status
        public let requiredAction: RequiredAction?
        public let lastError: LastError?
        public let expiresAt: Int
        public let startedAt: Int?
        public let cancelledAt: Int?
        public let failedAt: Int?
        public let completedAt: Int?
        public let model: String
        public let instructions: String
        public let tools: [OpenAI.Tool]
        public let fileIdentifiers: [String]
        public let metadata: [String: String]
    }
}

extension OpenAI.Run.Status {
    public var isTerminal: Bool {
        switch self {
            case .queued:
                return false
            case .inProgress:
                return false
            case .requiresAction:
                return false
            case .cancelling:
                return false
            case .cancelled:
                return true
            case .failed:
                return true
            case .completed:
                return true
            case .expired:
                return true
        }
    }
}

// MARK: - Conformances

extension OpenAI.Run: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt
        case threadID
        case assistantID
        case status
        case requiredAction
        case lastError
        case expiresAt
        case startedAt
        case cancelledAt
        case failedAt
        case completedAt
        case model
        case instructions
        case fileIdentifiers = "file_ids"
        case tools
        case metadata
    }
}

// MARK: - Auxiliary

extension OpenAI.Run {
    public struct RequiredAction: Codable, Hashable, Sendable {
        public enum RequiredActionType: String, Codable, Hashable, Sendable {
            case submitToolOutputs = "submit_tool_outputs"
        }
        
        public let type: RequiredActionType
        public let submitToolsOutputs: SubmitToolOutput
        
        public struct SubmitToolOutput: Codable, Hashable, Sendable {
            public let toolCalls: [OpenAI.ToolCall]
        }
    }
    
    public struct LastError: Codable, Hashable, Sendable {
        let code: String
        let message: String
    }
}
