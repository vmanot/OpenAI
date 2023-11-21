//
// Copyright (c) Vatsal Manot
//

import Foundation
import Swallow

public struct Tiktoken {
    private init() {
        
    }
    
    public static func encoding(
        for model: OpenAI.Model
    ) async throws -> Encoding? {
        guard let vocab = model.vocab else {
            return nil
        }
        
        let encoder = await loadRanks(vocab)
        let regex = try NSRegularExpression(pattern: vocab.pattern)
        let encoding = Encoding(
            name: model.rawValue,
            regex: regex,
            mergeableRanks: encoder,
            specialTokens: vocab.specialTokens
        )
        
        return encoding
    }
    
    public static func loadRanks(
        _ vocab: BPEVocabulary
    ) async -> [[UInt8]: Int] {
        if ["gpt2", "gpt3"].contains(vocab.name) {
            return await Load.dataGymToMergeableBpeRanks(vocabBpeFile: vocab.url)
        } else {
            return await Load.loadTiktokenBpe(url: vocab.url)
        }
    }
}
