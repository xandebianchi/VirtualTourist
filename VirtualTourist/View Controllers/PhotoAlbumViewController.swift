//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 20/02/21.
//

import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    
    // MARK: - Static variables
    
    struct Constants {
        static let image: String = "image"
        static let locationPredicate: String = "location == %@"
        static let collectionViewCellName: String = "ImageCell"
        static let errorMessageGetFromCoreData: String = "Not possible to get last images. Try a new collection."
        static let errorMessageGetNewImages: String = "Not possible to get new images. Try a new collection."
        static let errorMessageNotPossibleToDelete: String = "It was not possible to delete the image"
        static let errorDownloadingSingleImage: String = "There is an error with image download."
        static let okMessage: String = "OK"
        static let warningTitle: String = "Warning"
    }
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photoAlbum: UICollectionView!
    @IBOutlet weak var noImagesLabel: UILabel!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var newCollectionButton: UIButton!

    // MARK: - Variables
    
    var dataController: DataController!
    var latitude: Double = 0
    var longitude: Double = 0
    var location: Location!
    var fetchResultsController: NSFetchedResultsController<ImageFlickr>!
    var imagesDownloadedOrWithError: Int = 0
    
    // MARK: - Lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        photoAlbum.delegate = self
        photoAlbum.dataSource = self
        noImagesLabel.isHidden = true
        newCollectionButton.addTarget(self, action: #selector(fetchNewPhotoAlbum), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupMapView()
        setupFetchedResultsViewController(completion: handleCoreDataImagesFetch(success:error:))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        setupCollectionViewCells()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        fetchResultsController = nil
    }
     
    // MARK: - Main methods
    
    fileprivate func clearImages() {
        let imagesFlickr = fetchResultsController.fetchedObjects!
        let indexPath = IndexPath(row: 0, section: 0)
        for image in imagesFlickr {
            dataController.viewContext.delete(image)
            photoAlbum.deleteItems(at: [indexPath])
        }
        try? dataController.viewContext.save()
    }
    
    @objc func fetchNewPhotoAlbum() {
        clearImages()
        getPhotosFromFlickr(completion: handleDownloadUrlImages(success:error:imageUrl:))
        try? dataController.viewContext.save()
        DispatchQueue.main.async {
            self.photoAlbum.reloadData()
        }
    }
    
    func setupCollectionViewCells() {
        let space: CGFloat = 2.0
        let dimensionX = (view.frame.size.width - (4 * space)) / 3.0
        let dimensionY = (view.frame.size.height - (5 * space)) / 4.0
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSize(width: dimensionX, height: dimensionY)
    }
    
    func setupMapView() {
        let annotation = MKPointAnnotation()
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let span = MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        annotation.coordinate = coordinate
        mapView.delegate = self
        mapView.setRegion(region, animated: true)
        mapView.addAnnotation(annotation)
    }
    
    func setupFetchedResultsViewController(completion: @escaping (Bool, Error?) -> Void) {
        let fetchRequest: NSFetchRequest<ImageFlickr> = ImageFlickr.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: Constants.image, ascending: true)
        let predicate = NSPredicate(format: Constants.locationPredicate, location)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchResultsController.delegate = self
        do {
            try fetchResultsController.performFetch()
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
           
    func handleCoreDataImagesFetch(success: Bool, error: Error?) {
        if success {
            if fetchResultsController.fetchedObjects?.count ?? 0 == 0 {
                getPhotosFromFlickr(completion: handleDownloadUrlImages(success:error:imageUrl:))
            }
        } else {
            alertMessage(message: Constants.errorMessageGetFromCoreData)
            newCollectionButton.isEnabled = true
        }
    }

    func handleDownloadUrlImages(success: Bool, error: Error?, imageUrl: String?) {
        if success {
            downloadSingleImage(imageUrl: imageUrl!, completion: handleDownloadSingleImage(success:error:))
        } else {
            alertMessage(message: Constants.errorMessageGetNewImages)
            newCollectionButton.isEnabled = true
        }
    }
    
    func handleDownloadSingleImage(success: Bool, error: Error?) {
        if success {
            try? fetchResultsController.performFetch()
            DispatchQueue.main.async {
                self.photoAlbum.reloadData()
                self.incrementImagesDownloadOrWithErrorAndTestWithTotalPhotos()
            }
        } else {
            print(error?.localizedDescription ?? Constants.errorDownloadingSingleImage)
            incrementImagesDownloadOrWithErrorAndTestWithTotalPhotos()
        }
    }
    
    fileprivate func incrementImagesDownloadOrWithErrorAndTestWithTotalPhotos() {
        self.imagesDownloadedOrWithError += 1
        if self.imagesDownloadedOrWithError == FlickrClient.pageSize {
            self.changeNewCollectionButtonStatus(is: true)
        }
    }

    func changeNewCollectionButtonStatus(is downloadFinished: Bool) {
        newCollectionButton.isEnabled = downloadFinished
    }
    
    func alertMessage(message: String) {
        let alert = UIAlertController(title: Constants.warningTitle, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: Constants.okMessage, style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - MapView delegate methods

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.pinTintColor = UIColor.red
        } else {
            pinView!.annotation = annotation
        }
    
        return pinView
    }
    
    // MARK: - CollectionView delegate methods
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchResultsController.sections?.count ?? 1
    }
      
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.collectionViewCellName, for: indexPath) as! ImageCell
        if imageCell.isSelected {
           let imageSelected = fetchResultsController.object(at: indexPath)
           dataController.viewContext.delete(imageSelected)
           do {
               try dataController.viewContext.save()
               try fetchResultsController.performFetch()
           } catch {
               alertMessage(message: Constants.errorMessageNotPossibleToDelete)
           }
           DispatchQueue.main.async {
               self.photoAlbum.deleteItems(at: [indexPath])
               self.photoAlbum.reloadData()
           }
        }
    }
           
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.collectionViewCellName, for: indexPath) as! ImageCell
        let imageAtIndexPath = fetchResultsController.object(at: indexPath)
        if let cellImage = imageAtIndexPath.image {
            DispatchQueue.main.async {
                imageCell.imageFlickr.image = UIImage(data: cellImage)
            }
        }
        return imageCell
    }
    
}
