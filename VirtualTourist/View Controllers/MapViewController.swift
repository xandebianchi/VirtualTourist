//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Alexandre Bianchi on 15/02/21.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {

    // MARK: - Static variables
    
    struct Constants {
        static let latitude: String = "latitude"
        static let longitude: String = "longitude"
        static let latitudeDelta: String = "latitudeDelta"
        static let longitudeDelta: String = "longitudeDelta"
        static let locations: String = "locations"
        static let initialDelta: Double = 7.0
        static let segueIdentifier: String = "goToPhotoAlbum"
        static let okMessage: String = "OK"
        static let warningTitle: String = "Warning"
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: - Variables
    
    var mapChangedFromUserInteraction = false
    var dataController: DataController!
    let standardUserDefaults = UserDefaults.standard
    var location: Location!
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var fetchResultsController: NSFetchedResultsController<Location>!

    // MARK: - Lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(mapViewTapped(sender:)))
        longPressGestureRecognizer.delegate = self
        mapView.delegate = self
        mapView.addGestureRecognizer(longPressGestureRecognizer)
        buildMapViewUI()
        setupFetchedResultsViewController()
        getSavedLocations()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFetchedResultsViewController()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        fetchResultsController = nil
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
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        mapChangedFromUserInteraction = mapViewRegionDidChangeFromUserInteraction()
    }
    
    private func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        if let gestureRecognizers = mapView.subviews[0].gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizer.State.began || recognizer.state == UIGestureRecognizer.State.ended) {
                    return true
                }
            }
        }
        return false
    }
        
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        if (mapChangedFromUserInteraction) {
            saveMapRegion()
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        var selectedAnnotation: MKPointAnnotation!
        selectedAnnotation = view.annotation as? MKPointAnnotation
        latitude = selectedAnnotation.coordinate.latitude
        longitude = selectedAnnotation.coordinate.longitude
        let savedPins = fetchResultsController.fetchedObjects! as [Location]
        location = savedPins.filter({$0.latitude == view.annotation?.coordinate.latitude && $0.longitude == view.annotation?.coordinate.longitude}).first
        performSegue(withIdentifier: Constants.segueIdentifier, sender: self)
    }
    
    // MARK: - Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? PhotoAlbumViewController {
            viewController.dataController = dataController
            viewController.latitude = latitude
            viewController.longitude = longitude
            viewController.location = location
        }
    }
    
    // MARK: - Main methods
    
    fileprivate func buildMapViewUI() {
        let coordinate2D = CLLocationCoordinate2D(latitude: standardUserDefaults.object(forKey: Constants.latitude) as? Double ?? mapView.centerCoordinate.latitude, longitude: standardUserDefaults.object(forKey: Constants.longitude) as? Double ?? mapView.centerCoordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: standardUserDefaults.object(forKey: Constants.latitudeDelta) as? Double ?? Constants.initialDelta, longitudeDelta: standardUserDefaults.object(forKey: Constants.longitudeDelta) as? Double ?? Constants.initialDelta)
        let region = MKCoordinateRegion(center: coordinate2D, span: span)
        mapView.setRegion(region, animated: true)
    }
    
    func setupFetchedResultsViewController() {
        let fetchRequest: NSFetchRequest<Location> = Location.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: Constants.latitude, ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: Constants.locations)
        fetchResultsController.delegate = self
        do {
            try fetchResultsController.performFetch()
        } catch {
            alertMessage(message: error.localizedDescription)
        }
    }
    
    fileprivate func saveMapRegion() {
        standardUserDefaults.set(mapView.centerCoordinate.latitude, forKey: Constants.latitude)
        standardUserDefaults.set(mapView.centerCoordinate.longitude, forKey: Constants.longitude)
        standardUserDefaults.set(mapView.region.span.latitudeDelta, forKey: Constants.latitudeDelta)
        standardUserDefaults.set(mapView.region.span.longitudeDelta, forKey: Constants.longitudeDelta)
    }
    
    func getSavedLocations() {
        if let locations = fetchResultsController.fetchedObjects {
            for location in locations {
                let annotation = MKPointAnnotation()
                annotation.coordinate.latitude = location.latitude
                annotation.coordinate.longitude = location.longitude
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    @objc func mapViewTapped(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let annotation = MKPointAnnotation()
            let location = sender.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
            let savedLocation = Location(context: dataController.viewContext)
            savedLocation.longitude = annotation.coordinate.longitude
            savedLocation.latitude = annotation.coordinate.latitude
            do {
                try dataController.viewContext.save()
            } catch {
                alertMessage(message: error.localizedDescription)
            }
            try? fetchResultsController.performFetch()
            sender.state = .ended
        }
    }
    
    func alertMessage(message: String) {
        let alert = UIAlertController(title: Constants.warningTitle, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: Constants.okMessage, style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
}
