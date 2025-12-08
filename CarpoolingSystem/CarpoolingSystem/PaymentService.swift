//
//  PaymentService.swift
//  CarpoolingSystem - Payment & Pricing System
//
//  Created on 2025-12-07
//  实现商业级定价和支付系统
//

import Foundation
import StoreKit

// MARK: - Pricing Calculator
/// 定价计算器（商业级）
class PricingCalculator {
    
    // MARK: - 定价常量
    
    /// 基础定价因子
    struct PricingFactors {
        static let baseRatePerKm: Double = 3.0           // 基础价：每公里 3 元
        static let minimumFare: Double = 10.0            // 最低收费：10 元
        static let peakHourMultiplier: Double = 1.5      // 高峰时段倍率
        static let nightMultiplier: Double = 1.3         // 夜间倍率
        static let platformCommissionRate: Double = 0.10 // 平台抽成：10%
        static let insuranceFeeRate: Double = 0.05       // 保险费率：5%
    }
    
    /// 高峰时段定义
    struct PeakHours {
        static let morningStart = 7
        static let morningEnd = 9
        static let eveningStart = 17
        static let eveningEnd = 19
    }
    
    /// 夜间时段定义
    struct NightHours {
        static let start = 22
        static let end = 6
    }
    
    // MARK: - 核心功能：智能定价
    
    /// 计算行程建议价格
    /// - Parameters:
    ///   - distance: 距离（公里）
    ///   - departureTime: 出发时间
    ///   - passengerCount: 乘客数量
    ///   - carType: 车辆类型
    /// - Returns: 定价详情
    static func calculateSuggestedPrice(
        distance: Double,
        departureTime: Date,
        passengerCount: Int = 1,
        carType: CarType = .standard
    ) -> PriceBreakdown {
        print("💰 开始计算价格...")
        print("   距离: \(String(format: "%.2f", distance))km")
        print("   时间: \(departureTime)")
        print("   乘客数: \(passengerCount)")
        
        // 1. 基础价格（按距离）
        var basePrice = distance * PricingFactors.baseRatePerKm
        
        // 2. 车型系数
        basePrice *= carType.priceMultiplier
        
        // 3. 时间系数
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: departureTime)
        var timeMultiplier: Double = 1.0
        var timeReason: String = "正常时段"
        
        // 高峰时段
        if (hour >= PeakHours.morningStart && hour < PeakHours.morningEnd) ||
           (hour >= PeakHours.eveningStart && hour < PeakHours.eveningEnd) {
            timeMultiplier = PricingFactors.peakHourMultiplier
            timeReason = "高峰时段"
        }
        // 夜间时段
        else if hour >= NightHours.start || hour < NightHours.end {
            timeMultiplier = PricingFactors.nightMultiplier
            timeReason = "夜间时段"
        }
        
        let adjustedPrice = basePrice * timeMultiplier
        
        // 4. 确保最低收费
        let totalFare = max(adjustedPrice, PricingFactors.minimumFare)
        
        // 5. 客单价（司机发车模式）
        let unitFare = passengerCount > 0 ? totalFare / Double(passengerCount) : totalFare
        
        // 6. 平台抽成
        let platformCommission = totalFare * PricingFactors.platformCommissionRate
        
        // 7. 保险费
        let insuranceFee = totalFare * PricingFactors.insuranceFeeRate
        
        // 8. 司机实际收入
        let driverEarnings = totalFare - platformCommission - insuranceFee
        
        let breakdown = PriceBreakdown(
            basePrice: basePrice,
            timeMultiplier: timeMultiplier,
            timeReason: timeReason,
            carTypeMultiplier: carType.priceMultiplier,
            carTypeName: carType.displayName,
            totalFare: totalFare,
            unitFare: unitFare,
            platformCommission: platformCommission,
            insuranceFee: insuranceFee,
            driverEarnings: driverEarnings,
            passengerCount: passengerCount
        )
        
        print("✅ 价格计算完成:")
        print("   总费用: ¥\(String(format: "%.2f", totalFare))")
        print("   客单价: ¥\(String(format: "%.2f", unitFare))")
        print("   司机收入: ¥\(String(format: "%.2f", driverEarnings))")
        
