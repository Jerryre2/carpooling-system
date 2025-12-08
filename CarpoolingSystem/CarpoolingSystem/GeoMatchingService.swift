//
//  GeoMatchingService.swift
//  CarpoolingSystem - Geographic Matching & Location Services
//
//  Created on 2025-12-07
//  实现地理位置查询和智能匹配算法
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Geographic Matching Service
/// 地理匹配服务（商业级匹配算法）
class GeoMatchingService {
    
    // MARK: - 常量配置
    
    /// 默认搜索半径（公里）
    static let defaultSearchRadius: Double = 5.0
    
    /// 最大搜索半径（公里）
    static let maxSearchRadius: Double = 50.0
    
    /// 地球半径（公里）
    private static let earthRadiusKm: Double = 6371.0
    
    // MARK: - 核心功能：地理范围查询
    
    /// 根据地理位置筛选行程（Geofencing）
    /// - Parameters:
    ///   - rides: 所有行程列表
    ///   - userLocation: 用户当前位置
    ///   - radiusKm: 搜索半径（公里）
    /// - Returns: 在范围内的行程列表
    static func filterRidesByProximity(
        rides: [AdvancedRide],
        userLocation: CLLocationCoordinate2D,
        radiusKm: Double = defaultSearchRadius
    ) -> [AdvancedRide] {
        print("📍 开始地理筛选：用户位置 (\(userLocation.latitude), \(userLocation.longitude)), 半径 \(radiusKm)km")
        
        let filteredRides = rides.filter { ride in
            // 检查起点距离
            if let startDistance = calculateDistance(
                from: userLocation,
                to: ride.startLocation
            ) {
                if startDistance <= radiusKm {
                    print("  ✅ 行程 \(ride.id) 起点距离: \(String(format: "%.2f", startDistance))km")
                    return true
                }
            }
            
            // 检查终点距离
            if let endDistance = calculateDistance(
                from: userLocation,
                to: ride.endLocation
            ) {
                if endDistance <= radiusKm {
                    print("  ✅ 行程 \(ride.id) 终点距离: \(String(format: "%.2f", endDistance))km")
                    return true
                }
            }
            
            return false
        }
        
        print("📊 筛选结果: \(filteredRides.count)/\(rides.count) 条行程")
        return filteredRides
    }
    
    /// 智能匹配行程（综合考虑距离、时间、价格）
    /// - Parameters:
    ///   - rides: 所有行程列表
    ///   - userLocation: 用户位置
    ///   - departureTime: 期望出发时间
    ///   - maxPricePerSeat: 最高可接受价格
    ///   - radiusKm: 搜索半径
    /// - Returns: 匹配度排序的行程列表
    static func smartMatchRides(
        rides: [AdvancedRide],
        userLocation: CLLocationCoordinate2D,
        departureTime: Date? = nil,
        maxPricePerSeat: Double? = nil,
        radiusKm: Double = defaultSearchRadius
    ) -> [(ride: AdvancedRide, matchScore: Double)] {
        print("🎯 开始智能匹配...")
        
        var matchedRides: [(ride: AdvancedRide, matchScore: Double)] = []
        
        for ride in rides {
            var score: Double = 100.0 // 基础分数
            
            // 1. 地理位置匹配（权重：40%）
            if let startDistance = calculateDistance(from: userLocation, to: ride.startLocation) {
                let distanceScore = max(0, 40 - (startDistance / radiusKm) * 40)
                score += distanceScore
            }
            
            // 2. 时间匹配（权重：30%）
            if let departureTime = departureTime {
                let timeDifference = abs(ride.departureTime.timeIntervalSince(departureTime))
                let timeScore = max(0, 30 - (timeDifference / 3600) * 5) // 每小时减 5 分
                score += timeScore
            }
            
            // 3. 价格匹配（权重：20%）
            if let maxPrice = maxPricePerSeat {
                if ride.unitPrice <= maxPrice {
                    let priceRatio = ride.unitPrice / maxPrice
                    let priceScore = 20 * (1 - priceRatio) // 价格越低分数越高
                    score += priceScore
                }
            }
            
            // 4. 座位可用性（权重：10%）
            let seatAvailabilityScore = Double(ride.availableSeats) / Double(ride.totalCapacity) * 10
            score += seatAvailabilityScore
            
            matchedRides.append((ride: ride, matchScore: score))
        }
        
        // 按匹配度排序
        matchedRides.sort { $0.matchScore > $1.matchScore }
        
        print("✅ 匹配完成: \(matchedRides.count) 条行程")
        if let best = matchedRides.first {
            print("   最佳匹配: 行程 \(best.ride.id), 分数: \(String(format: "%.2f", best.matchScore))")
        }
        
        return matchedRides
    }
    
