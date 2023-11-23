//
// Copyright (c) Vatsal Manot
//

import LargeLanguageModels
import Swallow

extension OpenAI {
    public struct Message: Codable, Hashable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case id
            case object
            case createdAt
            case threadID
            case role
            case content
            case assistantID
            case runID
            case fileIdentifiers = "file_ids"
            case metadata
        }
        
        public let id: String
        public let object: OpenAI.ObjectType
        public let createdAt: Int
        public let threadID: String
        public let role: OpenAI.ChatRole
        public let content: [OpenAI.Message.Content]
        public let assistantID: String?
        public let runID: String?
        public let fileIdentifiers: [String]?
        public let metadata: [String: String]?
    }
}
