import SwiftUI
import MapKit
import CoreLocation

struct AppleMapView: UIViewRepresentable {
    let startLocation: String
    let endLocation: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true // 显示用户当前位置蓝点
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 1. 清除地图上旧的标记和路线
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        let geocoder = CLGeocoder()
        
        // 2. 解析“起点”地址
        geocoder.geocodeAddressString(startLocation) { startPlacemarks, error in
            guard let startLoc = startPlacemarks?.first?.location?.coordinate else { return }
            
            // 添加起点大头针
            let startAnnotation = MKPointAnnotation()
            startAnnotation.title = "起点"
            startAnnotation.subtitle = startLocation
            startAnnotation.coordinate = startLoc
            mapView.addAnnotation(startAnnotation)
            
            // 3. 解析“终点”地址
            geocoder.geocodeAddressString(endLocation) { endPlacemarks, error in
                guard let endLoc = endPlacemarks?.first?.location?.coordinate else { return }
                
                // 添加终点大头针
                let endAnnotation = MKPointAnnotation()
                endAnnotation.title = "终点"
                endAnnotation.subtitle = endLocation
                endAnnotation.coordinate = endLoc
                mapView.addAnnotation(endAnnotation)
                
                // 4. 请求自动规划路线 (Apple Maps 核心功能)
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: startLoc))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endLoc))
                request.transportType = .automobile // 设置为驾车模式
                
                let directions = MKDirections(request: request)
                directions.calculate { response, error in
                    guard let route = response?.routes.first else { return }
                    
                    // 在地图上画出路线
                    mapView.addOverlay(route.polyline)
                    
                    // 5. 自动缩放地图，让起点、终点和路线都刚好在屏幕内
                    let rect = route.polyline.boundingMapRect
                    // 增加一点内边距 (padding)，别让路线贴着屏幕边缘
                    mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
                }
            }
        }
    }
    
    // MARK: - Coordinator (代理)
    // 用来处理地图的高级回调，比如“怎么画线”
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AppleMapView
        
        init(_ parent: AppleMapView) {
            self.parent = parent
        }
        
        // 告诉地图：路线要画成什么颜色和宽度
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue // 苹果地图经典的蓝色
                renderer.lineWidth = 6
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
