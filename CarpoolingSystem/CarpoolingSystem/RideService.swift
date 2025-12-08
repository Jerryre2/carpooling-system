import Foundation
import FirebaseFirestore

class RideService: ObservableObject {
    @Published var rides: [Ride] = []
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        subscribeToRides()
        loadDemoData() // 添加演示数据（用于测试）
    }
    
    // MARK: - 加载演示数据（用于测试）
    private func loadDemoData() {
        let now = Date()
        
        // 演示行程1
        let ride1 = Ride(
            ownerID: "demo_driver1",
            ownerName: "张师傅",
            ownerPhone: "+853 6688 8888",
            startLocation: "横琴口岸",
            endLocation: "澳门科技大学",
            departureTime: now.addingTimeInterval(3600), // 1小时后
            availableSeats: 2,
            pricePerSeat: 50,
            notes: "舒适商务车",
            status: "Active",
            passengerIDs: []
        )
        
        // 演示行程2
        let ride2 = Ride(
            ownerID: "demo_driver2",
            ownerName: "李师傅",
            ownerPhone: "+853 6699 9999",
            startLocation: "澳门机场",
            endLocation: "澳门大学",
            departureTime: now.addingTimeInterval(7200), // 2小时后
            availableSeats: 1,
            pricePerSeat: 40,
            notes: "准时出发",
            status: "Active",
            passengerIDs: []
        )
        
        // 演示行程3
        let ride3 = Ride(
            ownerID: "demo_driver3",
            ownerName: "王师傅",
            ownerPhone: "+853 6677 7777",
            startLocation: "澳门科技大学",
            endLocation: "威尼斯人酒店",
            departureTime: now.addingTimeInterval(5400), // 1.5小时后
            availableSeats: 3,
            pricePerSeat: 35,
            notes: "可放行李",
            status: "Active",
            passengerIDs: []
        )
        
        // 将演示数据添加到 rides 数组
        self.rides = [ride1, ride2, ride3]
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
