//
//  DriverViewModel.swift
//  CarpoolingSystem - Driver Business Logic (Accept Orders)
//
//  Created on 2025-12-07
//  司机端业务逻辑：浏览订单、接单、完成行程
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

// MARK: - Driver ViewModel
/// 司机端视图模型（商业级 MVVM 架构）
@MainActor
class DriverViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 所有可接单的行程请求（拼车大厅）
    @Published var availableTrips: [TripRequest] = []
    
    /// 筛选后的行程
    @Published var filteredTrips: [TripRequest] = []
    
    /// 我接的订单
    @Published var myAcceptedTrips: [TripRequest] = []
    
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
    
    /// 司机当前位置
    @Published var driverCurrentLocation: CLLocationCoordinate2D?
    
    // MARK: - Filter Properties
    
    /// 筛选条件
    @Published var searchFilter: TripSearchFilter = TripSearchFilter()
    
    /// 排序方式
    @Published var sortOption: SortOption = .departureTime
    
    // MARK: - Private Properties

    private let tripService: TripRealtimeService
    private let notificationService: NotificationService
    private let locationService: DriverLocationService  // 🎯 实时位置追踪服务
    private let currentDriverID: String
    private let currentDriverName: String
    private let currentDriverPhone: String

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(driverID: String, driverName: String, driverPhone: String) {
        self.currentDriverID = driverID
        self.currentDriverName = driverName
        self.currentDriverPhone = driverPhone
        self.tripService = TripRealtimeService(userID: driverID)
        self.notificationService = NotificationService.shared
        self.locationService = DriverLocationService(driverID: driverID)  // 🎯 初始化位置服务

        setupBindings()

        print("🚗 DriverViewModel 初始化完成")
    }
    
    // MARK: - Setup
    
    /// 设置数据绑定
    private func setupBindings() {
        // 监听可用行程变化
        tripService.$availableTrips
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trips in
                guard let self = self else { return }
                
                // 只显示待接单的行程
                self.availableTrips = trips.filter { $0.status == .pending }
                
                // 应用筛选
                self.applyFilters()
                
                print("✅ 可用行程已更新: \(self.availableTrips.count) 条")
            }
            .store(in: &cancellables)
        
        // 监听我接的订单
        tripService.$myAcceptedTrips
            .receive(on: DispatchQueue.main)
            .assign(to: &$myAcceptedTrips)
        
        // 监听行程详情
        tripService.$currentTripDetails
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedTripDetails)
        
        // 监听同步时间
        tripService.$lastSyncTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncTime)
        
        // 监听筛选条件变化
        $searchFilter
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
        
        // 监听排序方式变化
        $sortOption
            .sink { [weak self] _ in
                self?.applySorting()
            }
            .store(in: &cancellables)

        // 🎯 监听司机位置变化（实时同步）
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.driverCurrentLocation = location
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle Methods
    
    /// 启动实时监听
    func startListening() {
        print("📡 启动司机端实时监听...")
        
        tripService.startListeningToAvailableTrips()
        tripService.startListeningToMyAcceptedTrips(driverID: currentDriverID)
    }
    
    /// 停止监听
    func stopListening() {
        print("🔇 停止司机端监听...")
        
        tripService.removeAllListeners()
    }
    
    /// 监听特定行程详情
    func listenToTripDetails(tripID: UUID) {
        print("📡 监听行程详情: \(tripID.uuidString)")
        
        tripService.startListeningToTripDetails(tripID: tripID)
    }
    
    // MARK: - Core Functions
    
    /// 接单（核心功能）
    /// - Parameter trip: 要接的行程
    func acceptTrip(_ trip: TripRequest) async {
        print("✅ 接单: \(trip.id.uuidString)")
        
        // 防止重复提交
        guard !isLoading else {
            print("⚠️ 正在处理中，请勿重复提交")
            return
        }
        
        // 前置检查
        guard trip.canBeAccepted else {
            errorAlert = ErrorAlert(
                title: "无法接单",
                message: "该订单已被其他司机接单或状态不允许接单"
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 更新订单状态
            var updatedTrip = trip
            updatedTrip.driverID = currentDriverID
            updatedTrip.driverName = currentDriverName
            updatedTrip.driverPhone = currentDriverPhone
            updatedTrip.status = .accepted
            updatedTrip.updatedAt = Date()
            
            // 如果司机有当前位置，也更新进去
            if let location = driverCurrentLocation {
                updatedTrip.driverCurrentLocation = Coordinate(location)
            }
            
            // 保存到 Firestore
            try await tripService.updateTrip(updatedTrip)
            
            // 成功提示
            successMessage = "接单成功！预期收入: ¥\(String(format: "%.2f", trip.expectedIncome))"
            
            // 发送通知给乘客
            try await notificationService.sendRequestAcceptedNotification(
                to: trip.passengerID,
                rideID: trip.id.uuidString,
                driverName: currentDriverName
            )
            
            // 🎯 关键：如果人数已满，自动进入待支付状态
            if trip.numberOfPassengers >= 1 {
                try await markTripAsAwaitingPayment(tripID: trip.id)
            }

            // 🎯 核心交付物：接单后立即开始实时位置追踪（每 3-5 秒上传）
            locationService.startTracking(for: trip.id)
            print("📍 已启动实时位置追踪")

            print("✅ 接单成功")
            
        } catch let error as NSError {
            print("❌ 接单失败: \(error.localizedDescription)")
            
            let networkError = mapFirebaseError(error)
            errorAlert = ErrorAlert(error: networkError) { [weak self] in
                Task {
                    await self?.acceptTrip(trip)
                }
            }
        }
    }
    
    /// 标记订单为待支付状态
    /// - Parameter tripID: 行程 ID
    private func markTripAsAwaitingPayment(tripID: UUID) async throws {
        print("💳 标记订单为待支付: \(tripID.uuidString)")
        
        guard var trip = selectedTripDetails ?? availableTrips.first(where: { $0.id == tripID }) else {
            throw NetworkError.rideNotFound
        }
        
        // 更新状态
        trip.status = .awaitingPayment
        trip.updatedAt = Date()
        
        // 保存
        try await tripService.updateTrip(trip)
        
        // 通知乘客支付
        // TODO: 发送支付通知
        
        print("✅ 已标记为待支付")
    }
    
    /// 开始行程
    /// - Parameter tripID: 行程 ID
    func startTrip(tripID: UUID) async {
        print("🚗 开始行程: \(tripID.uuidString)")
        
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await tripService.updateTripStatus(tripID: tripID, newStatus: .inProgress)
            
            successMessage = "行程已开始"
            
            // 发送通知给乘客
            if let trip = myAcceptedTrips.first(where: { $0.id == tripID }) {
                try await notificationService.sendRideStartedNotification(
                    to: [trip.passengerID],
                    rideID: tripID.uuidString,
                    driverName: currentDriverName,
                    startLocation: trip.startLocation
                )
            }
            
            print("✅ 行程已开始")
            
        } catch {
            print("❌ 开始行程失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "开始失败",
                message: error.localizedDescription
            )
        }
    }
    
    /// 完成行程
    /// - Parameter tripID: 行程 ID
    func completeTrip(tripID: UUID) async {
        print("🏁 完成行程: \(tripID.uuidString)")
        
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await tripService.updateTripStatus(tripID: tripID, newStatus: .completed)
            
            successMessage = "行程已完成"
            
            // 发送通知给乘客
            if let trip = myAcceptedTrips.first(where: { $0.id == tripID }) {
                try await notificationService.sendRideCompletedNotification(
                    to: [trip.passengerID],
                    rideID: tripID.uuidString,
                    totalPrice: trip.totalCost
                )
            }

            // 🎯 核心交付物：行程完成后停止位置追踪
            locationService.stopTracking()
            print("📍 已停止实时位置追踪")

            print("✅ 行程已完成")
            
        } catch {
            print("❌ 完成行程失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "完成失败",
                message: error.localizedDescription
            )
        }
    }
    
    // MARK: - Filter & Search Functions
    
    /// 应用筛选条件
    func applyFilters() {
        var results = availableTrips
        
        // 1. 时间窗口筛选（±10分钟）
        if let targetTime = searchFilter.departureTime {
            results = results.filter { trip in
                trip.isWithinTimeWindow(
                    of: targetTime,
                    windowMinutes: searchFilter.timeWindowMinutes
                )
            }
            
            print("🕐 时间窗口筛选: \(results.count) 条")
        }
        
        // 2. 起点位置筛选
        if let startLocation = searchFilter.startLocation {
            results = results.filter { trip in
                trip.startCoordinate.isNear(
                    startLocation,
                    within: searchFilter.locationRadiusMeters
                )
            }
            
            print("📍 起点筛选: \(results.count) 条")
        }
        
        // 3. 终点位置筛选
        if let endLocation = searchFilter.endLocation {
            results = results.filter { trip in
                trip.endCoordinate.isNear(
                    endLocation,
                    within: searchFilter.locationRadiusMeters
                )
            }
            
            print("🎯 终点筛选: \(results.count) 条")
        }
        
        // 4. 最高单价筛选
        if let maxPrice = searchFilter.maxPricePerPerson {
            results = results.filter { trip in
                trip.pricePerPerson <= maxPrice
            }
        }
        
        // 5. 最少座位数筛选
        results = results.filter { trip in
            trip.numberOfPassengers >= searchFilter.minSeats
        }
        
        filteredTrips = results
        
        // 应用排序
        applySorting()
        
        print("🔍 筛选完成: \(results.count) / \(availableTrips.count)")
    }
    
    /// 清空筛选条件
    func clearFilters() {
        searchFilter = TripSearchFilter()
        applyFilters()
    }

    // 🚫 搜索行程功能已移除 - 司机只能通过拼车大厅浏览订单

    /// 筛选指定时间附近的行程（±10分钟）
    /// 这是核心交付物之一：时间窗口筛选
    func filterTrips(near targetTime: Date, windowMinutes: Int = 10) -> [TripRequest] {
        let filtered = availableTrips.filter { trip in
            trip.isWithinTimeWindow(of: targetTime, windowMinutes: windowMinutes)
        }
        
        print("🕐 时间窗口筛选 (\(windowMinutes)分钟): \(filtered.count) 条")
        
        return filtered
    }
    
    // MARK: - Sorting Functions
    
    /// 应用排序
    private func applySorting() {
        switch sortOption {
        case .departureTime:
            filteredTrips.sort { $0.departureTime < $1.departureTime }
        case .expectedIncome:
            filteredTrips.sort { $0.expectedIncome > $1.expectedIncome }
        case .distance:
            if let driverLocation = driverCurrentLocation {
                filteredTrips.sort { trip1, trip2 in
                    let distance1 = Coordinate(driverLocation).distance(to: trip1.startCoordinate)
                    let distance2 = Coordinate(driverLocation).distance(to: trip2.startCoordinate)
                    return distance1 < distance2
                }
            }
        case .numberOfPassengers:
            filteredTrips.sort { $0.numberOfPassengers > $1.numberOfPassengers }
        }
        
        print("📊 已按 \(sortOption.displayName) 排序")
    }
    
    // MARK: - Location Functions
    
    /// 更新司机位置
    func updateDriverLocation(_ location: CLLocationCoordinate2D) {
        self.driverCurrentLocation = location
        
        print("📍 司机位置已更新: (\(location.latitude), \(location.longitude))")
        
        // 如果有距离排序，重新排序
        if sortOption == .distance {
            applySorting()
        }
    }
    
    /// 计算距离
    func calculateDistance(to trip: TripRequest) -> Double? {
        guard let driverLocation = driverCurrentLocation else {
            return nil
        }
        
        return Coordinate(driverLocation).distanceInKilometers(to: trip.startCoordinate)
    }
    
    /// 计算 ETA
    func calculateETA(to trip: TripRequest) -> Int? {
        guard let distance = calculateDistance(to: trip) else {
            return nil
        }
        
        // 假设平均速度 40 km/h
        let hours = distance / 40.0
        let minutes = Int(ceil(hours * 60))
        
        return max(minutes, 1)
    }
    
    // MARK: - Utility Functions
    
    /// 手动刷新
    func refresh() async {
        print("🔄 手动刷新数据...")
        
        isLoading = true
        defer { isLoading = false }
        
        await tripService.manualRefresh()
        
        successMessage = "刷新成功"
    }
    
    /// 格式化价格
    func formatPrice(_ price: Double) -> String {
        return String(format: "¥%.2f", price)
    }
    
    /// 格式化距离
    func formatDistance(_ distance: Double) -> String {
        if distance < 1.0 {
            return String(format: "%.0f米", distance * 1000)
        } else {
            return String(format: "%.1f公里", distance)
        }
    }
}

// MARK: - Sort Option Enum
/// 排序选项
enum SortOption: String, CaseIterable {
    case departureTime = "departure_time"       // 出发时间
    case expectedIncome = "expected_income"     // 预期收入
    case distance = "distance"                  // 距离
    case numberOfPassengers = "passengers"      // 人数
    
    var displayName: String {
        switch self {
        case .departureTime:
            return "出发时间"
        case .expectedIncome:
            return "预期收入"
        case .distance:
            return "距离"
        case .numberOfPassengers:
            return "人数"
        }
    }
    
    var icon: String {
        switch self {
        case .departureTime:
            return "clock"
        case .expectedIncome:
            return "dollarsign.circle"
        case .distance:
            return "location"
        case .numberOfPassengers:
            return "person.3"
        }
    }
}

// MARK: - Preview Helper
#if DEBUG
extension DriverViewModel {
    static var preview: DriverViewModel {
        DriverViewModel(
            driverID: "driver_preview",
            driverName: "测试司机",
            driverPhone: "+853 8888 8888"
        )
    }
}
#endif
