//
//  UserModels.swift
//  CarpoolingSystem - Commercial Grade User Management
//
//  Created on 2025-12-07
//

import Foundation
import FirebaseFirestore

// MARK: - User Role Enum
/// 用户角色枚举
/// 重命名为 AppUserRole 避免与其他模块的 UserRole 冲突
public enum AppUserRole: String, Codable {
    case carOwner = "carOwner"     // 车主（可发布行程）
    case passenger = "passenger"   // 乘客（可预订行程）
    
    public var displayName: String {
        switch self {
        case .carOwner: return "车主"
        case .passenger: return "乘客"
        }
    }
    
    public var icon: String {
        switch self {
        case .carOwner: return "car.fill"
        case .passenger: return "person.fill"
        }
    }
}

// MARK: - Backward Compatibility
/// 为了向后兼容，提供 UserRole 别名
/// 注意：建议直接使用 AppUserRole 以避免命名冲突
public typealias UserRole = AppUserRole

// MARK: - Verification Status
/// 认证状态
enum VerificationStatus: String, Codable {
    case pending = "pending"       // 待认证
    case verified = "verified"     // 已认证
    case rejected = "rejected"     // 已拒绝
    
    var displayName: String {
        switch self {
        case .pending: return "待认证"
        case .verified: return "已认证"
        case .rejected: return "已拒绝"
        }
    }
}

// MARK: - Vehicle Information
/// 车辆信息
struct VehicleInfo: Codable, Equatable {
    var carPlateNumber: String           // 车牌号
    var carModel: String                 // 车型
    var carColor: String                 // 车辆颜色
    var insuranceExpiryDate: Date       // 保险到期日期
    var driverLicenseNumber: String?    // 驾驶证号
    var verificationStatus: VerificationStatus  // 认证状态
    
    var isInsuranceValid: Bool {
        return insuranceExpiryDate > Date()
    }
    
    var isVerified: Bool {
        return verificationStatus == .verified
    }
}