    // MARK: - 距离计算
    
    /// 计算两个地点之间的距离（使用 Haversine 公式）
    /// - Parameters:
    ///   - coordinate1: 第一个坐标
    ///   - coordinate2: 第二个坐标
    /// - Returns: 距离（公里）
    static func calculateDistance(
        from coordinate1: CLLocationCoordinate2D,
        to coordinate2: CLLocationCoordinate2D
    ) -> Double {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        
        let distanceMeters = location1.distance(from: location2)
        let distanceKm = distanceMeters / 1000.0
        
        return distanceKm
    }
    
    /// 计算用户位置到行程地点的距离（使用地点名称）
    /// - Parameters:
    ///   - userCoordinate: 用户坐标
    ///   - locationName: 地点名称
    /// - Returns: 距离（公里），如果无法解析地点则返回 nil
    static func calculateDistance(
        from userCoordinate: CLLocationCoordinate2D,
        to locationName: String
    ) -> Double? {
        // 这里需要地理编码（Geocoding）
        // 实际应用中应该使用 MKLocalSearchCompleter 或缓存坐标
        
        // 示例：澳门常用地点坐标（可以扩展）
        let macaoLocations: [String: CLLocationCoordinate2D] = [
            "横琴口岸": CLLocationCoordinate2D(latitude: 22.1361, longitude: 113.5436),
            "澳门科技大学": CLLocationCoordinate2D(latitude: 22.1532, longitude: 113.5563),
            "澳门大学": CLLocationCoordinate2D(latitude: 22.1240, longitude: 113.5516),
            "澳门机场": CLLocationCoordinate2D(latitude: 22.1496, longitude: 113.5918),
            "威尼斯人酒店": CLLocationCoordinate2D(latitude: 22.1458, longitude: 113.5611),
            "澳门渔人码头": CLLocationCoordinate2D(latitude: 22.1901, longitude: 113.5486),
            "大三巴牌坊": CLLocationCoordinate2D(latitude: 22.1975, longitude: 113.5414),
            "新马路": CLLocationCoordinate2D(latitude: 22.1889, longitude: 113.5414)
        ]
        
        guard let targetCoordinate = macaoLocations[locationName] else {
            // 如果地点不在预设列表中，返回 nil
            // 实际应用中应该调用地理编码服务
            print("⚠️ 未找到地点坐标: \(locationName)")
            return nil
        }
        
        return calculateDistance(from: userCoordinate, to: targetCoordinate)
    }
    
    // MARK: - 路线规划
    
    /// 计算两地之间的路线和预估时间
    /// - Parameters:
    ///   - start: 起点坐标
    ///   - end: 终点坐标
    ///   - completion: 完成回调
    static func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        completion: @escaping (Result<RouteInfo, Error>) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("❌ 路线计算失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let route = response?.routes.first else {
                let error = NSError(
                    domain: "GeoMatchingService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "未找到路线"]
                )
                completion(.failure(error))
                return
            }
            
            let routeInfo = RouteInfo(
                distance: route.distance / 1000.0, // 转换为公里
                expectedTravelTime: route.expectedTravelTime, // 秒
                polyline: route.polyline
            )
            
            print("✅ 路线计算成功")
            print("   距离: \(String(format: "%.2f", routeInfo.distance))km")
            print("   预估时间: \(String(format: "%.0f", routeInfo.expectedTravelTime / 60))分钟")
            
