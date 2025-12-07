import Foundation
import FirebaseFirestore

enum UserRole: String, Codable {
    case carOwner = "Car Owner"
    case carpooler = "Carpooler"
}

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var phone: String
    var rating: Double
    var completedRides: Int
    var joinDate: Date
    var role: UserRole
    
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
    }
}