// MARK: - User Model
/// 应用用户模型（商业级）
/// 重命名为 AppUser 以避免与 FirebaseAuth.User 冲突
struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    
    // 基本信息（必填）
    var name: String
    var email: String
    var phone: String
    var avatarURL: String?              // 头像URL
    
    // 角色和权限
    var role: UserRole
    
    // 车主专属信息（可选）
    var vehicleInfo: VehicleInfo?
    
    // 统计信息
    var rating: Double                  // 评分 (0.0 - 5.0)
    var completedRides: Int            // 完成的行程数
    var totalRidesAsDriver: Int        // 作为司机的行程数
    var totalRidesAsPassenger: Int     // 作为乘客的行程数
    var joinDate: Date                 // 加入日期
    
    // 账户状态
    var isActive: Bool                 // 账户是否活跃
    var isBanned: Bool                 // 是否被封禁
    var banReason: String?             // 封禁原因
    
    // FCM 推送通知 Token
    var fcmToken: String?              // Firebase Cloud Messaging Token
    
    // 实名认证
    var isRealNameVerified: Bool       // 是否实名认证
    var realName: String?              // 真实姓名
    var idCardNumber: String?          // 身份证号（加密存储）
    
    // 偏好设置
    var preferences: UserPreferences?
    
    // MARK: - Computed Properties
    
    /// 是否是车主
    var isCarOwner: Bool {
        return role == .carOwner
    }
    
    /// 车主信息是否完整且有效
    var hasValidVehicleInfo: Bool {
        guard let vehicle = vehicleInfo else { return false }
        return !vehicle.carPlateNumber.isEmpty &&
               vehicle.isInsuranceValid &&
               vehicle.isVerified
    }
    
    /// 是否可以发布行程（车主专属权限）
    var canPublishRide: Bool {
        return isCarOwner && hasValidVehicleInfo && isActive && !isBanned
    }
    
    /// 是否可以预订行程
    var canBookRide: Bool {
        return isActive && !isBanned
    }
    
    /// 加入天数
    var daysSinceJoined: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
        return days
    }
    
    /// 格式化的加入日期
    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: joinDate)
    }
    
    /// 车牌号（简化访问）
    var carPlateNumber: String? {
        return vehicleInfo?.carPlateNumber
    }
    
    /// 保险到期日（简化访问）
    var insuranceExpiryDate: Date? {
        return vehicleInfo?.insuranceExpiryDate
    }
    
    // MARK: - Initializers
    
    /// 完整初始化器
    init(
        id: String? = nil,
        name: String,
        email: String,
        phone: String,
        avatarURL: String? = nil,
        role: UserRole,
        vehicleInfo: VehicleInfo? = nil,
        rating: Double = 5.0,
        completedRides: Int = 0,
        totalRidesAsDriver: Int = 0,
        totalRidesAsPassenger: Int = 0,
        joinDate: Date = Date(),
        isActive: Bool = true,
        isBanned: Bool = false,
        banReason: String? = nil,
        fcmToken: String? = nil,
        isRealNameVerified: Bool = false,
        realName: String? = nil,
        idCardNumber: String? = nil,
        preferences: UserPreferences? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.avatarURL = avatarURL
        self.role = role
        self.vehicleInfo = vehicleInfo
        self.rating = rating
        self.completedRides = completedRides
        self.totalRidesAsDriver = totalRidesAsDriver
        self.totalRidesAsPassenger = totalRidesAsPassenger
        self.joinDate = joinDate
        self.isActive = isActive
        self.isBanned = isBanned
        self.banReason = banReason
        self.fcmToken = fcmToken
        self.isRealNameVerified = isRealNameVerified
        self.realName = realName
        self.idCardNumber = idCardNumber
        self.preferences = preferences
    }
    
    /// 简化初始化器（用于基本注册）
    init(
        id: String?,
        name: String,
        email: String,
        phone: String,
        rating: Double,
        completedRides: Int,
        joinDate: Date,
        role: UserRole,
        carPlateNumber: String? = nil,
        insuranceExpiryDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.avatarURL = nil
        self.role = role
        
        // 如果提供了车主信息，创建 VehicleInfo
        if let carPlate = carPlateNumber, let insurance = insuranceExpiryDate {
            self.vehicleInfo = VehicleInfo(
                carPlateNumber: carPlate,
                carModel: "",
                carColor: "",
                insuranceExpiryDate: insurance,
                driverLicenseNumber: nil,
                verificationStatus: .pending
            )
        } else {
            self.vehicleInfo = nil
        }
        
        self.rating = rating
        self.completedRides = completedRides
        self.totalRidesAsDriver = 0
        self.totalRidesAsPassenger = 0
        self.joinDate = joinDate
        self.isActive = true
        self.isBanned = false
        self.banReason = nil
        self.fcmToken = nil
        self.isRealNameVerified = false
        self.realName = nil
        self.idCardNumber = nil
        self.preferences = nil
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case avatarURL
        case role
        case vehicleInfo
        case rating
        case completedRides
        case totalRidesAsDriver
        case totalRidesAsPassenger
        case joinDate
        case isActive
        case isBanned
        case banReason
        case fcmToken
        case isRealNameVerified
        case realName
        case idCardNumber
        case preferences
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.email = try container.decode(String.self, forKey: .email)
        self.phone = try container.decode(String.self, forKey: .phone)
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        self.role = try container.decode(UserRole.self, forKey: .role)
        self.vehicleInfo = try container.decodeIfPresent(VehicleInfo.self, forKey: .vehicleInfo)
        self.rating = try container.decode(Double.self, forKey: .rating)
        self.completedRides = try container.decode(Int.self, forKey: .completedRides)
        self.totalRidesAsDriver = try container.decode(Int.self, forKey: .totalRidesAsDriver)
        self.totalRidesAsPassenger = try container.decode(Int.self, forKey: .totalRidesAsPassenger)
        self.joinDate = try container.decode(Date.self, forKey: .joinDate)
        self.isActive = try container.decode(Bool.self, forKey: .isActive)
        self.isBanned = try container.decode(Bool.self, forKey: .isBanned)
        self.banReason = try container.decodeIfPresent(String.self, forKey: .banReason)
        self.fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        self.isRealNameVerified = try container.decode(Bool.self, forKey: .isRealNameVerified)
        self.realName = try container.decodeIfPresent(String.self, forKey: .realName)
        self.idCardNumber = try container.decodeIfPresent(String.self, forKey: .idCardNumber)
        self.preferences = try container.decodeIfPresent(UserPreferences.self, forKey: .preferences)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(vehicleInfo, forKey: .vehicleInfo)
        try container.encode(rating, forKey: .rating)
        try container.encode(completedRides, forKey: .completedRides)
        try container.encode(totalRidesAsDriver, forKey: .totalRidesAsDriver)
        try container.encode(totalRidesAsPassenger, forKey: .totalRidesAsPassenger)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isBanned, forKey: .isBanned)
        try container.encodeIfPresent(banReason, forKey: .banReason)
        try container.encodeIfPresent(fcmToken, forKey: .fcmToken)
        try container.encode(isRealNameVerified, forKey: .isRealNameVerified)
        try container.encodeIfPresent(realName, forKey: .realName)
        try container.encodeIfPresent(idCardNumber, forKey: .idCardNumber)
        try container.encodeIfPresent(preferences, forKey: .preferences)
    }
}

