//
//  NewRideModels.swift
//  CarpoolingSystem - Refactored Models (Passenger-Publish, Driver-Accept)
//
//  Created on 2025-12-07
//  重构后的数据模型：乘客发单，司机接单
//

import Foundation
import CoreLocation

// MARK: - Trip Status Enum (新的状态流转)
/// 订单状态枚举（完整的生命周期）
enum TripStatus: String, Codable, CaseIterable {
    case pending = "pending"                   // 发布中（等待司机接单）
    case accepted = "accepted"                 // 司机已接单（等待乘客支付）
    case awaitingPayment = "awaiting_payment"  // 待支付（司机已接单，人数已满）
    case paid = "paid"                         // 已支付（待出发）
    case inProgress = "in_progress"            // 行程中
    case completed = "completed"               // 已完成
    case cancelled = "cancelled"               // 已取消
    
    var displayName: String {
        switch self {
        case .pending:
            return "等待接单"
        case .accepted:
            return "司机已接单"
        case .awaitingPayment:
            return "待支付"
        case .paid:
            return "待出发"
        case .inProgress:
            return "行程中"
        case .completed:
            return "已完成"
        case .cancelled:
            return "已取消"
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .accepted:
            return "checkmark.circle.fill"
        case .awaitingPayment:
            return "creditcard.fill"
        case .paid:
            return "dollarsign.circle.fill"
        case .inProgress:
            return "car.fill"
        case .completed:
            return "flag.checkered"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .accepted:
            return "blue"
        case .awaitingPayment:
            return "purple"
        case .paid:
            return "green"
        case .inProgress:
            return "indigo"
        case .completed:
            return "gray"
        case .cancelled:
            return "red"
        }
    }
}

// MARK: - Trip Request Model (乘客发布的行程请求)
/// 行程请求模型（核心数据结构）
struct TripRequest: Codable, Identifiable, Equatable {
    let id: UUID
    
    // MARK: - 乘客信息
    let passengerID: String           // 发布乘客的 ID
    let passengerName: String          // 乘客姓名
    let passengerPhone: String         // 乘客电话
    
    // MARK: - 行程基本信息
    let startLocation: String          // 出发地名称
    let startCoordinate: Coordinate    // 出发地坐标
    let endLocation: String            // 目的地名称
    let endCoordinate: Coordinate      // 目的地坐标
    let departureTime: Date            // 出发时间
    
    // MARK: - 乘客数量与费用
    let numberOfPassengers: Int        // 乘客人数（可以是1人或多人拼车）
    let pricePerPerson: Double         // 单人费用
    
    // MARK: - 司机信息（接单后填充）
    var driverID: String?              // 接单司机 ID
    var driverName: String?            // 司机姓名
    var driverPhone: String?           // 司机电话
    var driverCurrentLocation: Coordinate? // 司机实时位置
    
    // MARK: - 状态管理
    var status: TripStatus             // 订单状态
    
    // MARK: - 支付信息
    var paymentTransactionID: String?  // 支付交易 ID
    var paidAt: Date?                  // 支付时间
    
    // MARK: - 时间戳
    let createdAt: Date                // 创建时间
    var updatedAt: Date                // 更新时间
    
    // MARK: - 备注
    let notes: String                  // 备注信息
    
    // MARK: - Computed Properties
    
    /// 预期收入（司机视角）
    var expectedIncome: Double {
        return pricePerPerson * Double(numberOfPassengers)
    }
    
    /// 总费用（乘客视角）
    var totalCost: Double {
        return expectedIncome
    }
    
