//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import Diagnostics
import LargeLanguageModels
import Swallow

extension OpenAI {
    public enum ChatRole: String, Codable, Hashable, Sendable {
        case system
        case user
        case assistant
        case function
        
        public init(from role: AbstractLLM.ChatRole) {
            switch role {
                case .system:
                    self = .system
                case .user:
                    self = .user
                case .assistant:
                    self = .assistant
                case .other(.function):
                    self = .function
            }
        }
    }
}
