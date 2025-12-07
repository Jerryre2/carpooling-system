//
//  RideDataStore.swift
//  Advanced Ride-Sharing System
//
//  Created on 2025-12-07
//

import Foundation
import Combine
import CoreLocation

// MARK: - User Role for Search Context
enum SearchUserRole {
    case driver    // 司机视角：搜索学生求车
    case passenger // 乘客视角：搜索司机发车
}

// MARK: - Ride Data Store
/// 全局状态管理器（ObservableObject）
class RideDataStore: ObservableObject {
    
    // MARK: - Published Properties
    @Published var rides: [AdvancedRide] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // 模拟位置数据库（用于追踪）
    private var passengerLocations: [String: (latitude: Double, longitude: Double)] = [:]
    
    // MARK: - Initialization
    init() {
        loadDemoData()
        setupSimulatedLocations()
    }
    
    // MARK: - Search Rides
    /// 根据用户角色搜索行程
    /// - Parameter userRole: 用户角色（司机或乘客）
    /// - Returns: 过滤后的行程列表
    func searchRides(userRole: SearchUserRole) -> [AdvancedRide] {
        switch userRole {
        case .passenger:
            // 乘客只看司机发车的行程
            return rides.filter { $0.rideType.isDriverOffer && $0.status == .pending }
        case .driver:
            // 司机只看学生求车的行程
            return rides.filter { $0.rideType.isStudentRequest && $0.status == .pending }
        }
    }
    
    // MARK: - Passenger Actions
    
    /// 乘客加入行程
    /// - Parameters:
    ///   - ride: 要加入的行程
    ///   - passengerID: 乘客ID
    ///   - passengerName: 乘客姓名
    ///   - passengerPhone: 乘客电话
    func joinRide(ride: AdvancedRide, passengerID: String, passengerName: String, passengerPhone: String) {
        guard let index = rides.firstIndex(where: { $0.id == ride.id }) else {
            errorMessage = "未找到该行程"
            return
        }
        
        var updatedRide = rides[index]
        
        // 前置检查
        guard updatedRide.rideType.isDriverOffer else {
            errorMessage = "只能加入司机发布的行程"
            return
        }
        
        guard updatedRide.availableSeats > 0 else {
            errorMessage = "座位已满，无法加入"
            return
        }
        
        guard !updatedRide.passengers.contains(where: { $0.id == passengerID }) else {
            errorMessage = "您已经加入过此行程"
            return
        }
        
        // 创建乘客信息
        let passenger = PassengerInfo(
            id: passengerID,
            name: passengerName,
            phone: passengerPhone,
            joinedAt: Date(),
            simulatedLocation: generateRandomLocation(near: updatedRide.driverCurrentLocation)
        )
        
        // 更新行程数据
        updatedRide.passengers.append(passenger)
        updatedRide.availableSeats -= 1
        
        // 如果座位满了，自动改为已接单状态
        if updatedRide.availableSeats == 0 {
            updatedRide.status = .accepted
        }
        
        rides[index] = updatedRide
        successMessage = "成功加入行程！"
        
        // 记录乘客位置
        if let location = passenger.simulatedLocation {
            passengerLocations[passengerID] = location
        }
    }
    
    /// 乘客取消行程
    /// - Parameters:
    ///   - ride: 要取消的行程
    ///   - passengerID: 乘客ID
    func cancelJoin(ride: AdvancedRide, passengerID: String) {
        guard let index = rides.firstIndex(where: { $0.id == ride.id }) else {
            errorMessage = "未找到该行程"
            return
        }
        
        var updatedRide = rides[index]
        
        guard let passengerIndex = updatedRide.passengers.firstIndex(where: { $0.id == passengerID }) else {
            errorMessage = "您未加入此行程"
            return
        }
        
        // 移除乘客
        updatedRide.passengers.remove(at: passengerIndex)
        updatedRide.availableSeats += 1
        
        // 如果之前是已接单状态，重置为待接单
        if updatedRide.status == .accepted && updatedRide.availableSeats > 0 {
            updatedRide.status = .pending
        }
        
        rides[index] = updatedRide
        successMessage = "已取消行程"
        
        // 移除乘客位置记录
        passengerLocations.removeValue(forKey: passengerID)
    }
    
    // MARK: - Driver Actions
    
