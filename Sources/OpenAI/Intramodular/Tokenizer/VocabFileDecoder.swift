//
// Copyright (c) Vatsal Manot
//

import Foundation
import Swallow

struct VocabFileDecoder {
    func decode(_ data: Data) -> [[UInt8]: Int] {
        guard let decoded = String(data: data, encoding: .utf8) else { return [:] }
        var result: [[UInt8]: Int] = .init()
        decoded.split(separator: "\n").forEach({
            let lineSplit = $0.split(separator: " ")
            guard let first = lineSplit.first,
                  let key = try? String(from: String(first), using: .base64),
                  let value = lineSplit.last
            else {
                return
            }
            result[key.utf16AsUInt8Array] = Int(value)
        })
        return result
    }
}

extension String {
    fileprivate var utf16AsUInt8Array: [UInt8] {
        utf16.map({ UInt8($0) })
    }
}
