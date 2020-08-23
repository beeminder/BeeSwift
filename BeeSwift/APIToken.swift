//
//  APIToken.swift
//  BeeSwift
//
//  Created by krugerk on 22.08.20.
//  Copyright © 2020 krugerk. All rights reserved.
//

import Foundation

struct ApiToken: Codable {
    let type: ApiTokenType
    let value: String
    
    init(type: ApiTokenType, token: String) {
        self.type = type
        self.value = token
    }
}

enum ApiTokenType: String, Codable {
    
    case AuthenticationToken = "auth_token"
    case AccessToken = "access_token"
    
    init?(_ tokenTypeString: String) {
        switch tokenTypeString {
        case ApiTokenType.AuthenticationToken.rawValue:
            self = .AuthenticationToken
        case ApiTokenType.AccessToken.rawValue:
            self = .AccessToken
        default:
            fatalError("unexpected string: \(tokenTypeString)")
        }
    }
}
