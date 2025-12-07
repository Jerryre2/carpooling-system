import Foundation
import FirebaseFirestore

class CarpoolService: ObservableObject {
    @Published var requests: [CarpoolRequest] = []
    private var db = Firestore.firestore()
    
    // MARK: - 1. 发布拼车请求 (Publish)
    func publishRequest(request: CarpoolRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("carpool_requests").addDocument(from: request)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - 2. 获取大厅列表 (List Hall)
    // 规则：只显示 OPEN 状态，且出发时间是未来的请求
    func fetchOpenRequests() {
        db.collection("carpool_requests")
            .whereField("status", isEqualTo: "OPEN")
            .whereField("departureTime", isGreaterThan: Date()) // 过滤掉已过期的
            .order(by: "departureTime", descending: false)      // 按时间排序，越早出发越靠前
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("获取请求失败: \(error?.localizedDescription ?? "未知错误")")
                    return
                }
                
                self.requests = documents.compactMap { doc -> CarpoolRequest? in
                    try? doc.data(as: CarpoolRequest.self)
                }
            }
    }
    
    // MARK: - 3. 加入拼车请求 (核心：事务处理)
    // 使用 Firestore Transaction 防止并发冲突
    func joinRequest(requestID: String, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let requestRef = db.collection("carpool_requests").document(requestID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let requestDocument: DocumentSnapshot
            do {
                try requestDocument = transaction.getDocument(requestRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // 读取当前数据
            guard let data = requestDocument.data(),
                  let status = data["status"] as? String,
                  let currentCount = data["currentPassengersCount"] as? Int,
                  let maxPeople = data["maxPassengers"] as? Int,
                  let participants = data["participantIDs"] as? [String] else {
                let error = NSError(domain: "AppError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据无效"])
                errorPointer?.pointee = error
                return nil
            }
            
            // --- 验证逻辑 (Validate) ---
            
            // 1. 检查状态是否还是 OPEN
            if status != "OPEN" {
                let error = NSError(domain: "AppError", code: -2, userInfo: [NSLocalizedDescriptionKey: "该拼车已关闭或已满"])
                errorPointer?.pointee = error
                return nil
            }
            
            // 2. 检查是否满员 (双重保险)
            if currentCount >= maxPeople {
                let error = NSError(domain: "AppError", code: -3, userInfo: [NSLocalizedDescriptionKey: "手慢了，人数已满"])
                errorPointer?.pointee = error
                return nil
            }
            
            // 3. 检查是否重复加入
            if participants.contains(userID) {
                let error = NSError(domain: "AppError", code: -4, userInfo: [NSLocalizedDescriptionKey: "你已经加入过这个拼车了"])
                errorPointer?.pointee = error
                return nil
            }
            
            // --- 写入逻辑 (Write) ---
            
            let newCount = currentCount + 1
            // 如果加了这个人后达到上限，状态自动变 FULL
            let newStatus = (newCount >= maxPeople) ? "FULL" : "OPEN"
            
            transaction.updateData([
                "currentPassengersCount": newCount,
                "participantIDs": FieldValue.arrayUnion([userID]),
                "status": newStatus
            ], forDocument: requestRef)
            
            return nil
            
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
