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
public class AddDataIntentHandler: INExtension, AddDataIntentHandling {
    @available(iOSApplicationExtension 14.0, watchOSApplicationExtension 7.0, *)
    public func resolveValue(for intent: AddDataIntent, with completion: @escaping (AddDataValueResolutionResult) -> Void) {
        print("foo")
    }
    @available(iOSApplicationExtension 14.0, watchOSApplicationExtension 7.0, *)
    public func resolveGoal(for intent: AddDataIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        print("foo")
    }
    
    override public func handler(for intent: INIntent) -> Any? {
        return AddDataIntentHandler()
    }
    @available(iOSApplicationExtension 14.0, watchOSApplicationExtension 7.0, *)
    public func confirm(intent: AddDataIntent,
               completion: @escaping (AddDataIntentResponse) -> Void) {
        completion(AddDataIntentResponse(code: .ready, userActivity: nil))
    }
    @available(iOSApplicationExtension 14.0, watchOSApplicationExtension 7.0, *)
    public func handle(intent: AddDataIntent,
              completion: @escaping (AddDataIntentResponse) -> Void) {
        let params = ["urtext": "^ 1", "requestid": UUID().uuidString]
        
//        RequestManager.addDatapoint(urtext: "^ 1", slug: intent.goal!) { (response) in
//            completion(AddDataIntentResponse.success(goal: intent.goal!))
//        } errorHandler: { (error, errorMessage) in
//            completion(AddDataIntentResponse.failure(goal: intent.goal!))
//        }
    }
}
