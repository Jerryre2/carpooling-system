//
//  RideModels.swift
//  Advanced Ride-Sharing System
//
//  Created on 2025-12-07
//

import Foundation
import CoreLocation

// MARK: - Ride Status Enum
/// 行程状态枚举
enum RideStatus: String, Codable, CaseIterable {
    case pending = "pending"           // 等待接单/加入
    case accepted = "accepted"         // 已接单/已确认，开始追踪
    case enRoute = "enRoute"          // 正在前往接乘客
    case completed = "completed"       // 已完成
    
    var displayName: String {
        switch self {
        case .pending: return "待接单"
        case .accepted: return "已接单"
        case .enRoute: return "行程中"
        case .completed: return "已完成"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .enRoute: return "car.fill"
        case .completed: return "flag.checkered"
        }
    }
}

// MARK: - Ride Type Enum
/// 行程类型枚举（多态模型核心）
enum RideType: Codable, Equatable {
    case driverOffer(totalFare: Double)                          // 司机发车：固定总价
    case studentRequest(maxPassengers: Int, unitFare: Double)    // 学生求车：人数上限+客单价
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case type
        case totalFare
        case maxPassengers
        case unitFare
    }
    
    private enum TypeIdentifier: String, Codable {
        case driverOffer
        case studentRequest
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeIdentifier.self, forKey: .type)
        
        switch type {
        case .driverOffer:
            let totalFare = try container.decode(Double.self, forKey: .totalFare)
            self = .driverOffer(totalFare: totalFare)
        case .studentRequest:
            let maxPassengers = try container.decode(Int.self, forKey: .maxPassengers)
            let unitFare = try container.decode(Double.self, forKey: .unitFare)
            self = .studentRequest(maxPassengers: maxPassengers, unitFare: unitFare)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .driverOffer(let totalFare):
            try container.encode(TypeIdentifier.driverOffer, forKey: .type)
            try container.encode(totalFare, forKey: .totalFare)
        case .studentRequest(let maxPassengers, let unitFare):
            try container.encode(TypeIdentifier.studentRequest, forKey: .type)
            try container.encode(maxPassengers, forKey: .maxPassengers)
            try container.encode(unitFare, forKey: .unitFare)
        }
    }
    
    // MARK: - Helper Properties
    var isDriverOffer: Bool {
        if case .driverOffer = self { return true }
        return false
    }
    
    var isStudentRequest: Bool {
        if case .studentRequest = self { return true }
        return false
    }
    
    var displayTypeLabel: String {
        switch self {
        case .driverOffer: return "🚗 司机发车"
        case .studentRequest: return "🎓 学生求车"
        }
    }
}