// MARK: - User Preferences
/// 用户偏好设置
struct UserPreferences: Codable, Equatable {
    var allowNotifications: Bool = true          // 允许推送通知
    var allowLocationTracking: Bool = true       // 允许位置追踪
    var preferredPaymentMethod: PaymentMethod = .cash  // 首选支付方式
    var autoAcceptRides: Bool = false           // 自动接单（司机）
    var maxPassengers: Int = 4                  // 最大乘客数（司机）
    var preferredLanguage: String = "zh_CN"     // 首选语言
}

// MARK: - Payment Method
/// 支付方式
enum PaymentMethod: String, Codable {
    case cash = "cash"             // 现金
    case alipay = "alipay"         // 支付宝
    case wechatPay = "wechatPay"   // 微信支付
    case stripe = "stripe"         // Stripe（信用卡）
    
    var displayName: String {
        switch self {
        case .cash: return "现金"
        case .alipay: return "支付宝"
        case .wechatPay: return "微信支付"
        case .stripe: return "信用卡"
        }
    }
    
    var icon: String {
        switch self {
        case .cash: return "dollarsign.circle.fill"
        case .alipay: return "a.circle.fill"
        case .wechatPay: return "w.circle.fill"
        case .stripe: return "creditcard.fill"
        }
    }
}

// MARK: - User Extension - Validation
extension AppUser {
    /// 验证用户信息完整性
    func validate() throws {
        // 基本信息验证
        guard !name.isEmpty else {
            throw UserValidationError.invalidName
        }
        
        guard email.contains("@") && email.contains(".") else {
            throw UserValidationError.invalidEmail
        }
        
        guard !phone.isEmpty else {
            throw UserValidationError.invalidPhone
        }
        
        // 车主特殊验证
        if role == .carOwner {
            guard let vehicle = vehicleInfo else {
                throw UserValidationError.missingVehicleInfo
            }
            
            guard !vehicle.carPlateNumber.isEmpty else {
                throw UserValidationError.invalidCarPlate
            }
            
            guard vehicle.insuranceExpiryDate > Date() else {
                throw UserValidationError.insuranceExpired
            }
            
            guard vehicle.verificationStatus == .verified else {
                throw UserValidationError.vehicleNotVerified
            }
        }
    }
}

// MARK: - User Validation Error
enum UserValidationError: LocalizedError {
    case invalidName
    case invalidEmail
    case invalidPhone
    case missingVehicleInfo
    case invalidCarPlate
    case insuranceExpired
    case vehicleNotVerified
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "用户名无效"
        case .invalidEmail:
            return "邮箱格式无效"
        case .invalidPhone:
            return "手机号无效"
        case .missingVehicleInfo:
            return "车主必须提供车辆信息"
        case .invalidCarPlate:
            return "车牌号无效"
        case .insuranceExpired:
            return "车辆保险已过期"
        case .vehicleNotVerified:
            return "车辆信息未通过认证"
        }
    }
}
