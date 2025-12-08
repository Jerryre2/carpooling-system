//
//  RealtimeRideService.swift
//  CarpoolingSystem - Commercial Grade Realtime Service
//
//  Created on 2025-12-07
//  实现多设备实时数据同步（即时通讯级体验）
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Realtime Ride Service
/// 商业级实时行程服务（核心交付物）
@MainActor
class RealtimeRideService: ObservableObject {
    // MARK: - Published Properties
    
    /// 所有活跃行程（实时同步）
    @Published var activeRides: [AdvancedRide] = []
    
    /// 我发布的行程（实时同步）
    @Published var myPublishedRides: [AdvancedRide] = []
    
    /// 我预订的行程（实时同步）
    @Published var myBookedRides: [AdvancedRide] = []
    
    /// 特定行程详情（用于详情页实时监听）
    @Published var currentRideDetails: AdvancedRide?
    
    /// 加载状态
    @Published var isLoading: Bool = false
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 上次同步时间
    @Published var lastSyncTime: Date?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private let currentUserID: String
    
    // MARK: - Initialization
    
    init(currentUserID: String) {
        self.currentUserID = currentUserID
        print("🔥 RealtimeRideService 初始化，用户ID: \(currentUserID)")
    }
    
    deinit {
        // 在 deinit 中直接清理，不调用 main actor 方法
        for (key, listener) in listeners {
            listener.remove()
            print("🔇 移除监听器: \(key)")
        }
        print("🔥 RealtimeRideService 析构")
    }
    
    // MARK: - 核心功能 1：实时监听所有活跃行程（列表页）
    
    /// 开始监听所有活跃行程
    /// 这是核心交付物之一：使用 onSnapshot 实现 1秒内 的实时刷新
    func startListeningToActiveRides() {
        print("📡 开始监听所有活跃行程...")
        
        // 移除旧的监听器（如果存在）
        removeListener(key: "activeRides")
        
        // 设置实时监听器
        let listener = db.collection("advancedRides")
            .whereField("status", in: [RideStatus.pending.rawValue, RideStatus.accepted.rawValue])
            .order(by: "departureTime", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ 监听活跃行程失败: \(error.localizedDescription)")
                        self.errorMessage = "实时同步失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let snapshot = querySnapshot else {
                        print("⚠️ 快照为空")
                        return
                    }
                    
                    // 🎯 关键：处理实时变更
                    let changes = snapshot.documentChanges
                    print("📊 检测到 \(changes.count) 个文档变更")
                    
                    // 解析所有行程
                    let rides = snapshot.documents.compactMap { document -> AdvancedRide? in
                        do {
                            let ride = try document.data(as: AdvancedRide.self)
                            return ride
                        } catch {
                            print("❌ 解析行程失败: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    
                    // ✅ 实时更新 UI（1秒内响应）
                    self.activeRides = rides
                    self.lastSyncTime = Date()
                    
                    print("✅ 活跃行程已更新: \(rides.count) 条")
                    
                    // 处理具体变更类型（用于日志和通知）
                    for change in changes {
                        switch change.type {
                        case .added:
                            print("➕ 新增行程: \(change.document.documentID)")
                        case .modified:
                            print("✏️ 修改行程: \(change.document.documentID)")
                        case .removed:
                            print("➖ 删除行程: \(change.document.documentID)")
                        }
                    }
                }
            }
        
        // 保存监听器引用
        listeners["activeRides"] = listener
    }
    
    // MARK: - 核心功能 2：实时监听我发布的行程
    
    /// 开始监听我发布的行程
    func startListeningToMyPublishedRides() {
        print("📡 开始监听我发布的行程...")
        
        removeListener(key: "myPublishedRides")
        
        let listener = db.collection("advancedRides")
            .whereField("publisherID", isEqualTo: currentUserID)
            .order(by: "departureTime", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ 监听我的行程失败: \(error.localizedDescription)")
                        self.errorMessage = "同步失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    let rides = documents.compactMap { document -> AdvancedRide? in
                        try? document.data(as: AdvancedRide.self)
                    }
                    
                    self.myPublishedRides = rides
                    self.lastSyncTime = Date()
                    
                    print("✅ 我的行程已更新: \(rides.count) 条")
                }
            }
        
