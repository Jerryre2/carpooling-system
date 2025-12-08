//
//  DriverLocationService.swift
//  CarpoolingSystem - Real-time Driver Location Tracking
//
//  Created on 2025-12-08
//  司机实时位置服务：每 3-5 秒自动上传位置到 Firebase
//

import Foundation
import CoreLocation
import FirebaseFirestore
import Combine

// MARK: - Driver Location Update Model
/// 司机位置更新模型（符合你的需求：Codable）
struct DriverLocationUpdate: Codable, Identifiable {
    let id: UUID
    let driverID: String
    let currentLocation: Coordinate
    let timestamp: Date

    init(driverID: String, currentLocation: Coordinate) {
        self.id = UUID()
        self.driverID = driverID
        self.currentLocation = currentLocation
        self.timestamp = Date()
    }
}

// MARK: - Driver Location Service
/// 商业级司机位置追踪服务
/// 核心功能：每 3-5 秒自动上传司机位置到 Firebase
@MainActor
class DriverLocationService: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 当前位置
    @Published var currentLocation: CLLocationCoordinate2D?

    /// 是否正在追踪
    @Published var isTracking: Bool = false

    /// 最后上传时间
    @Published var lastUploadTime: Date?

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private let db = Firestore.firestore()
    private let driverID: String
    private var currentTripID: UUID?

    /// 上传间隔（秒）- 符合你的需求：3-5 秒
    private let uploadIntervalSeconds: TimeInterval = 4.0
    private var uploadTimer: Timer?

    /// 位置更新缓存（优化性能）
    private var latestLocationForUpload: CLLocationCoordinate2D?

    // MARK: - Initialization

    init(driverID: String) {
        self.driverID = driverID
        self.locationManager = CLLocationManager()

        super.init()

        setupLocationManager()

        print("📍 DriverLocationService 初始化完成，司机ID: \(driverID)")
    }

    deinit {
        stopTracking()
        print("📍 DriverLocationService 析构")
    }

    // MARK: - Setup

    /// 配置位置管理器
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 移动 10 米才更新（节省电量）
        locationManager.allowsBackgroundLocationUpdates = true // 后台定位
        locationManager.pausesLocationUpdatesAutomatically = false

        // 请求权限
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Public Methods

    /// 🎯 核心功能 1：开始追踪并上传位置
    /// - Parameter tripID: 当前行程 ID
    func startTracking(for tripID: UUID) {
        guard !isTracking else {
            print("⚠️ 已经在追踪中")
            return
        }

        self.currentTripID = tripID
        self.isTracking = true

        // 开始位置更新
        locationManager.startUpdatingLocation()

        // 启动定时上传（每 4 秒上传一次）
        startUploadTimer()

        print("📍 开始追踪位置，行程ID: \(tripID.uuidString)")
    }

    /// 🎯 核心功能 2：停止追踪
    func stopTracking() {
        guard isTracking else { return }

        isTracking = false
        currentTripID = nil

        locationManager.stopUpdatingLocation()

        // 停止定时器
        stopUploadTimer()

        print("📍 停止追踪位置")
    }

    /// 手动上传当前位置
    func uploadCurrentLocation() async throws {
        guard let tripID = currentTripID,
              let location = latestLocationForUpload else {
            print("⚠️ 无法上传：缺少行程ID或位置数据")
            return
        }

        await uploadLocation(location, for: tripID)
    }

    // MARK: - Private Methods

    /// 启动定时上传
    private func startUploadTimer() {
        // 清除旧的定时器
        stopUploadTimer()

        // 创建新的定时器（每 4 秒触发一次）
        uploadTimer = Timer.scheduledTimer(
            withTimeInterval: uploadIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performScheduledUpload()
            }
        }

        // 立即触发一次上传
        uploadTimer?.fire()

        print("⏱️ 定时上传已启动，间隔: \(uploadIntervalSeconds) 秒")
    }

    /// 停止定时上传
    private func stopUploadTimer() {
        uploadTimer?.invalidate()
        uploadTimer = nil
    }

    /// 执行定时上传
    private func performScheduledUpload() async {
        guard let tripID = currentTripID,
              let location = latestLocationForUpload else {
            return
        }

        await uploadLocation(location, for: tripID)
    }

    /// 🎯 核心功能 3：上传位置到 Firebase
    /// 这是核心交付物：实时同步司机位置给乘客
    private func uploadLocation(_ location: CLLocationCoordinate2D, for tripID: UUID) async {
        do {
            // 创建位置更新模型
            let locationUpdate = DriverLocationUpdate(
                driverID: driverID,
                currentLocation: Coordinate(latitude: location.latitude, longitude: location.longitude)
            )

            // 🔥 方案 1：更新 TripRequest 中的司机位置（用于 NewRideModels）
            let tripDocRef = db.collection("trips").document(tripID.uuidString)
            try await tripDocRef.updateData([
                "driverCurrentLocation": [
                    "latitude": location.latitude,
                    "longitude": location.longitude
                ],
                "updatedAt": FieldValue.serverTimestamp()
            ])

            // 🔥 方案 2：更新 AdvancedRide 中的司机位置（用于 RideModels）
            let advancedRideDocRef = db.collection("advancedRides").document(tripID.uuidString)
            try await advancedRideDocRef.updateData([
                "driverLatitude": location.latitude,
                "driverLongitude": location.longitude,
                "driverCurrentLocation": [
                    "latitude": location.latitude,
                    "longitude": location.longitude
                ],
                "updatedAt": FieldValue.serverTimestamp()
            ])

            // 更新本地状态
            lastUploadTime = Date()

            print("✅ 位置已上传: (\(location.latitude), \(location.longitude))")

            // ✅ 实时监听器会自动将此位置推送到乘客端
        } catch {
            print("❌ 位置上传失败: \(error.localizedDescription)")
            errorMessage = "位置同步失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension DriverLocationService: CLLocationManagerDelegate {

    /// 位置更新回调
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // 更新当前位置
            self.currentLocation = location.coordinate

            // 缓存最新位置供上传使用
            self.latestLocationForUpload = location.coordinate

            print("📍 位置已更新: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }
    }

    /// 权限变更回调
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ 位置权限已授权")
            case .denied, .restricted:
                print("❌ 位置权限被拒绝")
                self.errorMessage = "请在设置中允许位置访问"
            case .notDetermined:
                print("⚠️ 位置权限未确定")
            @unknown default:
                break
            }
        }
    }

    /// 位置错误回调
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ 位置获取失败: \(error.localizedDescription)")
            self.errorMessage = "位置获取失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Usage Example (核心交付物)
/*
 // 在司机端 ViewModel 或 View 中使用：

 @StateObject private var locationService: DriverLocationService

 init(driverID: String) {
     _locationService = StateObject(wrappedValue: DriverLocationService(driverID: driverID))
 }

 // 当司机接单后，开始追踪：
 func onAcceptTrip(_ trip: TripRequest) async {
     // 接单逻辑...

     // 🎯 开始实时位置追踪（每 3-5 秒上传）
     locationService.startTracking(for: trip.id)
 }

 // 当行程结束，停止追踪：
 func onTripCompleted() {
     locationService.stopTracking()
 }

 // 在 UI 中显示追踪状态：
 if locationService.isTracking {
     HStack {
         Circle()
             .fill(Color.green)
             .frame(width: 8, height: 8)
         Text("实时位置同步中")
             .font(.caption)
     }
 }
 */