// MARK: - Passenger Info
/// 乘客信息
struct PassengerInfo: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let phone: String
    let joinedAt: Date
    
    // 模拟的乘客位置（用于实时追踪）
    var simulatedLocation: (latitude: Double, longitude: Double)?
    
    enum CodingKeys: String, CodingKey {
        case id, name, phone, joinedAt
        case latitude, longitude
    }
    
    // MARK: - Equatable Implementation
    static func == (lhs: PassengerInfo, rhs: PassengerInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.phone == rhs.phone &&
               lhs.joinedAt == rhs.joinedAt &&
               lhs.simulatedLocation?.latitude == rhs.simulatedLocation?.latitude &&
               lhs.simulatedLocation?.longitude == rhs.simulatedLocation?.longitude
    }
    
    init(id: String, name: String, phone: String, joinedAt: Date = Date(), simulatedLocation: (latitude: Double, longitude: Double)? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.joinedAt = joinedAt
        self.simulatedLocation = simulatedLocation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        
        if let lat = try? container.decode(Double.self, forKey: .latitude),
           let lon = try? container.decode(Double.self, forKey: .longitude) {
            simulatedLocation = (lat, lon)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(joinedAt, forKey: .joinedAt)
        
        if let location = simulatedLocation {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
    }
}

// MARK: - Advanced Ride Model
/// 高级行程模型（核心数据结构）
struct AdvancedRide: Codable, Identifiable, Equatable {
    let id: UUID
    let rideType: RideType
    
    // 发布者信息
    var publisherID: String        // 发布者ID（司机或学生）
    let publisherName: String
    let publisherPhone: String
    
    // 行程基本信息
    let startLocation: String
    let endLocation: String
    let departureTime: Date
    
    // 座位和容量
    let totalCapacity: Int         // 总容量
    var availableSeats: Int        // 剩余座位
    var passengers: [PassengerInfo] // 已加入的乘客列表
    
    // 状态管理
    var status: RideStatus
    
    // 实时位置追踪
    var driverCurrentLocation: (latitude: Double, longitude: Double)?
    
    // 目的地坐标（用于ETA计算）
    var destinationLocation: (latitude: Double, longitude: Double)?
    
    // 备注信息
    let notes: String
    
    // MARK: - Equatable Implementation
    static func == (lhs: AdvancedRide, rhs: AdvancedRide) -> Bool {
        return lhs.id == rhs.id &&
               lhs.rideType == rhs.rideType &&
               lhs.publisherID == rhs.publisherID &&
               lhs.publisherName == rhs.publisherName &&
               lhs.publisherPhone == rhs.publisherPhone &&
               lhs.startLocation == rhs.startLocation &&
               lhs.endLocation == rhs.endLocation &&
               lhs.departureTime == rhs.departureTime &&
               lhs.totalCapacity == rhs.totalCapacity &&
               lhs.availableSeats == rhs.availableSeats &&
               lhs.passengers == rhs.passengers &&
               lhs.status == rhs.status &&
               lhs.driverCurrentLocation?.latitude == rhs.driverCurrentLocation?.latitude &&
               lhs.driverCurrentLocation?.longitude == rhs.driverCurrentLocation?.longitude &&
               lhs.destinationLocation?.latitude == rhs.destinationLocation?.latitude &&
               lhs.destinationLocation?.longitude == rhs.destinationLocation?.longitude &&
               lhs.notes == rhs.notes
    }
    
    // MARK: - Computed Properties
    
    /// 客单价（乘客视角）
    var unitPrice: Double {
        switch rideType {
        case .driverOffer(let totalFare):
            return totalCapacity > 0 ? totalFare / Double(totalCapacity) : totalFare
        case .studentRequest(_, let unitFare):
            return unitFare
        }
    }
    
    /// 预计收入（司机视角）
    var estimatedRevenue: Double {
        let currentPassengers = passengers.count
        
        switch rideType {
        case .driverOffer(let totalFare):
            // 司机发车：总价固定，但可以根据实际乘客数调整展示
            return totalFare
        case .studentRequest(_, let unitFare):
            // 学生求车：单价 × 当前乘客数
            return unitFare * Double(currentPassengers)
        }
    }
    
    /// 当前乘客数
    var currentPassengerCount: Int {
        return passengers.count
    }
    
    /// 是否已满座
    var isFull: Bool {
        return availableSeats <= 0
    }
    
    /// 是否可以接单（针对司机接学生求车）
    var canBeAccepted: Bool {
        return rideType.isStudentRequest && status == .pending
    }
    
    /// 是否可以加入（针对乘客加入司机发车）
    var canJoin: Bool {
        return rideType.isDriverOffer && status == .pending && availableSeats > 0
    }
    
    /// 格式化的出发时间
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: departureTime)
    }
    
    /// 格式化的状态标签
    var statusLabel: String {
        return status.displayName
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, rideType, publisherID, publisherName, publisherPhone
        case startLocation, endLocation, departureTime
        case totalCapacity, availableSeats, passengers
        case status, notes
        case driverLatitude, driverLongitude
        case destLatitude, destLongitude
    }
    
    init(id: UUID = UUID(),
         rideType: RideType,
         publisherID: String,
         publisherName: String,
         publisherPhone: String,
         startLocation: String,
         endLocation: String,
         departureTime: Date,
         totalCapacity: Int,
         availableSeats: Int? = nil,
         passengers: [PassengerInfo] = [],
         status: RideStatus = .pending,
         driverCurrentLocation: (latitude: Double, longitude: Double)? = nil,
         destinationLocation: (latitude: Double, longitude: Double)? = nil,
         notes: String = "") {
        
        self.id = id
        self.rideType = rideType
        self.publisherID = publisherID
        self.publisherName = publisherName
        self.publisherPhone = publisherPhone
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.departureTime = departureTime
        self.totalCapacity = totalCapacity
        self.availableSeats = availableSeats ?? totalCapacity
        self.passengers = passengers
        self.status = status
        self.driverCurrentLocation = driverCurrentLocation
        self.destinationLocation = destinationLocation
        self.notes = notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        rideType = try container.decode(RideType.self, forKey: .rideType)
        publisherID = try container.decode(String.self, forKey: .publisherID)
        publisherName = try container.decode(String.self, forKey: .publisherName)
        publisherPhone = try container.decode(String.self, forKey: .publisherPhone)
        startLocation = try container.decode(String.self, forKey: .startLocation)
        endLocation = try container.decode(String.self, forKey: .endLocation)
        departureTime = try container.decode(Date.self, forKey: .departureTime)
        totalCapacity = try container.decode(Int.self, forKey: .totalCapacity)
        availableSeats = try container.decode(Int.self, forKey: .availableSeats)
        passengers = try container.decode([PassengerInfo].self, forKey: .passengers)
        status = try container.decode(RideStatus.self, forKey: .status)
        notes = try container.decode(String.self, forKey: .notes)
        
        // 解码位置信息
        if let lat = try? container.decode(Double.self, forKey: .driverLatitude),
           let lon = try? container.decode(Double.self, forKey: .driverLongitude) {
            driverCurrentLocation = (lat, lon)
        }
        
        if let lat = try? container.decode(Double.self, forKey: .destLatitude),
           let lon = try? container.decode(Double.self, forKey: .destLongitude) {
            destinationLocation = (lat, lon)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(rideType, forKey: .rideType)
        try container.encode(publisherID, forKey: .publisherID)
        try container.encode(publisherName, forKey: .publisherName)
        try container.encode(publisherPhone, forKey: .publisherPhone)
        try container.encode(startLocation, forKey: .startLocation)
        try container.encode(endLocation, forKey: .endLocation)
        try container.encode(departureTime, forKey: .departureTime)
        try container.encode(totalCapacity, forKey: .totalCapacity)
        try container.encode(availableSeats, forKey: .availableSeats)
        try container.encode(passengers, forKey: .passengers)
        try container.encode(status, forKey: .status)
        try container.encode(notes, forKey: .notes)
        
        // 编码位置信息
        if let location = driverCurrentLocation {
            try container.encode(location.latitude, forKey: .driverLatitude)
            try container.encode(location.longitude, forKey: .driverLongitude)
        }
        
        if let location = destinationLocation {
            try container.encode(location.latitude, forKey: .destLatitude)
            try container.encode(location.longitude, forKey: .destLongitude)
        }
    }
}