        listeners["myPublishedRides"] = listener
    }
    
    // MARK: - 核心功能 3：实时监听我预订的行程
    
    /// 开始监听我预订的行程
    func startListeningToMyBookedRides() {
        print("📡 开始监听我预订的行程...")
        
        removeListener(key: "myBookedRides")
        
        let listener = db.collection("advancedRides")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ 监听预订行程失败: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    // 筛选包含当前用户 ID 的行程
                    let rides = documents.compactMap { document -> AdvancedRide? in
                        guard let ride = try? document.data(as: AdvancedRide.self) else {
                            return nil
                        }
                        
                        // 检查是否是当前用户预订的行程
                        let isPassenger = ride.passengers.contains { $0.id == self.currentUserID }
                        return isPassenger ? ride : nil
                    }
                    
                    self.myBookedRides = rides
                    self.lastSyncTime = Date()
                    
                    print("✅ 我的预订已更新: \(rides.count) 条")
                }
            }
        
        listeners["myBookedRides"] = listener
    }
    
    // MARK: - 核心功能 4：实时监听特定行程详情（详情页）
    
    /// 开始监听特定行程的详情（用于行程详情页）
    /// 这是核心交付物之一：实时反映乘客列表和行程状态的变化
    func startListeningToRideDetails(rideID: UUID) {
        print("📡 开始监听行程详情: \(rideID.uuidString)")
        
        removeListener(key: "rideDetails")
        
        let listener = db.collection("advancedRides")
            .whereField("id", isEqualTo: rideID.uuidString)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ 监听行程详情失败: \(error.localizedDescription)")
                        self.errorMessage = "详情同步失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let document = querySnapshot?.documents.first else {
                        print("⚠️ 未找到行程: \(rideID.uuidString)")
                        return
                    }
                    
                    do {
                        let ride = try document.data(as: AdvancedRide.self)
                        self.currentRideDetails = ride
                        self.lastSyncTime = Date()
                        
                        print("✅ 行程详情已更新")
                        print("   - 状态: \(ride.status.displayName)")
                        print("   - 乘客数: \(ride.currentPassengerCount)/\(ride.totalCapacity)")
                        
                        // 🎯 关键：实时更新乘客列表
                        for passenger in ride.passengers {
                            print("   - 乘客: \(passenger.name)")
                        }
                    } catch {
                        print("❌ 解析行程详情失败: \(error.localizedDescription)")
                    }
                }
            }
        
        listeners["rideDetails"] = listener
    }
    
    // MARK: - 发布新行程
    
    /// 发布新行程（自动触发所有监听器更新）
    func publishRide(_ ride: AdvancedRide) async throws {
        print("📤 发布新行程...")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 将行程数据转换为字典
            let data = try Firestore.Encoder().encode(ride)
            
            // 写入 Firestore
            try await db.collection("advancedRides")
                .document(ride.id.uuidString)
                .setData(data)
            
            print("✅ 行程发布成功: \(ride.id.uuidString)")
            
            // ✅ 实时监听器会自动触发 UI 更新（无需手动刷新）
        } catch {
            print("❌ 发布行程失败: \(error.localizedDescription)")
            errorMessage = "发布失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - 更新行程
    
    /// 更新行程（自动触发所有监听器更新）
    func updateRide(_ ride: AdvancedRide) async throws {
        print("📝 更新行程: \(ride.id.uuidString)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try Firestore.Encoder().encode(ride)
            
            try await db.collection("advancedRides")
                .document(ride.id.uuidString)
                .setData(data, merge: true)
            
            print("✅ 行程更新成功")
            
            // ✅ 实时监听器会自动触发 UI 更新
        } catch {
            print("❌ 更新行程失败: \(error.localizedDescription)")
            errorMessage = "更新失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - 加入行程（乘客）
    
    /// 加入行程（针对司机发车）
    func joinRide(rideID: UUID, passenger: PassengerInfo) async throws {
        print("🎫 加入行程: \(rideID.uuidString)")
        isLoading = true
        defer { isLoading = false }
        
        let docRef = db.collection("advancedRides").document(rideID.uuidString)
        
        do {
            try await db.runTransaction { transaction, errorPointer in
                let document: DocumentSnapshot
                do {
                    document = try transaction.getDocument(docRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                
                guard var ride = try? document.data(as: AdvancedRide.self) else {
                    let error = NSError(
                        domain: "RideService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无法解析行程数据"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }
                
                // 检查座位
                guard ride.availableSeats > 0 else {
                    let error = NSError(
                        domain: "RideService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "座位已满"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }
                
                // 检查是否已加入
                guard !ride.passengers.contains(where: { $0.id == passenger.id }) else {
                    let error = NSError(
                        domain: "RideService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "已加入此行程"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }
                
                // 更新行程数据
                ride.passengers.append(passenger)
                ride.availableSeats -= 1
                
                // 如果满座，更新状态
                if ride.availableSeats == 0 {
                    ride.status = .accepted
                }
                
                // 写入事务
                let data = try! Firestore.Encoder().encode(ride)
                transaction.setData(data, forDocument: docRef, merge: true)
                
                return nil
            }
            
            print("✅ 成功加入行程")
            
            // ✅ 实时监听器会自动更新 UI
        } catch {
            print("❌ 加入行程失败: \(error.localizedDescription)")
            errorMessage = "加入失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - 接受行程（司机接学生求车）
    
    /// 接受行程（针对学生求车）
    func acceptRide(rideID: UUID, driverID: String) async throws {
        print("✅ 接受行程: \(rideID.uuidString)")
        isLoading = true
        defer { isLoading = false }
        
        let docRef = db.collection("advancedRides").document(rideID.uuidString)
        
        do {
            try await db.runTransaction { transaction, errorPointer in
                let document: DocumentSnapshot
                do {
                    document = try transaction.getDocument(docRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                
                guard var ride = try? document.data(as: AdvancedRide.self) else {
                    let error = NSError(
                        domain: "RideService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无法解析行程数据"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }
                
                // 检查状态
                guard ride.status == .pending else {
                    let error = NSError(
                        domain: "RideService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "行程状态不允许接单"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }
                
                // 更新状态
                ride.status = .accepted
                
                // 写入事务
                let data = try! Firestore.Encoder().encode(ride)
                transaction.setData(data, forDocument: docRef, merge: true)
                
                return nil
            }
            
            print("✅ 成功接受行程")
            
            // ✅ 实时监听器会自动更新 UI
        } catch {
            print("❌ 接受行程失败: \(error.localizedDescription)")
            errorMessage = "接受失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - 开始行程（进入 enRoute 状态）
    
    /// 开始行程（司机点击"开始"后）
    func startRide(rideID: UUID) async throws {
        print("🚗 开始行程: \(rideID.uuidString)")
        
        try await updateRideStatus(rideID: rideID, newStatus: .enRoute)
    }
    
    // MARK: - 完成行程
    
    /// 完成行程
    func completeRide(rideID: UUID) async throws {
        print("🏁 完成行程: \(rideID.uuidString)")
        
        try await updateRideStatus(rideID: rideID, newStatus: .completed)
    }
    
    // MARK: - 取消行程
    
    /// 取消行程
    func cancelRide(rideID: UUID) async throws {
        print("❌ 取消行程: \(rideID.uuidString)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("advancedRides")
                .document(rideID.uuidString)
                .delete()
            
            print("✅ 行程已取消")
            
            // ✅ 实时监听器会自动更新 UI
        } catch {
            print("❌ 取消行程失败: \(error.localizedDescription)")
            errorMessage = "取消失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - 更新实时位置（司机）
    
    /// 更新司机实时位置（用于实时追踪）
    func updateDriverLocation(rideID: UUID, latitude: Double, longitude: Double) async throws {
        print("📍 更新司机位置: (\(latitude), \(longitude))")
        
        try await db.collection("advancedRides")
            .document(rideID.uuidString)
            .updateData([
                "driverLatitude": latitude,
                "driverLongitude": longitude
            ])
        
        // ✅ 实时监听器会自动更新 UI
    }
    
    // MARK: - Private Helper Methods
    
    /// 更新行程状态
    private func updateRideStatus(rideID: UUID, newStatus: RideStatus) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("advancedRides")
                .document(rideID.uuidString)
                .updateData(["status": newStatus.rawValue])
            
            print("✅ 状态更新成功: \(newStatus.displayName)")
            
            // ✅ 实时监听器会自动更新 UI
        } catch {
            print("❌ 状态更新失败: \(error.localizedDescription)")
            errorMessage = "状态更新失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// 移除指定监听器
    private func removeListener(key: String) {
        listeners[key]?.remove()
        listeners.removeValue(forKey: key)
        print("🔇 移除监听器: \(key)")
    }
    
    /// 移除所有监听器
    func removeAllListeners() {
        for (key, listener) in listeners {
            listener.remove()
            print("🔇 移除监听器: \(key)")
        }
        listeners.removeAll()
    }
    
    // MARK: - 手动刷新（备用方案）
    
    /// 手动刷新数据（用于下拉刷新等场景）
    func manualRefresh() async {
        print("🔄 手动刷新数据...")
        
        // 实时监听器会自动处理数据更新
        // 这里只需要更新时间戳
        lastSyncTime = Date()
    }
}

// MARK: - 使用示例代码片段（核心交付物）

/*
 // 在 ViewModel 或 View 中使用：
 
 @StateObject private var rideService: RealtimeRideService
 
 init(userID: String) {
     _rideService = StateObject(wrappedValue: RealtimeRideService(currentUserID: userID))
 }
 
 // 在 onAppear 中启动监听：
 .onAppear {
     // 监听所有活跃行程（列表页）
     rideService.startListeningToActiveRides()
     
     // 监听我发布的行程
     rideService.startListeningToMyPublishedRides()
     
     // 监听我预订的行程
     rideService.startListeningToMyBookedRides()
 }
 
 // 在行程详情页启动监听：
 .onAppear {
     rideService.startListeningToRideDetails(rideID: ride.id)
 }
 
 // 发布新行程：
 Task {
     do {
         try await rideService.publishRide(newRide)
         // ✅ UI 会自动更新，无需手动刷新
     } catch {
         print("发布失败: \(error)")
     }
 }
 
 // 加入行程：
 Task {
     do {
         let passenger = PassengerInfo(
             id: currentUserID,
             name: currentUserName,
             phone: currentUserPhone
         )
         try await rideService.joinRide(rideID: ride.id, passenger: passenger)
         // ✅ UI 会自动更新，包括乘客列表和可用座位数
     } catch {
         print("加入失败: \(error)")
     }
 }
 */
