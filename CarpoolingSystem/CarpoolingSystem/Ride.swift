import Foundation
import FirebaseFirestore

struct Ride: Identifiable, Codable {
    @DocumentID var id: String?
    var ownerID: String
    var ownerName: String
    var ownerPhone: String
    var startLocation: String
    var endLocation: String
    var departureTime: Date
    var availableSeats: Int
    var pricePerSeat: Int
    var notes: String
    var status: String // "Active", "Full", "Completed"
    var passengerIDs: [String]
    
    // 这是一个计算属性，不算数据库字段
    var isActive: Bool {
        return status == "Active" && availableSeats > 0
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: departureTime)
    }
}
