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
        if let goal = intent.goal {
            // TODO: We should validate this is a valid slug
            return INStringResolutionResult.success(with: goal)
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
        guard let goal = intent.goal else {
            completion(AddDataIntentResponse.failure(goal: ""))
            return
        }
        guard let value = intent.value else {
            completion(AddDataIntentResponse.failure(goal: goal))
            return
        }
                
        RequestManager.addDatapoint(urtext: "^ \(value)", slug: goal) { (response) in
            completion(AddDataIntentResponse.success(goal: goal))
        } errorHandler: { (error, errorMessage) in
            completion(AddDataIntentResponse.failure(goal: goal))
        }
    }
}
