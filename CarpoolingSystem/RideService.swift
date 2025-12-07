import Foundation
import FirebaseFirestore

class RideService: ObservableObject {
    @Published var rides: [Ride] = []
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        subscribeToRides()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    // MARK: - 实时监听所有行程
    func subscribeToRides() {
        listenerRegistration = db.collection("rides")
            .order(by: "departureTime", descending: false) // 按时间排序
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching rides: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // 将 Firestore 数据转换为 Ride 数组
                self.rides = documents.compactMap { document -> Ride? in
                    try? document.data(as: Ride.self)
                }
            }
    }
    
    // MARK: - 发布行程
    func addRide(_ ride: Ride) {
        do {
            // Firestore 会自动生成 ID
            try db.collection("rides").addDocument(from: ride)
        } catch {
            print("Error adding ride: \(error)")
        }
    }
    
    // MARK: - 删除行程
    func deleteRide(_ ride: Ride) {
        guard let rideID = ride.id else { return }
        db.collection("rides").document(rideID).delete()
    }
    
    // MARK: - 预订行程
    func bookRide(ride: Ride, userID: String) {
        guard let rideID = ride.id else { return }
        
        // 使用事务或简单更新。这里用简单更新
        var newPassengers = ride.passengerIDs
        if !newPassengers.contains(userID) {
            newPassengers.append(userID)
        }
        
        let newSeats = ride.availableSeats - 1
        let newStatus = newSeats <= 0 ? "Full" : ride.status
        
        db.collection("rides").document(rideID).updateData([
            "passengerIDs": newPassengers,
            "availableSeats": newSeats,
            "status": newStatus
        ])
    }
    
    // MARK: - 取消预订
    func cancelBooking(ride: Ride, userID: String) {
        guard let rideID = ride.id else { return }
        
        var newPassengers = ride.passengerIDs
        if let index = newPassengers.firstIndex(of: userID) {
            newPassengers.remove(at: index)
        }
        
        let newSeats = ride.availableSeats + 1
        let newStatus = "Active" // 恢复为可用
        
        db.collection("rides").document(rideID).updateData([
            "passengerIDs": newPassengers,
            "availableSeats": newSeats,
            "status": newStatus
        ])
    }
}
