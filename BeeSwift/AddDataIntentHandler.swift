//
//  AddDataIntentHandler.swift
//  BeeSwift
//
//  Created by Andrew Brett on 3/28/21.
//  Copyright © 2021 APB. All rights reserved.
//

import Foundation
import Intents
import BeeKit

@available(iOS 14.0, *)
class AddDataIntentHandler: NSObject, AddDataIntentHandling {
    func resolveValue(for intent: AddDataIntent) async -> AddDataValueResolutionResult {
        if let value = intent.value {
            return AddDataValueResolutionResult.success(with: value.doubleValue)
        } else {
            return AddDataValueResolutionResult.needsValue()
        }
    }
    
    func resolveGoal(for intent: AddDataIntent) async -> INStringResolutionResult {
        if let goalSlug = intent.goal {
            // TODO: We should validate this is a valid slug
            return INStringResolutionResult.success(with: goalSlug)
        } else {
            return INStringResolutionResult.needsValue()
        }
    }
    
    func confirm(intent: AddDataIntent) async -> AddDataIntentResponse {
        if intent.goal != nil && intent.value != nil {
            return AddDataIntentResponse(code: .ready, userActivity: nil)
        } else {
            return AddDataIntentResponse(code: .failure, userActivity: nil)
        }
    }

    func handle(intent: AddDataIntent,
              completion: @escaping (AddDataIntentResponse) -> Void) {
        guard let goalSlug = intent.goal else {
            completion(AddDataIntentResponse.failure(goal: ""))
            return
        }
        guard let value = intent.value else {
            completion(AddDataIntentResponse.failure(goal: goalSlug))
            return
        }
        let comment = intent.comment ?? ""

        Task {
            do {
                let _ = try await ServiceLocator.requestManager.addDatapoint(urtext: "^ \(value) \"\(comment)\"", slug: goalSlug)
                completion(AddDataIntentResponse.success(goal: goalSlug))
            } catch {
                completion(AddDataIntentResponse.failure(goal: goalSlug))
            }
        }
    }
}
