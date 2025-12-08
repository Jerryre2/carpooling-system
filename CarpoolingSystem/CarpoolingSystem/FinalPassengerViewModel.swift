//
//  完全重构的乘客端 ViewModel - 最终版本
//  RefactoredPassengerViewModelFinal.swift
//
//  Created on 2025-12-07
//  无冲突、可直接使用的版本
//

import Foundation
import CoreLocation
import Combine
import SwiftUI
import FirebaseFirestore

// MARK: - 完全重构的乘客端 ViewModel（最终版本）
@MainActor
class FinalPassengerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var myPublishedTrips: [TripRequest] = []
    @Published var currentUser: RefactoredUser?
    @Published var selectedTripDetails: TripRequest?
    @Published var isLoading: Bool = false
    @Published var errorAlert: ErrorAlert?
    @Published var successMessage: String?
    @Published var lastSyncTime: Date?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var walletBalance: Double = 0.0
    
    // MARK: - Public Properties (for access)
    let currentUserID: String
    let currentUserName: String
    let currentUserPhone: String
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let paymentService: PaymentService // 新增：支付服务
    private let db = Firestore.firestore() // 新增：Firestore 实例
    
    // MARK: - Initialization
    
    init(userID: String, userName: String, userPhone: String) {
        self.currentUserID = userID
        self.currentUserName = userName
        self.currentUserPhone = userPhone
        self.paymentService = PaymentService() // 初始化支付服务
        
        // 初始化用户
        self.currentUser = RefactoredUser(
            id: userID,
            name: userName,
            phone: userPhone,
            role: .passenger,
            walletBalance: 500.0 // 默认余额
        )
        
        self.walletBalance = 500.0
        
        print("👤 FinalPassengerViewModel 初始化完成")
        
        // 新增：从 Firestore 加载真实余额
        Task {
            await loadWalletBalanceFromFirestore()
        }
    }
    
    // MARK: - Lifecycle Methods
    
    func startListening() {
        print("📡 启动乘客端实时监听...")
        // TODO: 启动 Firestore 监听
    }
    
    func stopListening() {
        print("🔇 停止乘客端监听...")
        // TODO: 停止 Firestore 监听
    }
    
    func listenToTripDetails(tripID: UUID) {
        print("📡 监听行程详情: \(tripID.uuidString)")
        // TODO: 监听特定行程
    }
    
    // MARK: - Core Functions
    
    /// 发布行程
    func publishTrip(
        startLocation: String,
        startCoordinate: Coordinate,
        endLocation: String,
        endCoordinate: Coordinate,
        departureTime: Date,
        numberOfPassengers: Int,
        pricePerPerson: Double,
        notes: String = ""
    ) async {
        print("📤 发布行程请求...")
        
        guard !isLoading else {
            print("⚠️ 正在处理中")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let trip = TripRequest(
                passengerID: currentUserID,
                passengerName: currentUserName,
                passengerPhone: currentUserPhone,
                startLocation: startLocation,
                startCoordinate: startCoordinate,
                endLocation: endLocation,
                endCoordinate: endCoordinate,
                departureTime: departureTime,
                numberOfPassengers: numberOfPassengers,
                pricePerPerson: pricePerPerson,
                notes: notes
            )
            
            // 模拟发布
            try await Task.sleep(nanoseconds: 1_000_000_000)
            myPublishedTrips.append(trip)
            
            successMessage = "发布成功！"
            print("✅ 行程发布成功: \(trip.id.uuidString)")
            
        } catch {
            print("❌ 发布失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "发布失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 支付行程
    func payForTrip(trip: TripRequest) async {
        print("💳 支付行程: \(trip.id.uuidString)")
        
        guard !isLoading else { return }
        guard let user = currentUser else { return }
        guard user.walletBalance >= trip.totalCost else {
            errorAlert = ErrorAlert(
                title: "余额不足",
                message: "请先充值"
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 扣除余额
            try await Task.sleep(nanoseconds: 500_000_000)
            
            if var updatedUser = currentUser {
                updatedUser.walletBalance -= trip.totalCost
                currentUser = updatedUser
                walletBalance = updatedUser.walletBalance
            }
            
            // 更新行程状态
            if let index = myPublishedTrips.firstIndex(where: { $0.id == trip.id }) {
                myPublishedTrips[index].status = .paid
                myPublishedTrips[index].paidAt = Date()
            }
            
            successMessage = "支付成功！¥\(String(format: "%.2f", trip.totalCost))"
            print("✅ 支付成功")
            
            // 新增：同步到 Firestore
            await syncPaymentToFirestore(trip: trip, amount: trip.totalCost)
            
        } catch {
            print("❌ 支付失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "支付失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 取消行程
    func cancelTrip(tripID: UUID) async {
        print("❌ 取消行程: \(tripID.uuidString)")
        
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let trip = myPublishedTrips.first(where: { $0.id == tripID }) else {
                throw NetworkError.rideNotFound
            }
            
            // 如果已支付，退款
            if trip.status == .paid, let paidAt = trip.paidAt {
                if var updatedUser = currentUser {
                    updatedUser.walletBalance += trip.totalCost
                    currentUser = updatedUser
                    walletBalance = updatedUser.walletBalance
                }
                
                // 新增：记录退款到 Firestore
                await recordRefundToFirestore(trip: trip, amount: trip.totalCost)
            }
            
            // 更新状态
            if let index = myPublishedTrips.firstIndex(where: { $0.id == tripID }) {
                myPublishedTrips[index].status = .cancelled
            }
            
            successMessage = "已取消行程"
            print("✅ 取消成功")
            
        } catch {
            print("❌ 取消失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "取消失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 充值
    func topUpWallet(amount: Double) async {
        print("💰 充值: ¥\(amount)")
        
        guard amount > 0 && amount <= 10000 else {
            errorAlert = ErrorAlert(
                title: "充值金额错误",
                message: "充值金额必须在 0-10000 元之间"
            )
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            
            if var updatedUser = currentUser {
                updatedUser.walletBalance += amount
                currentUser = updatedUser
                walletBalance = updatedUser.walletBalance
            }
            
            successMessage = "充值成功！+¥\(String(format: "%.2f", amount))"
            print("✅ 充值成功，当前余额: ¥\(walletBalance)")
            
            // 新增：同步到 Firestore
            await syncTopUpToFirestore(amount: amount)
            
        } catch {
            print("❌ 充值失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "充值失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 手动刷新
    func refresh() async {
        print("🔄 手动刷新...")
        
        isLoading = true
        defer { isLoading = false }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // 新增：从 Firestore 刷新余额
        await loadWalletBalanceFromFirestore()
        
        successMessage = "刷新成功"
    }
    
    /// 格式化价格
    func formatPrice(_ price: Double) -> String {
        return String(format: "¥%.2f", price)
    }
    
    /// 检查是否可以支付
    func canPayForTrip(_ trip: TripRequest) -> Bool {
        guard let user = currentUser else { return false }
        return trip.needsPayment &&
               trip.passengerID == currentUserID &&
               user.walletBalance >= trip.totalCost
    }
    
    /// 更新用户位置
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        self.userLocation = location
        print("📍 用户位置已更新")
    }
    
    // MARK: - 新增：支付服务集成方法
    
    /// 使用 PaymentService 处理支付（可选方法）
    func processPaymentWithService(amount: Double, rideID: String) async {
        print("💳 使用 PaymentService 处理支付: ¥\(amount)")
        
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let transaction = try await paymentService.processCashPayment(
                amount: amount,
                rideID: rideID
            )
            
            print("✅ PaymentService 支付成功: \(transaction.formattedAmount)")
            successMessage = "支付成功！"
            
            // 更新本地余额
            if var updatedUser = currentUser {
                updatedUser.walletBalance -= amount
                currentUser = updatedUser
                walletBalance = updatedUser.walletBalance
            }
            
        } catch {
            print("❌ PaymentService 支付失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "支付失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 加载交易历史（适配 WalletView）
    func loadTransactionHistory() async -> [WalletTransaction] {
        print("📋 加载交易历史...")
        
        do {
            let snapshot = try await db.collection("transactions")
                .whereField("userID", isEqualTo: currentUserID)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let transactions = snapshot.documents.compactMap { doc -> WalletTransaction? in
                let data = doc.data()
                
                guard let id = data["id"] as? String,
                      let amount = data["amount"] as? Double,
                      let statusRaw = data["status"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                // 判断交易类型
                let type: WalletTransactionType
                if amount > 0 {
                    type = .topUp
                } else if statusRaw == "refunded" {
                    type = .refund
                } else {
                    type = .payment
                }
                
                let status: WalletTransactionStatus
                switch statusRaw {
                case "completed":
                    status = .completed
                case "pending":
                    status = .pending
                case "failed":
                    status = .failed
                case "cancelled":
                    status = .cancelled
                default:
                    status = .completed
                }
                
                return WalletTransaction(
                    id: id,
                    userID: currentUserID,
                    type: type,
                    amount: abs(amount),
                    description: generateTransactionDescription(type: type, amount: amount),
                    status: status,
                    createdAt: timestamp
                )
            }
            
            print("✅ 加载了 \(transactions.count) 条交易记录")
            return transactions
            
        } catch {
            print("❌ 加载交易历史失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "加载失败",
                message: error.localizedDescription
            )
            return []
        }
    }
    
    // MARK: - 新增：Private Helper Methods
    
    /// 从 Firestore 加载钱包余额
    private func loadWalletBalanceFromFirestore() async {
        do {
            let document = try await db.collection("users").document(currentUserID).getDocument()
            
            if let data = document.data(),
               let balance = data["walletBalance"] as? Double {
                
                self.walletBalance = balance
                
                if var updatedUser = currentUser {
                    updatedUser.walletBalance = balance
                    currentUser = updatedUser
                }
                
                print("✅ 从 Firestore 加载余额: ¥\(balance)")
            } else {
                // 如果用户不存在，创建新用户
                try await db.collection("users").document(currentUserID).setData([
                    "id": currentUserID,
                    "name": currentUserName,
                    "phone": currentUserPhone,
                    "walletBalance": 500.0,
                    "role": "passenger",
                    "createdAt": Timestamp(date: Date())
                ])
                
                print("✅ 创建新用户，默认余额: ¥500.00")
            }
            
        } catch {
            print("❌ 加载余额失败: \(error.localizedDescription)")
        }
    }
    
    /// 同步支付到 Firestore
    private func syncPaymentToFirestore(trip: TripRequest, amount: Double) async {
        do {
            // 1. 更新用户余额
            try await db.collection("users").document(currentUserID).updateData([
                "walletBalance": FieldValue.increment(-amount)
            ])
            
            // 2. 创建交易记录
            let transactionID = UUID().uuidString
            try await db.collection("transactions").document(transactionID).setData([
                "id": transactionID,
                "userID": currentUserID,
                "rideID": trip.id.uuidString,
                "amount": -amount,
                "method": "cash",
                "status": "completed",
                "timestamp": Timestamp(date: Date())
            ])
            
            print("✅ 支付已同步到 Firestore")
            
        } catch {
            print("❌ 同步支付失败: \(error.localizedDescription)")
        }
    }
    
    /// 记录退款到 Firestore
    private func recordRefundToFirestore(trip: TripRequest, amount: Double) async {
        do {
            // 1. 更新用户余额
            try await db.collection("users").document(currentUserID).updateData([
                "walletBalance": FieldValue.increment(amount)
            ])
            
            // 2. 创建退款记录
            let transactionID = UUID().uuidString
            try await db.collection("transactions").document(transactionID).setData([
                "id": transactionID,
                "userID": currentUserID,
                "rideID": trip.id.uuidString,
                "amount": amount,
                "method": "cash",
                "status": "refunded",
                "timestamp": Timestamp(date: Date())
            ])
            
            print("✅ 退款已记录到 Firestore")
            
        } catch {
            print("❌ 记录退款失败: \(error.localizedDescription)")
        }
    }
    
    /// 同步充值到 Firestore
    private func syncTopUpToFirestore(amount: Double) async {
        do {
            // 1. 更新用户余额
            try await db.collection("users").document(currentUserID).updateData([
                "walletBalance": FieldValue.increment(amount)
            ])
            
            // 2. 创建充值记录
            let transactionID = UUID().uuidString
            try await db.collection("transactions").document(transactionID).setData([
                "id": transactionID,
                "userID": currentUserID,
                "rideID": "wallet_topup",
                "amount": amount,
                "method": "cash",
                "status": "completed",
                "timestamp": Timestamp(date: Date())
            ])
            
            print("✅ 充值已同步到 Firestore")
            
        } catch {
            print("❌ 同步充值失败: \(error.localizedDescription)")
        }
    }
    
    /// 生成交易描述
    private func generateTransactionDescription(type: WalletTransactionType, amount: Double) -> String {
        switch type {
        case .topUp:
            return "钱包充值"
        case .refund:
            return "行程退款"
        case .payment:
            return "行程支付"
        case .earning:
            return "司机收入"
        }
    }
}

// MARK: - Preview Helper
#if DEBUG
extension FinalPassengerViewModel {
    static var preview: FinalPassengerViewModel {
        FinalPassengerViewModel(
            userID: "preview_user",
            userName: "测试用户",
            userPhone: "+853 6666 6666"
        )
    }
}
#endif
