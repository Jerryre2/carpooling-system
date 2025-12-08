//
//  TypeAliases.swift
//  CarpoolingSystem
//
//  Type management to avoid conflicts
//

import Foundation

// ⚠️ 此文件仅用于文档说明，不定义任何类型别名
// ⚠️ 直接使用 AppUser 和 UserRole，不要使用 User

/*
 类型使用指南：
 
 1. 应用用户数据：
    - 使用 `AppUser` 结构体（定义在 UserModels.swift）
    - 示例：let user: AppUser = ...
 
 2. 用户角色：
    - 使用 `UserRole` 枚举（定义在 UserModels.swift）
    - 示例：let role: UserRole = .carOwner
 
 3. Firebase 认证：
    - Firebase Auth 的 User 类由 Firebase SDK 提供
    - 示例：Auth.auth().currentUser
 
 4. 避免使用：
    - ❌ 不要使用 `User` 作为类型名（会与 Firebase 冲突）
    - ✅ 始终使用 `AppUser`
 */

