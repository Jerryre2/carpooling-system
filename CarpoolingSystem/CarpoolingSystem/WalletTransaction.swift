//
//  WalletTransaction.swift
//  CarpoolingSystem
//
//  Created by 葛泰泽 on 08/12/2025.
//

//
//  WalletTransaction.swift
//  CarpoolingSystem - Wallet Transaction Model
//
//  Created on 2025-12-07
//  钱包交易记录模型（独立于支付系统）
//

import Foundation
import FirebaseFirestore

// MARK: - Wallet Transaction
/// 钱包交易记录（用于钱包视图展示）
struct WalletTransaction: Identifiable, Codable {
    var id: String
    let userID: String
    let type: WalletTransactionType
    let amount: Double
    let description: String
    let status: WalletTransactionStatus
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        userID: String,
        type: WalletTransactionType,
        amount: Double,
        description: String,
        status: WalletTransactionStatus = .completed,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.type = type
        self.amount = amount
        self.description = description
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Wallet Transaction Type
enum WalletTransactionType: String, Codable {
    case payment = "payment"
    case refund = "refund"
    case topUp = "top_up"
    case earning = "earning"
    
    var displayName: String {
        switch self {
        case .payment:
            return "支付"
        case .refund:
            return "退款"
        case .topUp:
            return "充值"
        case .earning:
            return "收入"
        }
    }
}

// MARK: - Wallet Transaction Status
enum WalletTransactionStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName1: String {
        switch self {
        case .pending:
            return "处理中"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .cancelled:
            return "已取消"
        }
    }
}
