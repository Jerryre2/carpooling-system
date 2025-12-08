//
//  RefactoredPassengerViewModel.swift
//  CarpoolingSystem - Passenger Business Logic (Publish Trips)
//
//  Created on 2025-12-07
//  乘客端业务逻辑：发布行程请求、支付、管理订单
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

// MARK: - Refactored Passenger ViewModel
/// 乘客端视图模型（发布行程 + 支付功能）
@MainActor
class RefactoredPassengerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 我发布的行程请求
    @Published var myPublishedTrips: [TripRequest] = []
    
    /// 当前用户信息（包含钱包）
    @Published var currentUser: RefactoredUser?
    
    /// 当前选中的行程详情
    @Published var selectedTripDetails: TripRequest?
    
    /// 加载状态
    @Published var isLoading: Bool = false
    
    /// 错误提示
    @Published var errorAlert: ErrorAlert?
    
    /// 成功提示消息
    @Published var successMessage: String?
    
    /// 上次同步时间
    @Published var lastSyncTime: Date?
    
    // MARK: - Private Properties
    
    private let tripService: TripRealtimeService
    private let walletService: WalletService
    private let notificationService: NotificationService
    private let currentPassengerID: String
    private let currentPassengerName: String
    private let currentPassengerPhone: String
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userID: String, userName: String, userPhone: String) {
        self.currentPassengerID = userID
        self.currentPassengerName = userName
        self.currentPassengerPhone = userPhone
        self.tripService = TripRealtimeService(userID: userID)
        self.walletService = WalletService(userID: userID)
        self.notificationService = NotificationService.shared
        
        // 初始化当前用户
        self.currentUser = RefactoredUser(
            id: userID,
            name: userName,
            phone: userPhone,
            role: .passenger,
            walletBalance: 0.0
        )
        
        setupBindings()
        
        print("👤 RefactoredPassengerViewModel 初始化完成")
    }
    
    // MARK: - Setup
    
    /// 设置数据绑定
    private func setupBindings() {
        // 监听我发布的行程
        tripService.$myPublishedTrips
            .receive(on: DispatchQueue.main)
            .assign(to: &$myPublishedTrips)
        
        // 监听行程详情
        tripService.$currentTripDetails
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedTripDetails)
        
        // 监听同步时间
        tripService.$lastSyncTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncTime)
        
        // 监听用户信息
        walletService.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentUser)
    }
    
    // MARK: - Lifecycle Methods
    
    /// 启动实时监听
    func startListening() {
        print("📡 启动乘客端实时监听...")
        
        tripService.startListeningToMyPublishedTrips(passengerID: currentPassengerID)
        walletService.startListeningToUserInfo()
    }
    
    /// 停止监听
    func stopListening() {
        print("🔇 停止乘客端监听...")
        
        tripService.removeAllListeners()
        walletService.stopListening()
    }
    
    /// 监听特定行程详情
    func listenToTripDetails(tripID: UUID) {
        print("📡 监听行程详情: \(tripID.uuidString)")
        
        tripService.startListeningToTripDetails(tripID: tripID)
    }
    
    // MARK: - Core Functions: 发布行程
    
    /// 🎯 发布行程请求（核心功能 1）
    func publishTrip(
        startLocation: String,
        startCoordinate: Coordinate,
        endLocation: String,
        endCoordinate: Coordinate,
        departureTime: Date,
        numberOfPassengers: Int,
        pricePerPerson: Double,
        notes: String
    ) async {
        print("📝 发布行程请求...")
        
        // 防止重复提交
        guard !isLoading else {
            print("⚠️ 正在处理中，请勿重复提交")
            return
        }
        
        // 前置检查
        guard numberOfPassengers > 0 else {
            errorAlert = ErrorAlert(
                title: "发布失败",
                message: "乘客人数必须大于 0"
            )
            return
        }
        
        guard pricePerPerson > 0 else {
            errorAlert = ErrorAlert(
                title: "发布失败",
                message: "单人费用必须大于 0"
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 创建行程请求
            let trip = TripRequest(
                passengerID: currentPassengerID,
                passengerName: currentPassengerName,
                passengerPhone: currentPassengerPhone,
                startLocation: startLocation,
                startCoordinate: startCoordinate,
                endLocation: endLocation,
                endCoordinate: endCoordinate,
                departureTime: departureTime,
                numberOfPassengers: numberOfPassengers,
                pricePerPerson: pricePerPerson,
                notes: notes
            )
            
            // 保存到 Firestore
            try await tripService.publishTrip(trip)
            
            successMessage = "发布成功！等待司机接单"
            
            print("✅ 行程发布成功")
            
        } catch let error as NSError {
            print("❌ 发布失败: \(error.localizedDescription)")
            
            let networkError = mapFirebaseError(error)
            errorAlert = ErrorAlert(error: networkError)
        }
    }
    
    /// 取消行程
    func cancelTrip(_ trip: TripRequest) async {
        print("❌ 取消行程: \(trip.id.uuidString)")
        
        guard !isLoading else { return }
        
        // 检查是否可以取消
        guard trip.status == .pending || trip.status == .accepted else {
            errorAlert = ErrorAlert(
                title: "无法取消",
                message: "只能取消待接单或已接单的行程"
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var updatedTrip = trip
            updatedTrip.status = .cancelled
            updatedTrip.updatedAt = Date()
            
            try await tripService.updateTrip(updatedTrip)
            
            successMessage = "已取消行程"
            
            // 如果已有司机接单，发送通知
            if let driverID = trip.driverID {
                try await notificationService.sendRideCancelledNotification(
                    to: [driverID],
                    rideID: trip.id.uuidString,
                    cancellerName: currentPassengerName
                )
            }
            
            print("✅ 取消成功")
            
        } catch {
            print("❌ 取消失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "取消失败",
                message: error.localizedDescription
            )
        }
    }
    
    // MARK: - Core Functions: 支付功能
    
    /// 🎯 支付行程费用（核心功能 2）
    /// 这是状态流转的关键：awaitingPayment -> paid
    func payForTrip(trip: TripRequest) async {
        print("💳 支付行程: \(trip.id.uuidString)")
        
        guard !isLoading else { return }
        
        // 前置检查：是否需要支付
        guard trip.needsPayment else {
            errorAlert = ErrorAlert(
                title: "无需支付",
                message: "该行程不需要支付或已支付"
            )
            return
        }
        
        // 检查余额
        let totalCost = trip.totalCost
        guard let user = currentUser, user.walletBalance >= totalCost else {
            errorAlert = ErrorAlert(
                title: "余额不足",
                message: "您的余额不足，请先充值。需要：¥\(String(format: "%.2f", totalCost))"
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. 扣除余额
            try await walletService.deductBalance(amount: totalCost)
            
            // 2. 创建支付交易记录
            let transaction = RefactoredPaymentTransaction(
                userID: currentPassengerID,
                tripID: trip.id,
                amount: totalCost,
                type: .payment,
                status: .completed
            )
            
            try await walletService.saveTransaction(transaction)
            
            // 3. 更新行程状态为已支付
            var updatedTrip = trip
            updatedTrip.status = .paid
            updatedTrip.paymentTransactionID = transaction.id.uuidString
            updatedTrip.paidAt = Date()
            updatedTrip.updatedAt = Date()
            
            try await tripService.updateTrip(updatedTrip)
            
            successMessage = "支付成功！¥\(String(format: "%.2f", totalCost))"
            
            // 4. 通知司机
            if let driverID = trip.driverID {
                // TODO: 发送支付成功通知给司机
                print("📤 发送支付通知给司机: \(driverID)")
            }
            
            print("✅ 支付成功")
            
        } catch let error as NetworkError {
            print("❌ 支付失败: \(error.errorDescription ?? "未知错误")")
            
            errorAlert = ErrorAlert(error: error)
            
        } catch {
            print("❌ 支付失败: \(error.localizedDescription)")
            
            errorAlert = ErrorAlert(
                title: "支付失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 检查是否可以支付
    func canPayForTrip(_ trip: TripRequest) -> Bool {
        guard trip.needsPayment else { return false }
        guard let user = currentUser else { return false }
        
        return user.walletBalance >= trip.totalCost
    }
    
    // MARK: - Wallet Functions
    
    /// 充值钱包
    func topUpWallet(amount: Double) async {
        print("💰 充值钱包: ¥\(amount)")
        
        guard !isLoading else { return }
        
        guard amount > 0 else {
            errorAlert = ErrorAlert(
                title: "充值失败",
                message: "充值金额必须大于 0"
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. 增加余额
            try await walletService.addBalance(amount: amount)
            
            // 2. 创建充值交易记录
            let transaction = RefactoredPaymentTransaction(
                userID: currentPassengerID,
                tripID: UUID(), // 充值没有关联行程
                amount: amount,
                type: .topUp,
                status: .completed
            )
            
            try await walletService.saveTransaction(transaction)
            
            successMessage = "充值成功！+¥\(String(format: "%.2f", amount))"
            
            print("✅ 充值成功")
            
        } catch {
            print("❌ 充值失败: \(error.localizedDescription)")
            
            errorAlert = ErrorAlert(
                title: "充值失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 获取交易记录
    func loadTransactionHistory() async -> [RefactoredPaymentTransaction] {
        return await walletService.loadTransactionHistory()
    }
    
    // MARK: - Utility Functions
    
    /// 手动刷新
    func refresh() async {
        print("🔄 手动刷新数据...")
        
        isLoading = true
        defer { isLoading = false }
        
        await tripService.manualRefresh()
        await walletService.refresh()
        
        successMessage = "刷新成功"
    }
    
    /// 格式化价格
    func formatPrice(_ price: Double) -> String {
        return String(format: "¥%.2f", price)
    }
    
    /// 获取行程状态颜色
    func getStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .blue
        case .awaitingPayment:
            return .purple
        case .paid:
            return .green
        case .inProgress:
            return .indigo
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
}

// MARK: - Wallet Service
/// 钱包服务（管理余额和交易）
@MainActor
class WalletService: ObservableObject {
    
    @Published var currentUser: RefactoredUser?
    @Published var transactions: [RefactoredPaymentTransaction] = []
    
    private let userID: String
    private var listener: Any?
    
    init(userID: String) {
        self.userID = userID
    }
    
    /// 启动监听用户信息
    func startListeningToUserInfo() {
        // TODO: 实现 Firestore 监听
        // 临时使用演示数据
        currentUser = RefactoredUser.demoPassenger
        
        print("📡 开始监听用户信息: \(userID)")
    }
    
    /// 停止监听
    func stopListening() {
        // TODO: 移除 Firestore 监听器
        print("🔇 停止监听用户信息")
    }
    
    /// 扣除余额
    func deductBalance(amount: Double) async throws {
        guard var user = currentUser else {
            throw NetworkError.unauthorized
        }
        
        guard user.walletBalance >= amount else {
            throw NetworkError.custom(message: "余额不足")
        }
        
        user.walletBalance -= amount
        user.updatedAt = Date()
        
        // TODO: 保存到 Firestore
        currentUser = user
        
        print("✅ 余额已扣除: -¥\(amount)")
    }
    
    /// 增加余额
    func addBalance(amount: Double) async throws {
        guard var user = currentUser else {
            throw NetworkError.unauthorized
        }
        
        user.walletBalance += amount
        user.updatedAt = Date()
        
        // TODO: 保存到 Firestore
        currentUser = user
        
        print("✅ 余额已增加: +¥\(amount)")
    }
    
    /// 保存交易记录
    func saveTransaction(_ transaction: RefactoredPaymentTransaction) async throws {
        // TODO: 保存到 Firestore
        transactions.append(transaction)
        
        print("✅ 交易记录已保存: \(transaction.id.uuidString)")
    }
    
    /// 加载交易历史
    func loadTransactionHistory() async -> [RefactoredPaymentTransaction] {
        // TODO: 从 Firestore 加载
        return transactions
    }
    
    /// 刷新
    func refresh() async {
        // TODO: 重新加载用户信息
        print("🔄 刷新用户信息")
    }
}

// MARK: - Trip Realtime Service
/// 行程实时服务（简化版，用于乘客端）
@MainActor
class TripRealtimeService: ObservableObject {
    
    @Published var myPublishedTrips: [TripRequest] = []
    @Published var availableTrips: [TripRequest] = []
    @Published var myAcceptedTrips: [TripRequest] = []
    @Published var currentTripDetails: TripRequest?
    @Published var lastSyncTime: Date?
    
    private let userID: String
    private var listeners: [String: Any] = [:]
    
    init(userID: String) {
        self.userID = userID
    }
    
    /// 发布行程
    func publishTrip(_ trip: TripRequest) async throws {
        // TODO: 保存到 Firestore
        myPublishedTrips.append(trip)
        lastSyncTime = Date()
        
        print("✅ 行程已发布: \(trip.id.uuidString)")
    }
    
    /// 更新行程
    func updateTrip(_ trip: TripRequest) async throws {
        // TODO: 更新 Firestore
        if let index = myPublishedTrips.firstIndex(where: { $0.id == trip.id }) {
            myPublishedTrips[index] = trip
        }
        
        lastSyncTime = Date()
        
        print("✅ 行程已更新: \(trip.id.uuidString)")
    }
    
    /// 更新行程状态
    func updateTripStatus(tripID: UUID, newStatus: TripStatus) async throws {
        guard var trip = myPublishedTrips.first(where: { $0.id == tripID }) else {
            throw NetworkError.rideNotFound
        }
        
        trip.status = newStatus
        trip.updatedAt = Date()
        
        try await updateTrip(trip)
    }
    
    /// 监听可用行程（司机端使用）
    func startListeningToAvailableTrips() {
        // TODO: 实现 Firestore 监听
        print("📡 开始监听可用行程")
    }
    
    /// 监听我发布的行程
    func startListeningToMyPublishedTrips(passengerID: String) {
        // TODO: 实现 Firestore 监听
        // 临时使用演示数据
        myPublishedTrips = TripRequest.demoTrips.filter { $0.passengerID == passengerID }
        
        print("📡 开始监听我发布的行程: \(passengerID)")
    }
    
    /// 监听我接的订单（司机端使用）
    func startListeningToMyAcceptedTrips(driverID: String) {
        // TODO: 实现 Firestore 监听
        print("📡 开始监听我接的订单: \(driverID)")
    }
    
    /// 监听行程详情
    func startListeningToTripDetails(tripID: UUID) {
        // TODO: 实现 Firestore 监听
        currentTripDetails = myPublishedTrips.first { $0.id == tripID }
        
        print("📡 开始监听行程详情: \(tripID.uuidString)")
    }
    
    /// 移除所有监听器
    func removeAllListeners() {
        listeners.removeAll()
        print("🔇 已移除所有监听器")
    }
    
    /// 手动刷新
    func manualRefresh() async {
        lastSyncTime = Date()
        print("🔄 手动刷新")
    }
}

// MARK: - Network Error Extension
extension NetworkError {
    static func custom(message: String) -> NetworkError {
        return .unknown(message: message)
    }
}

// MARK: - Preview Helper
#if DEBUG
extension RefactoredPassengerViewModel {
    static var preview: RefactoredPassengerViewModel {
        RefactoredPassengerViewModel(
            userID: "passenger_preview",
            userName: "测试乘客",
            userPhone: "+853 6666 6666"
        )
    }
}
#endif
