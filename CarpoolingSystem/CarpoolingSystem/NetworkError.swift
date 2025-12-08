//
//  NetworkError.swift
//  CarpoolingSystem - Unified Error Handling
//
//  Created on 2025-12-07
//  统一网络错误处理（商业级）
//

import Foundation

// MARK: - Network Error Enum
/// 统一网络错误枚举（禁止使用强制解包）
enum NetworkError: Error, LocalizedError {
    case networkUnavailable                     // 网络不可用
    case timeout                                // 请求超时
    case serverError(statusCode: Int)          // 服务器错误
    case decodingFailed(underlyingError: Error)// 解析失败
    case invalidData                            // 无效数据
    case unauthorized                           // 未授权
    case notFound                               // 资源未找到
    case duplicateRequest                       // 重复请求
    case seatsFull                              // 座位已满
    case invalidRideStatus                      // 行程状态不允许操作
    case alreadyJoined                          // 已加入行程
    case permissionDenied                       // 权限不足
    case rideNotFound                           // 行程未找到
    case unknown(message: String)               // 未知错误
    
    // MARK: - User-Friendly Error Messages
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络连接不可用，请检查您的网络设置"
        case .timeout:
            return "请求超时，请稍后重试"
        case .serverError(let statusCode):
            return "服务器错误 (\(statusCode))，请稍后重试"
        case .decodingFailed(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .invalidData:
            return "接收到无效数据"
        case .unauthorized:
            return "未授权访问，请重新登录"
        case .notFound:
            return "请求的资源不存在"
        case .duplicateRequest:
            return "请勿重复提交请求"
        case .seatsFull:
            return "座位已满，无法加入"
        case .invalidRideStatus:
            return "当前行程状态不允许此操作"
        case .alreadyJoined:
            return "您已经加入此行程"
        case .permissionDenied:
            return "权限不足，无法执行此操作"
        case .rideNotFound:
            return "行程不存在或已被删除"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
    
    // MARK: - Error Icon (for UI)
    var iconName: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .serverError:
            return "server.rack"
        case .decodingFailed, .invalidData:
            return "doc.badge.exclamationmark"
        case .unauthorized, .permissionDenied:
            return "lock.shield"
        case .notFound, .rideNotFound:
            return "magnifyingglass"
        case .duplicateRequest:
            return "doc.on.doc"
        case .seatsFull:
            return "person.3.fill"
        case .invalidRideStatus:
            return "exclamationmark.triangle"
        case .alreadyJoined:
            return "checkmark.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    // MARK: - Retry Capability
    var canRetry: Bool {
        switch self {
        case .networkUnavailable, .timeout, .serverError:
            return true
        case .unauthorized, .permissionDenied:
            return false
        case .seatsFull, .alreadyJoined, .invalidRideStatus:
            return false
        default:
            return true
        }
    }
}

// MARK: - Result Extension for Better Error Handling
extension Result where Failure == NetworkError {
    /// 将 Result 转换为可选值（忽略错误）
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// 将 Result 转换为错误（忽略成功值）
    var error: NetworkError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}

// MARK: - Firebase Error Mapping
/// 将 Firebase 错误映射为自定义错误
func mapFirebaseError(_ error: Error) -> NetworkError {
    let nsError = error as NSError
    
    // 检查错误域
    switch nsError.domain {
    case "FIRFirestoreErrorDomain":
        switch nsError.code {
        case 7: // 权限被拒绝
            return .permissionDenied
        case 5: // 未找到
            return .rideNotFound
        case 14: // 服务不可用
            return .networkUnavailable
        case 4: // 超时
            return .timeout
        default:
            return .serverError(statusCode: nsError.code)
        }
        
    case NSURLErrorDomain:
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .timeout
        default:
            return .unknown(message: error.localizedDescription)
        }
        
    default:
        return .unknown(message: error.localizedDescription)
    }
}

// MARK: - Error Alert Model (for SwiftUI)
/// 错误提示框模型
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let iconName: String
    let canRetry: Bool
    let retryAction: (() -> Void)?
    
    init(error: NetworkError, retryAction: (() -> Void)? = nil) {
        self.title = "操作失败"
        self.message = error.errorDescription ?? "发生未知错误"
        self.iconName = error.iconName
        self.canRetry = error.canRetry
        self.retryAction = retryAction
    }
    
    init(title: String, message: String, iconName: String = "exclamationmark.triangle") {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.canRetry = false
        self.retryAction = nil
    }
}
