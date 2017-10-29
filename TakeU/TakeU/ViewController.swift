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
import CoreBluetooth

// bluetooth接続に使用
let PeripheralName = "IMBLE042C"
let CharacteristicProperties = 0xA
let ServiceUUID = CBUUID(string:"ADA99A7F-888B-4E9F-8080-07DDC240F3CE")
let CharacteristicUUID = CBUUID(string:"ADA99A7F-888B-4E9F-8082-07DDC240F3CE")
let ShortRight = "abcdr"
let LongRight = "abcdR"
let ShortLeft = "abcdl"
let LongLeft = "abcdL"


class ViewController: UIViewController {
    
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
    
    // bluetooth
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    private var characteristicArray = [CBCharacteristic]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        searchResultController = SearchResultsController()
        searchResultController.delegate = self
        startConnectPeripheral() // bluetooth connect
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
                                              radius: 20,
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
    
    // bluetooth
    
    // 接続開始メソッド
    func startConnectPeripheral() {
        // CBCentralManagerの初期化
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
    // 接続切断メソッド
    func startDisconnectPeripheral() {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    // ペリフェラルへの書き込みメソッド
    func writeValueToPeripheral(_ submitData: String){
        peripheral.writeValue(submitData.data(using: String.Encoding.ascii)!,
                              for: characteristicArray.last!,
                              type: CBCharacteristicWriteType.withResponse)
    }
    
}

extension ViewController: MKMapViewDelegate {
    
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
extension ViewController: CLLocationManagerDelegate {
    
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
                // bluetooth write
                writeValueToPeripheral(ShortRight)
            } else if currentStep.instructions.contains("左") {
                // bluetooth write
                writeValueToPeripheral(ShortLeft)
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

extension ViewController: UISearchBarDelegate {
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

extension ViewController: LocateOnTheMap {
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

// bluetooth controller

// //  Created by Rentaro Igari on 2017/10/28.


extension ViewController: CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //====================================================
    //       CBCentralの状態が変化した時に呼ばれるメソッド.
    //====================================================
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // ログ出力.
        print("state: \(central.state)")
        
        // CBCentralがPoweredONの時にスキャン開始.
        switch (central.state) {
            
        case .unknown:
            print("BLE Unknown")
        case .resetting:
            print("BLE Resetting")
        case .unsupported:
            print("BLE Unsupported")
        case .unauthorized:
            print("BLE Unauthorized")
        case .poweredOff:
            print("BLE PoweredOff")
        case .poweredOn:
            print("BLE PoweredOn")
            central.scanForPeripherals(withServices: nil, options: nil)
        }
        
    }
    
    
    
    //=========================================================
    //                 スキャン結果を受け取る.
    //=========================================================
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber)
    {
        // takeUを検出する.
        if(peripheral.name == PeripheralName) {
            print("detection success")
            self.peripheral = peripheral
            
            // スキャン停止
            self.centralManager.stopScan()
            
            // takeUと接続する
            self.centralManager.connect(self.peripheral, options: nil)
            
        }
        
    }
    
    
    //==========================================================================================
    //                                   接続時呼ばれるメソッド
    //==========================================================================================
    
    // 成功時
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connection success!")
        
        // delegateをセット
        peripheral.delegate = self;
        
        // サービス探索
        peripheral.discoverServices([ServiceUUID])
    }
    
    // 失敗時
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Connection failed...")
    }
    
    
    //==============================================================
    //        サービス探索結果を受け取り、キャラクタリスティックを探索
    //===============================================================
    
    // サービス探査後に呼ばれるメソッド
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else{
            print("error")
            return
        }
        print(services)
        print("service detection success!")
        for obj in services {
            if let service = obj as? CBService {
                
                // キャラクタリスティック探索
                peripheral.discoverCharacteristics(
                    [CharacteristicUUID], for: service)
            }
        }
    }
    
    
    //=========================================================
    //           キャラクタリスティックを受け取る
    //=========================================================
    
    // キャラクタリスティック探査後に呼ばれるメソッド
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            print("\(characteristics)")
            
            print("character detection success!")
            // 書き込み用キャラクタリスティックを保存
            for characteristic in characteristics {
                if(Int(characteristic.properties.rawValue) == CharacteristicProperties) {
                    print(characteristic)
                    self.characteristicArray.append(characteristic as CBCharacteristic)
                }
            }
        }
        print("---------------------------------")
    }
    
    
    //===============================================
    //         書き込み後に実行されるメソッド
    //===============================================
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("write sccess!!")
    }
    
    
    
    //===============================================
    //          接続切断時に呼び出されるメソッド
    //===============================================
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("disconnect peripheral")
        print("==================================")
    }
    
}