    /// 格式化的出发时间
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: departureTime)
    }
    
    /// 格式化的创建时间
    var formattedCreatedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }
    
    /// 是否可以接单（司机视角）
    var canBeAccepted: Bool {
        return status == .pending && driverID == nil
    }
    
    /// 是否需要支付（乘客视角）
    var needsPayment: Bool {
        return status == .awaitingPayment && paidAt == nil
    }
    
    /// 是否已接单
    var isAccepted: Bool {
        return driverID != nil && status != .pending
    }
    
    /// 距离出发还有多久（分钟）
    var minutesUntilDeparture: Int {
        let interval = departureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }
    
    /// 是否在指定时间窗口内（用于筛选）
    /// - Parameter targetTime: 目标时间
    /// - Parameter windowMinutes: 时间窗口（分钟）
    /// - Returns: 是否在窗口内
    func isWithinTimeWindow(of targetTime: Date, windowMinutes: Int = 10) -> Bool {
        let difference = abs(departureTime.timeIntervalSince(targetTime))
        let windowSeconds = Double(windowMinutes * 60)
        return difference <= windowSeconds
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        passengerID: String,
        passengerName: String,
        passengerPhone: String,
        startLocation: String,
        startCoordinate: Coordinate,
        endLocation: String,
        endCoordinate: Coordinate,
        departureTime: Date,
        numberOfPassengers: Int,
        pricePerPerson: Double,
        driverID: String? = nil,
        driverName: String? = nil,
        driverPhone: String? = nil,
        driverCurrentLocation: Coordinate? = nil,
        status: TripStatus = .pending,
        paymentTransactionID: String? = nil,
        paidAt: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.passengerID = passengerID
        self.passengerName = passengerName
        self.passengerPhone = passengerPhone
        self.startLocation = startLocation
        self.startCoordinate = startCoordinate
        self.endLocation = endLocation
        self.endCoordinate = endCoordinate
        self.departureTime = departureTime
        self.numberOfPassengers = numberOfPassengers
        self.pricePerPerson = pricePerPerson
        self.driverID = driverID
        self.driverName = driverName
        self.driverPhone = driverPhone
        self.driverCurrentLocation = driverCurrentLocation
        self.status = status
        self.paymentTransactionID = paymentTransactionID
        self.paidAt = paidAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.notes = notes
    }
    
    // MARK: - Equatable
    static func == (lhs: TripRequest, rhs: TripRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Coordinate Model
/// 坐标模型（简化版，支持 Codable）
struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    /// 转换为 CLLocationCoordinate2D
    var clCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 从 CLLocationCoordinate2D 创建
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    /// 计算与另一个坐标的距离（单位：米）
    func distance(to other: Coordinate) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
    
    /// 计算与另一个坐标的距离（单位：公里）
    func distanceInKilometers(to other: Coordinate) -> Double {
        return distance(to: other) / 1000.0
    }
    
    /// 是否在指定坐标的附近（默认 500 米内）
    func isNear(_ other: Coordinate, within meters: Double = 500) -> Bool {
        return distance(to: other) <= meters
    }
}

// MARK: - Refactored User Model (重构后的用户模型)
/// 用户模型（包含钱包功能）- 使用 RefactoredUser 避免与项目中其他 User 冲突
struct RefactoredUser: Codable, Identifiable {
    let id: String                     // 用户 ID
    var name: String                   // 姓名
    var phone: String                  // 电话
    var role: RefactoredUserRole       // 角色（司机或乘客）
    var walletBalance: Double          // 钱包余额
    var profileImageURL: String?       // 头像 URL
    
    // MARK: - 统计信息
    var totalTripsAsPassenger: Int     // 作为乘客的订单数
    var totalTripsAsDriver: Int        // 作为司机的订单数
    var rating: Double                 // 评分（1-5）
    var totalEarnings: Double          // 作为司机的总收入
    
    // MARK: - 时间戳
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        name: String,
        phone: String,
        role: RefactoredUserRole,
        walletBalance: Double = 0.0,
        profileImageURL: String? = nil,
        totalTripsAsPassenger: Int = 0,
        totalTripsAsDriver: Int = 0,
        rating: Double = 5.0,
        totalEarnings: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.role = role
        self.walletBalance = walletBalance
        self.profileImageURL = profileImageURL
        self.totalTripsAsPassenger = totalTripsAsPassenger
        self.totalTripsAsDriver = totalTripsAsDriver
        self.rating = rating
        self.totalEarnings = totalEarnings
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Refactored User Role Enum
/// 用户角色枚举（重构版）- 使用 RefactoredUserRole 避免冲突
enum RefactoredUserRole: String, Codable {
    case passenger = "passenger"       // 乘客
    case driver = "driver"             // 司机
    case both = "both"                 // 既是司机也是乘客
    
    var displayName: String {
        switch self {
        case .passenger:
            return "乘客"
        case .driver:
            return "司机"
        case .both:
            return "司机/乘客"
        }
    }
}

// MARK: - Refactored Payment Transaction Model
/// 支付交易记录 - 使用 RefactoredPaymentTransaction 避免冲突
struct RefactoredPaymentTransaction: Codable, Identifiable {
    let id: UUID
    let userID: String                 // 用户 ID
    let tripID: UUID                   // 关联的行程 ID
    let amount: Double                 // 金额
    let type: RefactoredTransactionType  // 交易类型
    let status: RefactoredPaymentStatus  // 支付状态
    let createdAt: Date                // 创建时间
    
