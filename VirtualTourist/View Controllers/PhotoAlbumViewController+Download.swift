//
//  PhotoAlbumViewController+Download.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 27/02/21.
//

extension PhotoAlbumViewController {
    
    func getPhotosFromFlickr(completion: @escaping (Bool, Error?, String?) -> Void) {
        changeNewCollectionButtonStatus(is: false)
        FlickrClient.getPhotos(latitude: latitude, longitude: longitude) { (photos, error) in
            if error == nil {
                self.imagesDownloadedOrWithError = 0
                for image in photos {
                    completion(true, nil, image.url_m)
                }
            } else {
                completion(false, error, nil)
            }
        }
    }
    
    func downloadSingleImage(imageUrl: String, completion: @escaping(Bool, Error?) -> Void) {
        let imageFlickr = ImageFlickr(context: dataController.viewContext)
        FlickrClient.loadSingleImage(imageUrl: imageUrl) { (data, error) in
            if error == nil {
                imageFlickr.image = data
                imageFlickr.url = imageUrl
                imageFlickr.location = self.location
                do {
                    try self.dataController.viewContext.save()
                    completion(true, nil)
                } catch {
                    completion(false, error)
                }
            } else {
                completion(false, error)
            }
        }
    }
    
}
