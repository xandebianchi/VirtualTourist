//
//  Photo.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 18/02/21.
//

struct Photo: Codable {
    var id: String
    var owner: String
    var secret: String
    var server: String
    var farm: Int
    var title: String
    var ispublic: Int
    var isfriend: Int
    var isfamily: Int
    var url_m: String
}