    /// 司机接单（接受学生求车）
    /// - Parameters:
    ///   - ride: 要接受的行程
    ///   - driverID: 司机ID
    func acceptRequest(ride: AdvancedRide, driverID: String) {
        guard let index = rides.firstIndex(where: { $0.id == ride.id }) else {
            errorMessage = "未找到该行程"
            return
        }
        
        var updatedRide = rides[index]
        
        // 前置检查
        guard updatedRide.rideType.isStudentRequest else {
            errorMessage = "只能接受学生发布的求车请求"
            return
        }
        
        guard updatedRide.status == .pending else {
            errorMessage = "该行程已被其他司机接单"
            return
        }
        
        // 更新行程数据
        updatedRide.publisherID = driverID  // 将发布者改为司机ID
        updatedRide.status = .accepted
        
        // 设置司机初始位置（模拟）
        if updatedRide.driverCurrentLocation == nil {
            updatedRide.driverCurrentLocation = generateRandomLocation(near: nil)
        }
        
        rides[index] = updatedRide
        successMessage = "成功接单！"
    }
    
    /// 司机开始出发（状态转为enRoute）
    /// - Parameter ride: 行程
    func startEnRoute(ride: AdvancedRide) {
        guard let index = rides.firstIndex(where: { $0.id == ride.id }) else {
            errorMessage = "未找到该行程"
            return
        }
        
        var updatedRide = rides[index]
        
        guard updatedRide.status == .accepted else {
            errorMessage = "只能在已接单状态下开始出发"
            return
        }
        
        updatedRide.status = .enRoute
        rides[index] = updatedRide
        successMessage = "已开始行程"
    }
    
    /// 司机完成行程
    /// - Parameter ride: 行程
    func completeRide(ride: AdvancedRide) {
        guard let index = rides.firstIndex(where: { $0.id == ride.id }) else {
            errorMessage = "未找到该行程"
            return
        }
        
        var updatedRide = rides[index]
        
        guard updatedRide.status == .enRoute || updatedRide.status == .accepted else {
            errorMessage = "只能在行程中或已接单状态下完成行程"
            return
        }
        
        updatedRide.status = .completed
        rides[index] = updatedRide
        successMessage = "行程已完成"
    }
    
    // MARK: - Location Tracking
    
    /// 更新司机实时位置
    /// - Parameters:
    ///   - rideID: 行程ID
    ///   - location: 新位置（经纬度）
    func updateDriverLocation(rideID: UUID, location: (latitude: Double, longitude: Double)) {
        guard let index = rides.firstIndex(where: { $0.id == rideID }) else {
            return
        }
        
        rides[index].driverCurrentLocation = location
    }
    
    /// 获取乘客实时位置（模拟）
    /// - Parameter passengerID: 乘客ID
    /// - Returns: 乘客位置（经纬度）
    func getPassengerLocation(passengerID: String) -> (latitude: Double, longitude: Double)? {
        return passengerLocations[passengerID]
    }
    
    /// 计算预计到达时间（ETA）
    /// - Parameters:
    ///   - driverLocation: 司机当前位置
    ///   - destinationLocation: 目的地位置
    /// - Returns: 预计到达时间（分钟）
    func calculateETA(driverLocation: (latitude: Double, longitude: Double),
                      destinationLocation: (latitude: Double, longitude: Double)) -> Int {
        
        // 使用 CLLocation 计算直线距离
        let driverCLLocation = CLLocation(latitude: driverLocation.latitude, longitude: driverLocation.longitude)
        let destCLLocation = CLLocation(latitude: destinationLocation.latitude, longitude: destinationLocation.longitude)
        
        let distanceInMeters = driverCLLocation.distance(from: destCLLocation)
        
        // 假设平均速度为 40 km/h = 666.67 m/min
        let averageSpeedMetersPerMinute: Double = 666.67
        
        let etaMinutes = Int(ceil(distanceInMeters / averageSpeedMetersPerMinute))
        
        return max(etaMinutes, 1) // 至少返回1分钟
    }
    
    /// 模拟司机位置移动（用于演示）
    /// - Parameter rideID: 行程ID
    func simulateDriverMovement(rideID: UUID) {
        guard let index = rides.firstIndex(where: { $0.id == rideID }),
              let currentLocation = rides[index].driverCurrentLocation,
              let destination = rides[index].destinationLocation else {
            return
        }
        
        // 计算移动方向（简化版：直线移动）
        let deltaLat = (destination.latitude - currentLocation.latitude) * 0.1
        let deltaLon = (destination.longitude - currentLocation.longitude) * 0.1
        
        let newLocation = (
            latitude: currentLocation.latitude + deltaLat,
            longitude: currentLocation.longitude + deltaLon
        )
        
        updateDriverLocation(rideID: rideID, location: newLocation)
    }
    
    // MARK: - Ride Management
    
    /// 添加新行程
    /// - Parameter ride: 新行程
    func addRide(_ ride: AdvancedRide) {
        rides.append(ride)
        successMessage = "发布成功"
    }
    
    /// 删除行程
    /// - Parameter ride: 要删除的行程
    func deleteRide(_ ride: AdvancedRide) {
        rides.removeAll { $0.id == ride.id }
        successMessage = "已删除行程"
    }
    