        return breakdown
    }
    
    /// 计算动态定价（考虑供需关系）
    /// - Parameters:
    ///   - baseBreakdown: 基础定价
    ///   - demandLevel: 需求水平 (0.0 - 2.0)
    ///   - supplyLevel: 供给水平 (0.0 - 2.0)
    /// - Returns: 调整后的定价
    static func calculateDynamicPrice(
        baseBreakdown: PriceBreakdown,
        demandLevel: Double,
        supplyLevel: Double
    ) -> PriceBreakdown {
        print("📊 计算动态定价...")
        print("   需求水平: \(String(format: "%.2f", demandLevel))")
        print("   供给水平: \(String(format: "%.2f", supplyLevel))")
        
        // 供需比率
        let demandSupplyRatio = demandLevel / max(supplyLevel, 0.1)
        
        // 动态价格倍率（1.0 - 2.0）
        let dynamicMultiplier = min(max(1.0, demandSupplyRatio), 2.0)
        
        var adjustedBreakdown = baseBreakdown
        adjustedBreakdown.totalFare *= dynamicMultiplier
        adjustedBreakdown.unitFare *= dynamicMultiplier
        adjustedBreakdown.driverEarnings *= dynamicMultiplier
        
        print("✅ 动态定价倍率: \(String(format: "%.2f", dynamicMultiplier))")
        print("   调整后总价: ¥\(String(format: "%.2f", adjustedBreakdown.totalFare))")
        
        return adjustedBreakdown
    }
}

// MARK: - Price Breakdown Model
/// 价格详细拆分
struct PriceBreakdown {
    var basePrice: Double              // 基础价格
    var timeMultiplier: Double         // 时间倍率
    var timeReason: String             // 时间原因
    var carTypeMultiplier: Double      // 车型倍率
    var carTypeName: String            // 车型名称
    var totalFare: Double              // 总费用
    var unitFare: Double               // 客单价
    var platformCommission: Double     // 平台抽成
    var insuranceFee: Double           // 保险费
    var driverEarnings: Double         // 司机收入
    var passengerCount: Int            // 乘客数量
    
    /// 格式化的总费用
    var formattedTotalFare: String {
        return "¥\(String(format: "%.2f", totalFare))"
    }
    
    /// 格式化的客单价
    var formattedUnitFare: String {
        return "¥\(String(format: "%.2f", unitFare))"
    }
    
    /// 格式化的司机收入
    var formattedDriverEarnings: String {
        return "¥\(String(format: "%.2f", driverEarnings))"
    }
    
    /// 价格详情字符串
    var detailsString: String {
        return """
        💰 价格详情
        ━━━━━━━━━━━━━━━━━━━━
        基础价格: ¥\(String(format: "%.2f", basePrice))
        时间调整: \(timeReason) (×\(String(format: "%.2f", timeMultiplier)))
        车型: \(carTypeName) (×\(String(format: "%.2f", carTypeMultiplier)))
        ━━━━━━━━━━━━━━━━━━━━
        总费用: \(formattedTotalFare)
        客单价: \(formattedUnitFare) (共 \(passengerCount) 人)
        ━━━━━━━━━━━━━━━━━━━━
        平台服务费: ¥\(String(format: "%.2f", platformCommission))
        保险费: ¥\(String(format: "%.2f", insuranceFee))
        司机收入: \(formattedDriverEarnings)
        """
    }
}

// MARK: - Car Type Enum
/// 车辆类型
enum CarType: String, Codable, CaseIterable {
    case standard = "standard"     // 标准车型
    case comfort = "comfort"       // 舒适车型
    case business = "business"     // 商务车型
    case luxury = "luxury"         // 豪华车型
    
    var displayName: String {
        switch self {
        case .standard: return "标准车"
        case .comfort: return "舒适车"
        case .business: return "商务车"
        case .luxury: return "豪华车"
        }
    }
    
