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
    func resolveValue(for intent: AddDataIntent, with completion: @escaping (AddDataValueResolutionResult) -> Void) {
        print("foo")
    }
    
    func resolveGoal(for intent: AddDataIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        print("foo")
    }
    
    func confirm(intent: AddDataIntent,
               completion: @escaping (AddDataIntentResponse) -> Void) {
        completion(AddDataIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: AddDataIntent,
              completion: @escaping (AddDataIntentResponse) -> Void) {
        guard let datapointValue = intent.value else { return }
        
        RequestManager.addDatapoint(urtext: "^ \(datapointValue)", slug: intent.goal!) { (response) in
            completion(AddDataIntentResponse.success(goal: intent.goal!))
        } errorHandler: { (error, errorMessage) in
            completion(AddDataIntentResponse.failure(goal: intent.goal!))
        }
        completion(AddDataIntentResponse(code: .continueInApp, userActivity: nil))
    }
}