    /// 获取指定行程
    /// - Parameter id: 行程ID
    /// - Returns: 行程对象
    func getRide(by id: UUID) -> AdvancedRide? {
        return rides.first { $0.id == id }
    }
    
    // MARK: - Helper Methods
    
    /// 生成随机位置（用于模拟）
    /// - Parameter near: 基准位置（可选）
    /// - Returns: 随机位置
    private func generateRandomLocation(near baseLocation: (latitude: Double, longitude: Double)?) -> (latitude: Double, longitude: Double) {
        if let base = baseLocation {
            // 在基准位置附近生成（±0.01度范围内）
            return (
                latitude: base.latitude + Double.random(in: -0.01...0.01),
                longitude: base.longitude + Double.random(in: -0.01...0.01)
            )
        } else {
            // 生成澳门区域的随机位置（澳门大致范围）
            return (
                latitude: 22.1987 + Double.random(in: -0.05...0.05),
                longitude: 113.5439 + Double.random(in: -0.05...0.05)
            )
        }
    }
    
    /// 设置模拟位置数据
    private func setupSimulatedLocations() {
        // 为演示数据设置模拟位置
        passengerLocations = [
            "passenger1": (22.2015, 113.5495),
            "passenger2": (22.1965, 113.5380),
            "passenger3": (22.2040, 113.5520)
        ]
    }
    
    // MARK: - Demo Data
    
    /// 加载演示数据
    private func loadDemoData() {
        let now = Date()
        
        // 司机发车示例1
        let driverRide1 = AdvancedRide(
            rideType: .driverOffer(totalFare: 120.0),
            publisherID: "driver001",
            publisherName: "张师傅",
            publisherPhone: "+853 6688 8888",
            startLocation: "横琴口岸",
            endLocation: "澳门科技大学",
            departureTime: now.addingTimeInterval(3600),
            totalCapacity: 4,
            status: .pending,
            driverCurrentLocation: (22.1987, 113.5439),
            destinationLocation: (22.2015, 113.5495),
            notes: "舒适商务车，可放行李"
        )
        
        // 司机发车示例2
        let driverRide2 = AdvancedRide(
            rideType: .driverOffer(totalFare: 80.0),
            publisherID: "driver002",
            publisherName: "李师傅",
            publisherPhone: "+853 6699 9999",
            startLocation: "澳门机场",
            endLocation: "澳门大学",
            departureTime: now.addingTimeInterval(7200),
            totalCapacity: 3,
            availableSeats: 1,
            passengers: [
                PassengerInfo(id: "passenger1", name: "王小明", phone: "+853 6611 1111", simulatedLocation: (22.1965, 113.5380)),
                PassengerInfo(id: "passenger2", name: "李小红", phone: "+853 6622 2222", simulatedLocation: (22.2040, 113.5520))
            ],
            status: .accepted,
            driverCurrentLocation: (22.1560, 113.5920),
            destinationLocation: (22.1965, 113.5380),
            notes: "准时出发"
        )
        
        // 学生求车示例1
        let studentRequest1 = AdvancedRide(
            rideType: .studentRequest(maxPassengers: 3, unitFare: 25.0),
            publisherID: "student001",
            publisherName: "陈同学",
            publisherPhone: "+853 6633 3333",
            startLocation: "澳门科技大学",
            endLocation: "威尼斯人酒店",
            departureTime: now.addingTimeInterval(5400),
            totalCapacity: 3,
            status: .pending,
            destinationLocation: (22.1463, 113.5600),
            notes: "有3个人，寻找拼车"
        )
        
        // 学生求车示例2
        let studentRequest2 = AdvancedRide(
            rideType: .studentRequest(maxPassengers: 2, unitFare: 30.0),
            publisherID: "student002",
            publisherName: "刘同学",
            publisherPhone: "+853 6644 4444",
            startLocation: "澳门大学",
            endLocation: "新马路",
            departureTime: now.addingTimeInterval(10800),
            totalCapacity: 2,
            status: .pending,
            destinationLocation: (22.1884, 113.5387),
            notes: "市区观光"
        )
        
        // 已完成的行程示例
        let completedRide = AdvancedRide(
            rideType: .driverOffer(totalFare: 100.0),
            publisherID: "driver003",
            publisherName: "赵师傅",
            publisherPhone: "+853 6655 5555",
            startLocation: "氹仔码头",
            endLocation: "澳门旅游塔",
            departureTime: now.addingTimeInterval(-3600),
            totalCapacity: 4,
            availableSeats: 0,
            passengers: [
                PassengerInfo(id: "passenger3", name: "周小华", phone: "+853 6677 7777"),
                PassengerInfo(id: "passenger4", name: "吴小丽", phone: "+853 6688 8888")
            ],
            status: .completed,
            notes: "已完成"
        )
        
        rides = [driverRide1, driverRide2, studentRequest1, studentRequest2, completedRide]
    }
}
