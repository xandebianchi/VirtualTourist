//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 18/02/21.
//

import Foundation

class FlickrClient {
    
    // MARK: - Static variables
    
    static let apiKey = "908fdff79dd5a7631b9bb74327eaa531"
    static let secretKey = "62c8ae3b0e6e2b6a"
    static let pageSize = 20
    
    // MARK: - Declarations
    
    enum Endpoints {
        static let base = "https://www.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(FlickrClient.apiKey)&media=Photo&per_page=\(FlickrClient.pageSize)&extras=url_m&format=json"
        
        case searchImages(Double, Double)
        
        var stringValue: String {
            switch self {
            case .searchImages(let latitude, let longitude):
                return Endpoints.base + "&lat=\(latitude)&lon=\(longitude)" + "&page=\(Int.random(in: 0..<100))"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    // MARK: - Base REST methods
    
    class func taskGETRequest<Response: Decodable>(url: URL, response: Response.Type, completion: @escaping (Response?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                completion(nil, error)
                return
            }
            
            let decoder = JSONDecoder()
            do {
                var newData = data.subdata(in: 14..<data.count)
                _ = newData.popLast()
                let result = try decoder.decode(Response.self, from: newData)
                DispatchQueue.main.async {
                    completion(result, nil)
                }
            } catch {
                do {
                    let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(nil, errorResponse as? Error)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Network calls
    
    class func getPhotos(latitude: Double, longitude: Double, completion: @escaping ([Photo], Error?) -> Void ) {
        taskGETRequest(url: Endpoints.searchImages(latitude, longitude).url, response: PhotosRequest.self) { (response, error) in
            if let response = response {
                completion(response.photos.photoList, nil)
            } else {
                completion([], error)
            }
        }
    }
    
    class func loadSingleImage(imageUrl: String, completion: @escaping(Data?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: URL(string: imageUrl)!) { (data, response, error) in
            guard let data = data else {
                completion(nil, error)
                return
            }
            DispatchQueue.main.async {
                completion(data, nil)
            }
            
        }
        task.resume()
    }
}
