import Foundation
import FirebaseFirestore

// 注意：UserRole 现在定义在 UserModels.swift 中
// 这个文件保留是为了向后兼容，但建议迁移到 UserModels.swift 中的 AppUser

/// 旧版用户模型（已弃用，建议使用 AppUser）
/// 保留此结构以支持现有代码，但新代码应使用 UserModels.swift 中的 AppUser
struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var phone: String
    var rating: Double
    var completedRides: Int
    var joinDate: Date
    var role: AppUserRole  // 使用 AppUserRole 而不是 UserRole
    var walletBalance: Double
    // Car Owner specific fields
    var carPlateNumber: String?
    var insuranceExpiryDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case rating
        case completedRides
        case joinDate
        case role
        case carPlateNumber
        case insuranceExpiryDate
        case walletBalance
    }
    
    // MARK: - 手动实现 Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.email = try container.decode(String.self, forKey: .email)
        self.phone = try container.decode(String.self, forKey: .phone)
        self.rating = try container.decode(Double.self, forKey: .rating)
        self.completedRides = try container.decode(Int.self, forKey: .completedRides)
        self.joinDate = try container.decode(Date.self, forKey: .joinDate)
        self.role = try container.decode(AppUserRole.self, forKey: .role)
        self.carPlateNumber = try container.decodeIfPresent(String.self, forKey: .carPlateNumber)
        self.insuranceExpiryDate = try container.decodeIfPresent(Date.self, forKey: .insuranceExpiryDate)
        self.walletBalance = try container.decodeIfPresent(Double.self, forKey: .walletBalance) ?? 0.0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encode(rating, forKey: .rating)
        try container.encode(completedRides, forKey: .completedRides)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(carPlateNumber, forKey: .carPlateNumber)
        try container.encodeIfPresent(insuranceExpiryDate, forKey: .insuranceExpiryDate)
    }
    
    init(
        id: String? = nil,
        name: String,
        email: String,
        phone: String,
        rating: Double,
        completedRides: Int,
        joinDate: Date,
        role: AppUserRole,
        carPlateNumber: String? = nil,
        insuranceExpiryDate: Date? = nil,
        walletBalance: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.rating = rating
        self.completedRides = completedRides
        self.joinDate = joinDate
        self.role = role
        self.carPlateNumber = carPlateNumber
        self.insuranceExpiryDate = insuranceExpiryDate
        self.walletBalance = walletBalance
    }
}