            completion(.success(routeInfo))
        }
    }
    
    /// 批量计算路线（用于多个行程）
    static func calculateMultipleRoutes(
        rides: [AdvancedRide],
        userLocation: CLLocationCoordinate2D,
        completion: @escaping ([UUID: RouteInfo]) -> Void
    ) {
        var routeInfos: [UUID: RouteInfo] = [:]
        let group = DispatchGroup()
        
        for ride in rides {
            // 这里需要地理编码
            // 简化示例：假设已有坐标
            guard let startCoord = getCoordinateForLocation(ride.startLocation),
                  let endCoord = getCoordinateForLocation(ride.endLocation) else {
                continue
            }
            
            group.enter()
            calculateRoute(from: startCoord, to: endCoord) { result in
                if case .success(let routeInfo) = result {
                    routeInfos[ride.id] = routeInfo
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(routeInfos)
        }
    }
    
    // MARK: - Geohash（用于高级查询）
    
    /// 计算坐标的 Geohash（用于数据库索引）
    /// 注意：这是简化版本，实际应用中应该使用专业的 Geohash 库
    static func geohash(for coordinate: CLLocationCoordinate2D, precision: Int = 9) -> String {
        // 实际应用中应该使用成熟的 Geohash 库
        // 这里只是演示概念
        
        let latRange = (-90.0, 90.0)
        let lonRange = (-180.0, 180.0)
        
        var lat = coordinate.latitude
        var lon = coordinate.longitude
        
        var hash = ""
        let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        
        // 简化的 Geohash 算法
        for _ in 0..<precision {
            var idx = 0
            
            // 纬度
            let latMid = (latRange.0 + latRange.1) / 2
            if lat > latMid {
                idx |= 1
            }
            
            // 经度
            let lonMid = (lonRange.0 + lonRange.1) / 2
            if lon > lonMid {
                idx |= 2
            }
            
            hash.append(base32[base32.index(base32.startIndex, offsetBy: idx)])
        }
        
        return hash
    }
    
    // MARK: - Helper Methods
    
    /// 根据地点名称获取坐标（简化版本）
    private static func getCoordinateForLocation(_ locationName: String) -> CLLocationCoordinate2D? {
        let macaoLocations: [String: CLLocationCoordinate2D] = [
            "横琴口岸": CLLocationCoordinate2D(latitude: 22.1361, longitude: 113.5436),
            "澳门科技大学": CLLocationCoordinate2D(latitude: 22.1532, longitude: 113.5563),
            "澳门大学": CLLocationCoordinate2D(latitude: 22.1240, longitude: 113.5516),
            "澳门机场": CLLocationCoordinate2D(latitude: 22.1496, longitude: 113.5918),
            "威尼斯人酒店": CLLocationCoordinate2D(latitude: 22.1458, longitude: 113.5611)
        ]
        
        return macaoLocations[locationName]
    }
}

// MARK: - Route Info Model
/// 路线信息模型
struct RouteInfo {
    let distance: Double                // 距离（公里）
    let expectedTravelTime: TimeInterval // 预估时间（秒）
    let polyline: MKPolyline            // 路线折线（用于地图显示）
    
    /// 格式化的距离
    var formattedDistance: String {
        return String(format: "%.2f km", distance)
    }
    
    /// 格式化的时间
    var formattedTravelTime: String {
        let minutes = Int(expectedTravelTime / 60)
        if minutes < 60 {
            return "\(minutes) 分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) 小时 \(remainingMinutes) 分钟"
        }
    }
}

// MARK: - Location Search Service
/// 地点搜索服务（使用 MapKit）
class LocationSearchService: NSObject, ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching: Bool = false
    
    private var searchCompleter = MKLocalSearchCompleter()
    private var currentSearch: MKLocalSearch?
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        
        // 设置搜索区域为澳门
        let macaoCenter = CLLocationCoordinate2D(latitude: 22.1667, longitude: 113.5500)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        searchCompleter.region = MKCoordinateRegion(center: macaoCenter, span: span)
    }
    
    /// 搜索地点
    func search(query: String) {
        isSearching = true
        searchCompleter.queryFragment = query
    }
    
    /// 执行完整搜索
    func performSearch(for completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        currentSearch?.cancel()
        
        currentSearch = MKLocalSearch(request: request)
        currentSearch?.start { [weak self] response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 搜索失败: \(error.localizedDescription)")
                self.isSearching = false
                return
            }
            
            self.searchResults = response?.mapItems ?? []
            self.isSearching = false
            
            print("✅ 搜索结果: \(self.searchResults.count) 个")
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension LocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        print("📍 搜索结果更新: \(completer.results.count) 个")
        
        // 可以在这里处理自动完成结果
        if let firstResult = completer.results.first {
            performSearch(for: firstResult)
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("❌ 搜索失败: \(error.localizedDescription)")
        isSearching = false
    }
}
