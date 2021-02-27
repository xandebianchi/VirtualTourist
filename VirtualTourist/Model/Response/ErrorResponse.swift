//
//  ErrorResponse.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 18/02/21.
//

struct ErrorResponse: Codable {
    var stat: String
    var code: Int
    var message: String
}