    var priceMultiplier: Double {
        switch self {
        case .standard: return 1.0
        case .comfort: return 1.3
        case .business: return 1.6
        case .luxury: return 2.0
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "car.fill"
        case .comfort: return "car.2.fill"
        case .business: return "suv.side.fill"
        case .luxury: return "car.circle.fill"
        }
    }
}

// MARK: - Payment Service
/// 支付服务（预留第三方支付集成）
@MainActor
class PaymentService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessingPayment: Bool = false
    @Published var paymentError: String?
    @Published var lastTransaction: PaymentTransaction?
    
    // MARK: - Payment Methods
    
    /// 处理现金支付
    func processCashPayment(amount: Double, rideID: String) async throws -> PaymentTransaction {
        print("💵 处理现金支付: ¥\(amount)")
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // 模拟支付处理
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        let transaction = PaymentTransaction(
            id: UUID().uuidString,
            rideID: rideID,
            amount: amount,
            method: .cash,
            status: .completed,
            timestamp: Date()
        )
        
        lastTransaction = transaction
        print("✅ 现金支付完成")
        
        return transaction
    }
    
    /// 处理支付宝支付（预留接口）
    func processAlipayPayment(amount: Double, rideID: String) async throws -> PaymentTransaction {
        print("🅰️ 处理支付宝支付: ¥\(amount)")
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // 实际应用中：
        // 1. 调用支付宝 SDK
        // 2. 生成订单
        // 3. 唤起支付宝 App
        // 4. 处理回调
        
        // 模拟
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let transaction = PaymentTransaction(
            id: UUID().uuidString,
            rideID: rideID,
            amount: amount,
            method: .alipay,
            status: .completed,
            timestamp: Date()
        )
        
        lastTransaction = transaction
        print("✅ 支付宝支付完成")
        
        return transaction
    }
    
    /// 处理微信支付（预留接口）
    func processWeChatPayment(amount: Double, rideID: String) async throws -> PaymentTransaction {
        print("💬 处理微信支付: ¥\(amount)")
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // 实际应用中：
        // 1. 调用微信支付 SDK
        // 2. 生成预支付订单
        // 3. 唤起微信 App
        // 4. 处理回调
        
        // 模拟
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let transaction = PaymentTransaction(
            id: UUID().uuidString,
            rideID: rideID,
            amount: amount,
            method: .wechatPay,
            status: .completed,
            timestamp: Date()
        )
        
        lastTransaction = transaction
        print("✅ 微信支付完成")
        
        return transaction
    }
    
    /// 处理 Stripe 支付（信用卡）
    func processStripePayment(amount: Double, rideID: String) async throws -> PaymentTransaction {
        print("💳 处理 Stripe 支付: ¥\(amount)")
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // 实际应用中：
        // 1. 调用 Stripe SDK
        // 2. 创建 PaymentIntent
        // 3. 确认支付
        // 4. 处理 3D Secure（如需要）
        
        /*
         示例代码（需要集成 Stripe SDK）：
         
         import StripePaymentSheet
         
         let paymentIntentClientSecret = try await createPaymentIntent(amount: amount)
         
         var configuration = PaymentSheet.Configuration()
         configuration.merchantDisplayName = "拼车系统"
         configuration.allowsDelayedPaymentMethods = true
         
         let paymentSheet = PaymentSheet(
             paymentIntentClientSecret: paymentIntentClientSecret,
             configuration: configuration
         )
         
         // 在 UI 中展示支付页面
         // let result = await paymentSheet.present()
         */
        
        // 模拟
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let transaction = PaymentTransaction(
            id: UUID().uuidString,
            rideID: rideID,
            amount: amount,
            method: .stripe,
            status: .completed,
            timestamp: Date()
        )
        
        lastTransaction = transaction
        print("✅ Stripe 支付完成")
        
        return transaction
    }
    
    // MARK: - Transaction Management
    
    /// 获取交易历史
    func fetchTransactionHistory(userID: String) async throws -> [PaymentTransaction] {
        print("📜 获取交易历史: \(userID)")
        
        // 实际应用中：从 Firestore 或后端 API 获取
        // let db = Firestore.firestore()
        // let snapshot = try await db.collection("transactions")
        //     .whereField("userID", isEqualTo: userID)
        //     .order(by: "timestamp", descending: true)
        //     .getDocuments()
        
        // 模拟数据
        return []
    }
    
    /// 退款处理
    func processRefund(transactionID: String, amount: Double) async throws -> PaymentTransaction {
        print("↩️ 处理退款: \(transactionID), 金额: ¥\(amount)")
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // 实际应用中：调用支付服务提供商的退款 API
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let refundTransaction = PaymentTransaction(
            id: UUID().uuidString,
            rideID: "",
            amount: -amount, // 负数表示退款
            method: .cash,
            status: .refunded,
            timestamp: Date()
        )
        
        print("✅ 退款完成")
        return refundTransaction
    }
}

