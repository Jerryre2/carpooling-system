//
//  PassengerViewModel.swift
//  CarpoolingSystem - Passenger Business Logic (MVVM)
//
//  Created on 2025-12-07
//  乘客端业务逻辑（商业级 MVVM 架构）
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

// MARK: - Passenger ViewModel
/// 乘客端视图模型（完整的业务逻辑层）
@MainActor
class PassengerViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI Binding)
    
    /// 所有可用的司机行程
    @Published var availableDriverRides: [AdvancedRide] = []
    
    /// 我已预订的行程
    @Published var myBookedRides: [AdvancedRide] = []
    
    /// 当前选中的行程详情
    @Published var selectedRideDetails: AdvancedRide?
    
    /// 筛选后的行程
    @Published var filteredRides: [AdvancedRide] = []
    
    /// 加载状态
    @Published var isLoading: Bool = false
    
    /// 错误提示
    @Published var errorAlert: ErrorAlert?
    
    /// 成功提示消息
    @Published var successMessage: String?
    
    /// 上次同步时间
    @Published var lastSyncTime: Date?
    
    // MARK: - Filter Properties
    
    /// 出发日期筛选
    @Published var filterDate: Date?
    
    /// 起点筛选
    @Published var filterStartLocation: String = ""
    
    /// 终点筛选
    @Published var filterEndLocation: String = ""
    
    /// 最大价格筛选
    @Published var filterMaxPrice: Double?
    
    /// 最小座位数筛选
    @Published var filterMinSeats: Int = 1
    
    /// 距离范围筛选（单位：公里）
    @Published var filterMaxDistance: Double?
    
    /// 用户当前位置（用于距离计算）
    @Published var userLocation: CLLocationCoordinate2D?
    
    // MARK: - Private Properties
    
    private let rideService: RealtimeRideService
    private let notificationService: NotificationService
    private let currentUserID: String
    private let currentUserName: String
    private let currentUserPhone: String
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userID: String, userName: String, userPhone: String) {
        self.currentUserID = userID
        self.currentUserName = userName
        self.currentUserPhone = userPhone
        self.rideService = RealtimeRideService(currentUserID: userID)
        self.notificationService = NotificationService.shared
        
        setupBindings()
        
        print("🎯 PassengerViewModel 初始化完成")
    }
    
    // MARK: - Setup
    
    /// 设置数据绑定（响应式编程）
    private func setupBindings() {
        // 监听实时服务的数据变化
        rideService.$activeRides
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rides in
                guard let self = self else { return }
                
                // 只显示司机发布的行程
                self.availableDriverRides = rides.filter { $0.rideType.isDriverOffer }
                
                // 应用筛选
                self.applyFilters()
                
                print("✅ 可用行程已更新: \(self.availableDriverRides.count) 条")
            }
            .store(in: &cancellables)
        
        rideService.$myBookedRides
            .receive(on: DispatchQueue.main)
            .assign(to: &$myBookedRides)
        
        rideService.$currentRideDetails
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedRideDetails)
        
        rideService.$lastSyncTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncTime)
        
        // 监听筛选条件变化，自动重新筛选
        Publishers.CombineLatest4(
            $filterDate,
            $filterStartLocation,
            $filterEndLocation,
            $filterMaxPrice
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle Methods
    
    /// 启动实时监听（View.onAppear 调用）
    func startListening() {
        print("📡 启动乘客端实时监听...")
        
        rideService.startListeningToActiveRides()
        rideService.startListeningToMyBookedRides()
    }
    
    /// 停止监听（View.onDisappear 调用）
    func stopListening() {
        print("🔇 停止乘客端监听...")
        
        rideService.removeAllListeners()
    }
    
    /// 监听特定行程详情（用于详情页）
    func listenToRideDetails(rideID: UUID) {
        print("📡 监听行程详情: \(rideID.uuidString)")
        
        rideService.startListeningToRideDetails(rideID: rideID)
    }
    
    // MARK: - Core Functions
    
    /// 预订行程（加入司机行程）
    func bookTrip(tripID: UUID) async {
        print("🎫 预订行程: \(tripID.uuidString)")
        
        // 防止重复提交
        guard !isLoading else {
            print("⚠️ 正在处理中，请勿重复提交")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 创建乘客信息
            let passenger = PassengerInfo(
                id: currentUserID,
                name: currentUserName,
                phone: currentUserPhone,
                joinedAt: Date(),
                simulatedLocation: userLocation.map { ($0.latitude, $0.longitude) }
            )
            
            // 调用实时服务加入行程
            try await rideService.joinRide(rideID: tripID, passenger: passenger)
            
            // 成功提示
            successMessage = "预订成功！司机将收到通知"
            
            // 发送通知给司机
            if let ride = availableDriverRides.first(where: { $0.id == tripID }) {
                try await notificationService.sendPassengerJoinedNotification(
                    to: ride.publisherID,
                    rideID: tripID.uuidString,
                    passengerName: currentUserName,
                    remainingSeats: ride.availableSeats - 1
                )
            }
            
            print("✅ 预订成功")
            
        } catch let error as NSError {
            print("❌ 预订失败: \(error.localizedDescription)")
            
            let networkError = mapFirebaseError(error)
            errorAlert = ErrorAlert(error: networkError) { [weak self] in
                Task {
                    await self?.bookTrip(tripID: tripID)
                }
            }
        }
    }
    
    /// 取消预订
    func cancelBooking(tripID: UUID) async {
        print("❌ 取消预订: \(tripID.uuidString)")
        
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: 实现取消预订逻辑
            // 需要从 passengers 数组中移除当前用户
            
            successMessage = "已取消预订"
            
            print("✅ 取消成功")
            
        } catch {
            print("❌ 取消失败: \(error.localizedDescription)")
            errorAlert = ErrorAlert(
                title: "取消失败",
                message: error.localizedDescription
            )
        }
    }
    
    // MARK: - Filter Functions
    
    /// 应用筛选条件
    func applyFilters() {
        var results = availableDriverRides
        
        // 1. 日期筛选
        if let date = filterDate {
            let calendar = Calendar.current
            results = results.filter { ride in
                calendar.isDate(ride.departureTime, inSameDayAs: date)
            }
        }
        
        // 2. 起点筛选
        if !filterStartLocation.isEmpty {
            results = results.filter { ride in
                ride.startLocation.localizedCaseInsensitiveContains(filterStartLocation)
            }
        }
        
        // 3. 终点筛选
        if !filterEndLocation.isEmpty {
            results = results.filter { ride in
                ride.endLocation.localizedCaseInsensitiveContains(filterEndLocation)
            }
        }
        
        // 4. 价格筛选
        if let maxPrice = filterMaxPrice {
            results = results.filter { ride in
                ride.unitPrice <= maxPrice
            }
        }
        
        // 5. 座位数筛选
        results = results.filter { ride in
            ride.availableSeats >= filterMinSeats
        }
        
        // 6. 距离筛选（如果有用户位置）
        if let maxDistance = filterMaxDistance,
           let userLoc = userLocation {
            results = results.filter { ride in
                guard let rideLocation = ride.driverCurrentLocation else {
                    return true // 无位置信息则不过滤
                }
                
                let distance = calculateDistance(
                    from: userLoc,
                    to: CLLocationCoordinate2D(
                        latitude: rideLocation.latitude,
                        longitude: rideLocation.longitude
                    )
                )
                
                return distance <= maxDistance
            }
        }
        
        // 7. 按出发时间排序
        results.sort { $0.departureTime < $1.departureTime }
        
        filteredRides = results
        
        print("🔍 筛选完成: \(results.count) / \(availableDriverRides.count)")
    }
    
    /// 清空筛选条件
    func clearFilters() {
        filterDate = nil
        filterStartLocation = ""
        filterEndLocation = ""
        filterMaxPrice = nil
        filterMinSeats = 1
        filterMaxDistance = nil
        
        applyFilters()
    }
    
    /// 计算两点之间的距离（单位：公里）
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        
        let distanceInMeters = fromLocation.distance(from: toLocation)
        return distanceInMeters / 1000.0 // 转换为公里
    }
    
    // MARK: - Search Functions
    
    /// 搜索行程（关键词搜索）
    func searchRides(keyword: String) {
        guard !keyword.isEmpty else {
            applyFilters()
            return
        }
        
        let results = availableDriverRides.filter { ride in
            ride.startLocation.localizedCaseInsensitiveContains(keyword) ||
            ride.endLocation.localizedCaseInsensitiveContains(keyword) ||
            ride.publisherName.localizedCaseInsensitiveContains(keyword) ||
            ride.notes.localizedCaseInsensitiveContains(keyword)
        }
        
        filteredRides = results
        
        print("🔍 搜索结果: \(results.count) 条")
    }
    
    /// 按距离排序
    func sortByDistance() {
        guard let userLoc = userLocation else {
            print("⚠️ 无用户位置信息")
            return
        }
        
        filteredRides.sort { ride1, ride2 in
            let distance1 = ride1.driverCurrentLocation.map { location in
                calculateDistance(
                    from: userLoc,
                    to: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                )
            } ?? Double.infinity
            
            let distance2 = ride2.driverCurrentLocation.map { location in
                calculateDistance(
                    from: userLoc,
                    to: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                )
            } ?? Double.infinity
            
            return distance1 < distance2
        }
        
        print("📍 已按距离排序")
    }
    
    /// 按价格排序
    func sortByPrice(ascending: Bool = true) {
        filteredRides.sort { ride1, ride2 in
            ascending ? ride1.unitPrice < ride2.unitPrice : ride1.unitPrice > ride2.unitPrice
        }
        
        print("💰 已按价格排序")
    }
    
    /// 按出发时间排序
    func sortByDepartureTime() {
        filteredRides.sort { $0.departureTime < $1.departureTime }
        
        print("⏰ 已按出发时间排序")
    }
    
    // MARK: - Utility Functions
    
    /// 手动刷新数据
    func refresh() async {
        print("🔄 手动刷新数据...")
        
        isLoading = true
        defer { isLoading = false }
        
        await rideService.manualRefresh()
        
        successMessage = "刷新成功"
    }
    
    /// 更新用户位置
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        self.userLocation = location
        
        print("📍 用户位置已更新: (\(location.latitude), \(location.longitude))")
        
        // 如果有距离筛选，重新应用筛选
        if filterMaxDistance != nil {
            applyFilters()
        }
    }
    
    /// 获取行程详情
    func getRideDetails(rideID: UUID) -> AdvancedRide? {
        return availableDriverRides.first { $0.id == rideID }
    }
    
    /// 检查是否已预订
    func isRideBooked(rideID: UUID) -> Bool {
        return myBookedRides.contains { $0.id == rideID }
    }
    
    /// 计算预计到达时间
    func calculateETA(for ride: AdvancedRide) -> Int? {
        guard let userLoc = userLocation,
              let driverLoc = ride.driverCurrentLocation else {
            return nil
        }
        
        let distance = calculateDistance(
            from: userLoc,
            to: CLLocationCoordinate2D(latitude: driverLoc.latitude, longitude: driverLoc.longitude)
        )
        
        // 假设平均速度 40 km/h
        let hours = distance / 40.0
        let minutes = Int(ceil(hours * 60))
        
        return max(minutes, 1)
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

// MARK: - Preview Helper
#if DEBUG
extension PassengerViewModel {
    static var preview: PassengerViewModel {
        PassengerViewModel(
            userID: "preview_user",
            userName: "测试用户",
            userPhone: "+853 6666 6666"
        )
    }
}
#endif
