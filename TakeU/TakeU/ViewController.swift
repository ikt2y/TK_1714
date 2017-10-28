//
//  ViewController.swift
//  TakeU
//
//  Created by ikt2y on 2017/10/28.
//  Copyright © 2017年 shibugame. All rights reserved.
//
import UIKit
import MapKit
import CoreLocation
import GooglePlaces

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate, LocateOnTheMap {
    
    // MapView.
    var myMapView : MKMapView!
    var myLocationManager: CLLocationManager!
    
    // Search results
    var searchResultController: SearchResultsController!
    var resultsArray = [String]()
    
    // current location
    var currentLat: CLLocationDegrees = CLLocationDegrees()
    var currentLon: CLLocationDegrees = CLLocationDegrees()
    
    // destination location
    var destinationLat: CLLocationDegrees = CLLocationDegrees()
    var destinationLon: CLLocationDegrees = CLLocationDegrees()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        searchResultController = SearchResultsController()
        searchResultController.delegate = self
    }
    
    
    func setupLocationManager() {
        // LocationManagerの生成&設定.
        myLocationManager = CLLocationManager()
        myLocationManager.delegate = self
        myLocationManager.distanceFilter = 100.0
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Location privacy setting.
        let status = CLLocationManager.authorizationStatus()
        if(status != CLAuthorizationStatus.authorizedWhenInUse) {
            print("not determined")
            myLocationManager.requestWhenInUseAuthorization()
        }
        // Setting location accuracy
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        myLocationManager.startUpdatingLocation()
    }
    
    // GPSから値を取得した際に呼び出されるメソッド.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //　Get current location info
        self.currentLat = locations.first!.coordinate.latitude
        self.currentLon = locations.first!.coordinate.longitude
        setMap(lat: self.currentLat, lon: self.currentLon)
    }
    
    func setMap(lat: Double, lon: Double) {
        // 中心点の緯度経度.
        let myLat: CLLocationDegrees = lat
        let myLon: CLLocationDegrees = lon
        let myCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(myLat, myLon)
        
        // 縮尺.
        let myLatDist : CLLocationDistance = 100
        let myLonDist : CLLocationDistance = 100
        
        // MapViewの生成&表示.
        myMapView = MKMapView()
        myMapView.showsUserLocation = true
        myMapView.frame = self.view.bounds
        myMapView.delegate = self
        // Regionを作成.
        let myRegion: MKCoordinateRegion = MKCoordinateRegionMakeWithDistance(myCoordinate, myLatDist, myLonDist);
        myMapView.setRegion(myRegion, animated: true)
        self.view.addSubview(myMapView)
        // 長押しでタップするときにピンを落とす設定
        let myLongPress: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
        myLongPress.addTarget(self, action: #selector(self.recognizeLongPress(sender:)))
        // MapViewにUIGestureRecognizerを追加.
        myMapView.addGestureRecognizer(myLongPress)
    }
    
    func createRoute() {
        // 地図の中心を出発点と目的地の中間に設定.
        let center: CLLocationCoordinate2D = CLLocationCoordinate2DMake((currentLat + destinationLat)/2, (currentLon + destinationLon)/2)
        myMapView.setCenter(center, animated: true)
        // 縮尺を指定.
        let mySpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        let myRegion: MKCoordinateRegion = MKCoordinateRegion(center: center, span: mySpan)
        // regionをmapViewにセット.
        myMapView.region = myRegion
        // PlaceMarkを生成して出発点、目的地の座標をセット.
        let currentCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(self.currentLat, self.currentLon)
        let destinationCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(self.destinationLat, self.destinationLon)
        let fromPlace: MKPlacemark = MKPlacemark(coordinate: currentCoordinate, addressDictionary: nil)
        let toPlace: MKPlacemark = MKPlacemark(coordinate: destinationCoordinate, addressDictionary: nil)
        // Itemを生成してPlaceMarkをセット.
        let fromItem: MKMapItem = MKMapItem(placemark: fromPlace)
        let toItem: MKMapItem = MKMapItem(placemark: toPlace)
        // MKDirectionsRequestを生成.
        let myRequest: MKDirectionsRequest = MKDirectionsRequest()
        // 出発地のItemをセット.
        myRequest.source = fromItem
        // 目的地のItemをセット.
        myRequest.destination = toItem
        // 複数経路の検索を有効.
        myRequest.requestsAlternateRoutes = true
        // 移動手段を徒歩に設定.
        myRequest.transportType = MKDirectionsTransportType.walking
        // MKDirectionsを生成してRequestをセット.
        let myDirections: MKDirections = MKDirections(request: myRequest)
        // 経路探索.
        // ルートは1つのみ
        if self.myMapView.overlays.count != 0 {
            self.myMapView.removeOverlays(self.myMapView.overlays)
        }
        myDirections.calculate { (response, error) in
            if error != nil || response!.routes.isEmpty {
                return
            }
            let route: MKRoute = response!.routes[0] as MKRoute
            // mapViewにルートを描画.
            self.myMapView.add(route.polyline)
        }
        self.view.addSubview(myMapView)
    }
    
    // Regionが変更された時に呼び出されるメソッド.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        print("regionDidChangeAnimated")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var statusStr = ""
        switch status {
        case .notDetermined, .denied, .restricted:
            statusStr = "NG"
            setMap(lat: 35.681167, lon: 139.767052) // default location (Tokyo)
        case .authorizedAlways: fallthrough
        case .authorizedWhenInUse:
            statusStr = "OK"
            break
        }
        print("AuthorizationStatus: \(statusStr)")
    }
    
    /*
     長押しを感知した際に呼ばれるメソッド.
     */
    @objc func recognizeLongPress(sender: UILongPressGestureRecognizer) {
        // 長押しの最中に何度もピンを生成しないようにする.
        if sender.state != UIGestureRecognizerState.began { return }
        let location = sender.location(in: myMapView)
        let myCoordinate: CLLocationCoordinate2D = myMapView.convert(location, toCoordinateFrom: myMapView)
        let destinationPin: MKPointAnnotation = MKPointAnnotation()
        destinationPin.coordinate = myCoordinate
        destinationPin.title = "タイトル"
        destinationPin.subtitle = "サブタイトル"
        // 目的地の緯度経度を設定
        self.destinationLat = destinationPin.coordinate.latitude
        self.destinationLon = destinationPin.coordinate.longitude
        // MapViewにピンを追加.
        myMapView.addAnnotation(destinationPin)
        // ルートを表示
        createRoute()
    }
    
    /*
     addAnnotationした際に呼ばれるデリゲートメソッド.
     */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // 目的地は2つ以上つくれない
        if self.myMapView.annotations.count > 1 {
            self.myMapView.removeAnnotations(myMapView.annotations)
        }
        // 現在地アノテーションの表示
        if annotation as? MKUserLocation == mapView.userLocation { return nil }
        // 目的地アノテーションの表示
        let destinationPinIdentifier = "PinAnnotationIdentifier"
        let destinationPinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: destinationPinIdentifier)
        destinationPinView.animatesDrop = true
        destinationPinView.canShowCallout = true
        destinationPinView.annotation = annotation
        destinationPinView.isDraggable = true
        return destinationPinView
    }
    
    // ルートの表示設定.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let route: MKPolyline = overlay as! MKPolyline
        let routeRenderer: MKPolylineRenderer = MKPolylineRenderer(polyline: route)
        // ルートの線の太さ.
        routeRenderer.lineWidth = 3.0
        // ルートの線の色.
        routeRenderer.strokeColor = UIColor.red
        return routeRenderer
    }
    
    @IBAction func tapSearchAddressBtn(_ sender: Any) {
        let searchController = UISearchController(searchResultsController: searchResultController)
        searchController.searchBar.delegate = self
        self.present(searchController, animated:true, completion: nil)
    }
    
    func locateWithLongitude(_ lon: Double, resultLat lat: Double, resultTitle title: String) {
        DispatchQueue.main.async { () -> Void in
            self.setMap(lat: lat, lon: lon)
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let placeClient = GMSPlacesClient()
        placeClient.autocompleteQuery(searchText, bounds: nil, filter: nil) { (results, error: Error?) -> Void in
            print("Error @%",Error.self)
            self.resultsArray.removeAll()
            if results == nil { return }
            for result in results! {
                if let result = result as? GMSAutocompletePrediction {
                    self.resultsArray.append(result.attributedFullText.string)
                }
            }
            self.searchResultController.reloadDataWithArray(self.resultsArray)
        }
    }
    
}
