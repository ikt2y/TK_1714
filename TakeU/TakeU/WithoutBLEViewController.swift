//
//  WithoutBlutoothViewController.swift
//  TakeU
//
//  Created by ikt2y on 2017/10/30.
//  Copyright © 2017年 shibugame. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import GooglePlaces

class WithoutBLEViewController: UIViewController {
    
    var timer: Timer!
    
    // MapView.
    var myMapView : MKMapView!
    var myLocationManager: CLLocationManager!
    
    // Search results
    var searchResultController: SearchResultsController!
    var resultsArray = [String]()
    
    // turn by turn navigation info
    var steps = [MKRouteStep]()
    var stepCounter = 0
    
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
    
    @objc func update() {
        myLocationManager.startUpdatingLocation()
    }
    
    func setupLocationManager() {
        // LocationManagerの生成&設定.
        myLocationManager = CLLocationManager()
        myLocationManager.delegate = self
        myLocationManager.distanceFilter = 100.0
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Location privacy setting.
        let status = CLLocationManager.authorizationStatus()
        if(status != CLAuthorizationStatus.authorizedAlways) {
            print("not determined")
            myLocationManager.requestAlwaysAuthorization()
        }
        // Setting location accuracy
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        myLocationManager.startUpdatingLocation()
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
        // ルートは1つのみ
        if self.myMapView.overlays.count != 0 {
            self.myMapView.removeOverlays(self.myMapView.overlays)
        }
        // 地図の中心を出発点と目的地の中間に設定.
        let center: CLLocationCoordinate2D = CLLocationCoordinate2DMake((currentLat + destinationLat)/2, (currentLon + destinationLon)/2)
        myMapView.setCenter(center, animated: true)
        // 縮尺を指定.
        // 現在地と目的地を含む矩形を計算
        let maxLat:Double = fmax(currentLat, destinationLat)
        let maxLon:Double = fmax(currentLon, destinationLon)
        let minLat:Double = fmin(currentLat, destinationLat)
        let minLon:Double = fmin(currentLon, destinationLon)
        // 地図表示するときの緯度、経度の幅を計算
        let mapMargin:Double = 1.5
        let leastCoordSpan:Double = 0.005
        let span_x:Double = fmax(leastCoordSpan, fabs(maxLat - minLat) * mapMargin);
        let span_y:Double = fmax(leastCoordSpan, fabs(maxLon - minLon) * mapMargin);
        let mySpan:MKCoordinateSpan = MKCoordinateSpanMake(span_x, span_y);
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
        myDirections.calculate { (response, error) in
            if error != nil || response!.routes.isEmpty {
                return
            }
            let route: MKRoute = response!.routes[0] as MKRoute
            // 観測停止.
            self.myLocationManager.monitoredRegions.forEach({
                self.myLocationManager.stopMonitoring(for: $0)
            })
            // 曲がり角ごとに情報を取得.
            self.steps = route.steps
            for i in 0 ..< route.steps.count {
                let step = route.steps[i]
                print("\(step.distance)m")
                print("\(step.instructions)")
                // 観測領域を生成.
                let region = CLCircularRegion(center: step.polyline.coordinate,
                                              radius: 10,
                                              identifier: "\(i)")
                // 観測開始.
                self.myLocationManager.startMonitoring(for: region)
                let circle = MKCircle(center: region.center, radius: region.radius)
                // 観測領域を描画
                self.myMapView.add(circle)
            }
            // mapViewにルートを描画.
            self.myMapView.add(route.polyline)
        }
        self.stepCounter += 1
        self.view.addSubview(myMapView)
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
    
    @IBAction func tapSearchAddressBtn(_ sender: Any) {
        let searchController = UISearchController(searchResultsController: searchResultController)
        searchController.searchBar.delegate = self
        self.present(searchController, animated:true, completion: nil)
    }
    
}

extension WithoutBLEViewController: MKMapViewDelegate {
    
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
        // 経路の線.
        if overlay is MKPolyline {
            let route: MKPolyline = overlay as! MKPolyline
            let routeRenderer: MKPolylineRenderer = MKPolylineRenderer(polyline: route)
            // ルートの線の太さ.
            routeRenderer.lineWidth = 3.0
            // ルートの線の色.
            routeRenderer.strokeColor = UIColor.red
            return routeRenderer
        }
        // 曲がり角の円.
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = .red
            renderer.fillColor = .red
            renderer.alpha = 0.5
            return renderer
        }
        return MKOverlayRenderer()
    }
    
}
extension WithoutBLEViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var statusStr = ""
        switch status {
        case .notDetermined, .denied, .restricted, .authorizedWhenInUse:
            statusStr = "NG"
            setMap(lat: 35.681167, lon: 139.767052) // default location (Tokyo)
        case .authorizedAlways:
            statusStr = "OK"
            break
        }
        print("AuthorizationStatus: \(statusStr)")
    }
    
    // GPSから値を取得した際に呼び出されるメソッド.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.currentLat = locations.first!.coordinate.latitude
        self.currentLon = locations.first!.coordinate.longitude
        setMap(lat: currentLat, lon: currentLon)
        myLocationManager.stopUpdatingLocation()
        self.myMapView.userTrackingMode = .followWithHeading
    }
    
    // 観測領域に入った際に呼ばれるメソッド.
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered route")
        // アラートを作成.
        let alert = UIAlertController(title:"Enter！", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true, completion: nil)
        stepCounter += 1
        if stepCounter < steps.count {
            let currentStep = steps[stepCounter]
            if currentStep.instructions.contains("右") {
                let alert = UIAlertController(title:"右に曲がってください", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true, completion: nil)
            } else if currentStep.instructions.contains("左") {
                let alert = UIAlertController(title:"左に曲がってください", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true, completion: nil)
            } else { return }
            myLocationManager.startUpdatingLocation()
        } else {
            // 目的地に到達した時に表示.
            // アラートを作成.
            let alert = UIAlertController(title:"到着！", message: "目的地に到着しました", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true, completion: nil)
            
            // 一度リセット.
            stepCounter = 0
            myLocationManager.monitoredRegions.forEach(
                { self.myLocationManager.stopMonitoring(for: $0) }
            )
            
            // 表示していたアノテーション,overlayなども消す.
            self.myMapView.removeAnnotations(myMapView.annotations)
            self.myMapView.removeOverlays(myMapView.overlays)
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // アラートを作成.
        let alert = UIAlertController(title:"Exit！", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension WithoutBLEViewController: UISearchBarDelegate {
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

extension WithoutBLEViewController: LocateOnTheMap {
    func locateWithLongitude(_ lon: Double, resultLat lat: Double, resultTitle title: String) {
        DispatchQueue.main.async { () -> Void in
            self.setMap(lat: lat, lon: lon)
            let destinationPin: MKPointAnnotation = MKPointAnnotation()
            destinationPin.coordinate.latitude = lat
            destinationPin.coordinate.longitude = lon
            // 目的地の緯度経度を設定
            self.destinationLat = lat
            self.destinationLon = lon
            destinationPin.title = title
            // MapViewにピンを追加.
            self.myMapView.addAnnotation(destinationPin)
            // ルートを表示
            self.createRoute()
        }
    }
}
