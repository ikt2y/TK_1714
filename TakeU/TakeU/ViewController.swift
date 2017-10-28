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

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    // MapView.
    var myMapView : MKMapView!
    var myLocationManager: CLLocationManager!
    var currentLat: Double = Double()
    var currentLon: Double = Double()
    var destinationLat: Double = Double()
    var destinationLon: Double = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
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
        // Regionを作成.
        let myRegion: MKCoordinateRegion = MKCoordinateRegionMakeWithDistance(myCoordinate, myLatDist, myLonDist);
        // MapViewの生成&表示.
        myMapView = MKMapView()
        myMapView.showsUserLocation = true
        myMapView.frame = self.view.bounds
        myMapView.delegate = self
        self.view.addSubview(myMapView)
        // MapViewに反映.
        myMapView.setRegion(myRegion, animated: true)
        
        let myLongPress: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
        myLongPress.addTarget(self, action: #selector(self.recognizeLongPress(sender:)))
        // MapViewにUIGestureRecognizerを追加.
        myMapView.addGestureRecognizer(myLongPress)
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
        
        // #TODO: destinationLat, destinationLonにそれぞれ代入する
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
}