// MARK: - Payment Transaction Model
/// 支付交易记录
struct PaymentTransaction: Identifiable, Codable {
    let id: String
    let rideID: String
    let amount: Double
    let method: PaymentMethod
    var status: PaymentStatus
    let timestamp: Date
    
    var formattedAmount: String {
        let prefix = amount >= 0 ? "+" : ""
        return "\(prefix)¥\(String(format: "%.2f", abs(amount)))"
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: timestamp)
    }
}

// MARK: - Payment Status
/// 支付状态
enum PaymentStatus: String, Codable {
    case pending = "pending"           // 待支付
    case processing = "processing"     // 处理中
    case completed = "completed"       // 已完成
    case failed = "failed"             // 失败
    case refunded = "refunded"         // 已退款
    case cancelled = "cancelled"       // 已取消
    
    var displayName: String {
        switch self {
        case .pending: return "待支付"
        case .processing: return "处理中"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .refunded: return "已退款"
        case .cancelled: return "已取消"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .processing: return "arrow.clockwise"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .refunded: return "arrow.uturn.backward.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .processing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .refunded: return "purple"
        case .cancelled: return "gray"
        }
    }
}

// MARK: - Settlement Service
/// 结算服务（司机收入结算）
class SettlementService {
    
    /// 生成结算报告
    static func generateSettlementReport(
        driverID: String,
        rides: [AdvancedRide],
        transactions: [PaymentTransaction]
    ) -> SettlementReport {
        print("📊 生成结算报告: \(driverID)")
        
        let completedRides = rides.filter { $0.status == .completed }
        
        var totalRevenue: Double = 0
        var totalCommission: Double = 0
        var totalInsurance: Double = 0
        
        for ride in completedRides {
            let revenue = ride.estimatedRevenue
            totalRevenue += revenue
            totalCommission += revenue * PricingCalculator.PricingFactors.platformCommissionRate
            totalInsurance += revenue * PricingCalculator.PricingFactors.insuranceFeeRate
        }
        
        let netEarnings = totalRevenue - totalCommission - totalInsurance
        
        let report = SettlementReport(
            driverID: driverID,
            period: Date(),
            totalRides: completedRides.count,
            totalRevenue: totalRevenue,
            platformCommission: totalCommission,
            insuranceFee: totalInsurance,
            netEarnings: netEarnings
        )
        
        print("✅ 结算报告生成完成")
        print(report.summaryString)
        
        return report
    }
}

// MARK: - Settlement Report
/// 结算报告
struct SettlementReport {
    let driverID: String
    let period: Date
    let totalRides: Int
    let totalRevenue: Double
    let platformCommission: Double
    let insuranceFee: Double
    let netEarnings: Double
    
    var summaryString: String {
        return """
        📊 结算报告
        ━━━━━━━━━━━━━━━━━━━━
        完成行程: \(totalRides) 次
        总收入: ¥\(String(format: "%.2f", totalRevenue))
        平台服务费: -¥\(String(format: "%.2f", platformCommission))
        保险费: -¥\(String(format: "%.2f", insuranceFee))
        ━━━━━━━━━━━━━━━━━━━━
        净收入: ¥\(String(format: "%.2f", netEarnings))
        """
    }
}
