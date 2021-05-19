//
//  AddDataIntentHandler.swift
//  BeeSwift
//
//  Created by Andrew Brett on 3/28/21.
//  Copyright © 2021 APB. All rights reserved.
//

import Foundation
import Intents

@available(iOS 14.0, *)
class IntentHandler: INExtension, AddDataIntentHandling {
    func provideGoalOptionsCollection(for intent: AddDataIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let slugs : [NSString] = ["btime"]
        completion(INObjectCollection(items: slugs), nil)
    }
    
    func resolveValue(for intent: AddDataIntent, with completion: @escaping (AddDataValueResolutionResult) -> Void) {
        print("foo")
    }
    
    func resolveGoal(for intent: AddDataIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        print("foo")
    }
    
    override func handler(for intent: INIntent) -> Any? {
        return AddDataIntentHandler()
        guard intent is AddDataIntent else {
            fatalError("Unhandled intent type: \(intent)")
        }
        return AddDataIntentHandler()
    }
    
    func confirm(intent: AddDataIntent,
               completion: @escaping (AddDataIntentResponse) -> Void) {
        completion(AddDataIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: AddDataIntent,
              completion: @escaping (AddDataIntentResponse) -> Void) {
        let params = ["urtext": "^ 1", "requestid": UUID().uuidString]
        
        RequestManager.addDatapoint(urtext: "^ 1", slug: intent.goal!) { (response) in
            completion(AddDataIntentResponse.success(goal: intent.goal!))
        } errorHandler: { (error, errorMessage) in
            completion(AddDataIntentResponse.failure(goal: intent.goal!))
        }
    }
}
