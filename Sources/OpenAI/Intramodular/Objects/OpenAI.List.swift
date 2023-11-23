//
// Copyright (c) Vatsal Manot
//

import NetworkKit
import Swift

extension OpenAI {
    public class List<T: Object & Sendable>: Object {
        private enum CodingKeys: String, CodingKey {
            case data
        }
        
        public let data: [T]
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.data = try container.decode(forKey: .data)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
        }
    }
}
