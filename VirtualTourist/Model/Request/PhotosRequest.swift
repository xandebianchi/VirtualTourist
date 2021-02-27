//
//  Photos.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 18/02/21.
//

struct PhotosRequest: Codable {
    let photos: Photos
    let stat: String
    
    enum CodingKeys: String, CodingKey {
       case photos
       case stat
    }
}

struct Photos: Codable {
    let page: Int
    let pages: Int
    let perPage: Int
    let total: String
    let photoList: [Photo]
    
    enum CodingKeys: String, CodingKey {
        case page
        case pages
        case perPage = "perpage"
        case total
        case photoList = "photo"
    }
}
