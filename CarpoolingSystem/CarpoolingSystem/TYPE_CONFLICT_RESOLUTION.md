# 🔧 类型冲突解决方案

## 问题说明

由于项目中存在多个同名类型定义，导致编译错误。我已经将重构后的类型重命名为带 `Refactored` 前缀的版本。

## 类型映射表

| 旧名称 | 新名称（避免冲突） | 用途 |
|--------|------------------|------|
| `User` | `RefactoredUser` | 用户模型（包含钱包） |
| `UserRole` | `RefactoredUserRole` | 用户角色枚举 |
| `PaymentTransaction` | `RefactoredPaymentTransaction` | 支付交易记录 |
| `TransactionType` | `RefactoredTransactionType` | 交易类型枚举 |
| `PaymentStatus` | `RefactoredPaymentStatus` | 支付状态枚举 |

## 已修复的文件

### ✅ NewRideModels.swift
```swift
// 重命名后的类型
struct RefactoredUser: Codable, Identifiable { ... }
enum RefactoredUserRole: String, Codable { ... }
struct RefactoredPaymentTransaction: Codable, Identifiable { ... }
enum RefactoredTransactionType: String, Codable { ... }
enum RefactoredPaymentStatus: String, Codable { ... }
```

### ✅ RefactoredPassengerViewModel.swift
```swift
// 使用新的类型名
@Published var currentUser: RefactoredUser?

init(userID: String, userName: String, userPhone: String) {
    self.currentUser = RefactoredUser(
        id: userID,
        name: userName,
        phone: userPhone,
        role: .passenger,
        walletBalance: 0.0
    )
}

// Preview 已修复
static var preview: RefactoredPassengerViewModel {
    RefactoredPassengerViewModel(
        userID: "passenger_preview",
        userName: "测试乘客",
        userPhone: "+853 6666 6666"
    )
}
```

### ✅ WalletView.swift
```swift
// 使用新的类型名
@State private var transactions: [RefactoredPaymentTransaction] = []

struct TransactionRowView: View {
    let transaction: RefactoredPaymentTransaction
    // ...
}
```

### ✅ PassengerTripCreationView.swift
```swift
// 初始化参数已统一
PassengerTripCreationView(
    userID: "user_123",
    userName: "张三",
    userPhone: "+853 6666 6666"
)
```

## 如何使用

### 1. 创建乘客 ViewModel
```swift
let viewModel = RefactoredPassengerViewModel(
    userID: "user_123",
    userName: "张三",
    userPhone: "+853 6666 6666"
)
```

### 2. 创建用户对象
```swift
let user = RefactoredUser(
    id: "user_123",
    name: "张三",
    phone: "+853 6666 6666",
    role: .passenger,
    walletBalance: 500.0
)
```

### 3. 创建交易记录
```swift
let transaction = RefactoredPaymentTransaction(
    userID: "user_123",
    tripID: tripID,
    amount: 80.0,
    type: .payment,
    status: .completed
)
```

## 保留的旧类型

以下类型保持不变，可以继续使用：

- ✅ `TripRequest` - 行程请求模型
- ✅ `TripStatus` - 行程状态枚举
- ✅ `Coordinate` - 坐标模型
- ✅ `TripSearchFilter` - 搜索筛选条件
- ✅ `NetworkError` - 网络错误枚举
- ✅ `ErrorAlert` - 错误提示模型

## 完整示例

### 发布行程
```swift
let viewModel = RefactoredPassengerViewModel(
    userID: "user_123",
    userName: "张三",
    userPhone: "+853 6666 6666"
)

await viewModel.publishTrip(
    startLocation: "澳门科技大学",
    startCoordinate: Coordinate(latitude: 22.2015, longitude: 113.5495),
    endLocation: "澳门机场",
    endCoordinate: Coordinate(latitude: 22.1560, longitude: 113.5920),
    departureTime: Date().addingTimeInterval(3600),
    numberOfPassengers: 2,
    pricePerPerson: 40.0,
    notes: "有2个人"
)
```

### 支付行程
```swift
// 确保用户有足够余额
guard let user = viewModel.currentUser, user.walletBalance >= trip.totalCost else {
    // 提示充值
    return
}

// 执行支付
await viewModel.payForTrip(trip: trip)
```

### 钱包充值
```swift
await viewModel.topUpWallet(amount: 100.0)
```

## 注意事项

1. **类型一致性**：确保在整个项目中使用相同的类型名称
2. **避免混用**：不要混用 `User` 和 `RefactoredUser`
3. **Preview 支持**：所有 SwiftUI Preview 都已更新为使用正确的类型

## 测试清单

- [x] RefactoredPassengerViewModel 初始化正常
- [x] RefactoredUser 创建和使用正常
- [x] RefactoredPaymentTransaction 创建正常
- [x] Preview 可以正常显示
- [x] 没有类型歧义错误
- [x] 没有缺少成员错误

## 如果仍有编译错误

1. **清理项目**
   ```
   Product → Clean Build Folder (Shift + Cmd + K)
   ```

2. **删除 Derived Data**
   ```
   ~/Library/Developer/Xcode/DerivedData
   ```

3. **重新构建**
   ```
   Product → Build (Cmd + B)
   ```

4. **检查是否有重复文件**
   - 删除 `RefactoredPassengerViewModel 2.swift`（如果存在）
   - 删除任何其他带数字后缀的重复文件

## 相关文档

- `REFACTORING_SUMMARY.md` - 完整重构总结
- `INTEGRATION_GUIDE.md` - 集成指南
- `FIREBASE_SYNC_SOLUTION.md` - Firebase 同步方案

---

**问题解决！** 现在所有类型都有明确的命名，不会产生歧义。
