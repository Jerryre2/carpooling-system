import Foundation
import FirebaseFirestore

// 定义拼车请求的数据结构
struct CarpoolRequest: Identifiable, Codable {
    @DocumentID var id: String? // Firestore 自动生成的 ID
    var creatorID: String
    var departureLocation: String
    var destination: String
    var departureTime: Date
    var maxPassengers: Int          // 最大乘客数（不含发起人）
    var currentPassengersCount: Int // 当前已加入人数
    var status: String              // "OPEN", "FULL", "CLOSED"
    var participantIDs: [String]    // 已加入的用户 ID 列表
    var createdAt: Date             // 创建时间，用于排序
    
    // 简单的初始化方法
    init(creatorID: String,
         departureLocation: String,
         destination: String,
         departureTime: Date,
         maxPassengers: Int) {
        self.creatorID = creatorID
        self.departureLocation = departureLocation
        self.destination = destination
        self.departureTime = departureTime
        self.maxPassengers = maxPassengers
        self.currentPassengersCount = 0
        self.status = "OPEN"
        self.participantIDs = []
        self.createdAt = Date()
    }
}