    init(
        id: UUID = UUID(),
        userID: String,
        tripID: UUID,
        amount: Double,
        type: RefactoredTransactionType,
        status: RefactoredPaymentStatus = .completed
    ) {
        self.id = id
        self.userID = userID
        self.tripID = tripID
        self.amount = amount
        self.type = type
        self.status = status
        self.createdAt = Date()
    }
}

// MARK: - Refactored Transaction Type Enum
enum RefactoredTransactionType: String, Codable {
    case payment = "payment"           // 支付行程费用
    case refund = "refund"             // 退款
    case topUp = "top_up"              // 充值
    case earning = "earning"           // 司机收入
    
    var displayName: String {
        switch self {
        case .payment:
            return "支付"
        case .refund:
            return "退款"
        case .topUp:
            return "充值"
        case .earning:
            return "收入"
        }
    }
}

// MARK: - Refactored Payment Status Enum
enum RefactoredPaymentStatus: String, Codable {
    case pending = "pending"           // 待处理
    case completed = "completed"       // 已完成
    case failed = "failed"             // 失败
    case refunded = "refunded"         // 已退款
    
    var displayName: String {
        switch self {
        case .pending:
            return "待处理"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .refunded:
            return "已退款"
        }
    }
}

// MARK: - Search Filter Model
/// 搜索筛选条件
struct TripSearchFilter {
    var startLocation: Coordinate?     // 起点坐标
    var endLocation: Coordinate?       // 终点坐标
    var departureTime: Date?           // 出发时间
    var maxPricePerPerson: Double?     // 最高单价
    var minSeats: Int = 1              // 最少座位数
    
    // 匹配范围设置
    var locationRadiusMeters: Double = 500   // 位置匹配半径（米）
    var timeWindowMinutes: Int = 10          // 时间窗口（分钟）
}

// MARK: - Demo Data Extensions
#if DEBUG
extension TripRequest {
    /// 生成演示数据
    static var demoTrips: [TripRequest] {
        let now = Date()
        
        return [
            TripRequest(
                passengerID: "passenger_001",
                passengerName: "张小明",
                passengerPhone: "+853 6611 1111",
                startLocation: "澳门科技大学",
                startCoordinate: Coordinate(latitude: 22.2015, longitude: 113.5495),
                endLocation: "澳门机场",
                endCoordinate: Coordinate(latitude: 22.1560, longitude: 113.5920),
                departureTime: now.addingTimeInterval(3600),
                numberOfPassengers: 2,
                pricePerPerson: 40.0,
                notes: "有2个人，需要帮忙搬行李"
            ),
            
            TripRequest(
                passengerID: "passenger_002",
                passengerName: "李小红",
                passengerPhone: "+853 6622 2222",
                startLocation: "澳门大学",
                startCoordinate: Coordinate(latitude: 22.1965, longitude: 113.5380),
                endLocation: "威尼斯人酒店",
                endCoordinate: Coordinate(latitude: 22.1463, longitude: 113.5600),
                departureTime: now.addingTimeInterval(1800),
                numberOfPassengers: 1,
                pricePerPerson: 35.0,
                notes: "单人出行"
            ),
            
            TripRequest(
                passengerID: "passenger_003",
                passengerName: "王大力",
                passengerPhone: "+853 6633 3333",
                startLocation: "横琴口岸",
                startCoordinate: Coordinate(latitude: 22.1987, longitude: 113.5439),
                endLocation: "新马路",
                endCoordinate: Coordinate(latitude: 22.1884, longitude: 113.5387),
                departureTime: now.addingTimeInterval(7200),
                numberOfPassengers: 3,
                pricePerPerson: 25.0,
                driverID: "driver_001",
                driverName: "赵师傅",
                status: .accepted,
                notes: "3人拼车"
            )
        ]
    }
}

extension RefactoredUser {
    /// 生成演示用户
    static var demoPassenger: RefactoredUser {
        RefactoredUser(
            id: "passenger_demo",
            name: "测试乘客",
            phone: "+853 6666 6666",
            role: .passenger,
            walletBalance: 500.0
        )
    }
    
    static var demoDriver: RefactoredUser {
        RefactoredUser(
            id: "driver_demo",
            name: "测试司机",
            phone: "+853 8888 8888",
            role: .driver,
            walletBalance: 0.0,
            totalEarnings: 1250.0
        )
    }
}
#endif
