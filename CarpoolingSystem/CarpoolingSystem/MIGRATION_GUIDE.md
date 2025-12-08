# 📋 从旧系统迁移到新系统指南

## 🔄 迁移概览

本指南帮助您将现有代码从**旧的司机发布模式**迁移到**新的乘客发布+司机接单模式**。

---

## 📊 架构变更对比

### 旧架构 → 新架构

| 组件 | 旧系统 | 新系统 | 操作 |
|------|--------|--------|------|
| 数据模型 | `AdvancedRide` | `TripRequest` | ✅ 替换 |
| 用户模型 | `User` | `AppUser` | ✅ 重命名避免冲突 |
| 乘客 ViewModel | `PassengerViewModel` | `RefactoredPassengerViewModel` | ✅ 使用新的 |
| 司机 ViewModel | `DriverViewModel` | `DriverViewModel`（已重构） | ✅ 使用新版本 |
| 数据源 | `RideDataStore`（本地） | `FirebaseTripService`（云端） | ✅ 替换 |
| 发布权限 | 司机发布行程 | 乘客发布请求 | ⚠️ **逻辑反转** |

---

## 🔧 Step-by-Step 迁移步骤

### Step 1: 添加新文件到项目

将以下文件添加到您的 Xcode 项目：

```
✅ 必须添加：
├── NewRideModels.swift
├── NetworkError.swift
├── RefactoredPassengerViewModel.swift
├── DriverViewModel.swift（新版本）
├── TripCreationView.swift
├── WalletView.swift
├── PassengerMainView.swift
└── DriverCarpoolHallView.swift

📄 参考文档：
├── FIREBASE_SYNC_SOLUTION.md
├── REFACTOR_SUMMARY.md
└── QUICK_START.md
```

### Step 2: 重命名冲突的类型

#### 2.1 查找并替换 `User` 引用

```bash
# 在 Xcode 中：
# 1. Edit → Find → Find in Workspace
# 2. 搜索：": User" 或 "var user: User"
# 3. 手动检查每个结果，确定是否需要替换为 AppUser
```

**示例：**

```swift
// ❌ 旧代码（可能冲突）
struct Profile {
    let user: User  // 如果项目中有多个 User 定义
}

// ✅ 新代码
struct Profile {
    let user: AppUser  // 使用明确的类型名
}
```

#### 2.2 处理 `UserRole` 冲突

如果您的项目中已有 `UserRole` 枚举：

```swift
// 查看 UserModels.swift
// 它定义了 AppUserRole 和 typealias UserRole = AppUserRole

// ✅ 推荐：使用 AppUserRole
var role: AppUserRole = .passenger

// ⚠️ 也可以：使用 typealias（可能冲突）
var role: UserRole = .passenger
```

### Step 3: 更新 View 层

#### 3.1 替换乘客端 View

**旧代码：**
```swift
struct ContentView: View {
    @StateObject private var dataStore = RideDataStore()
    @StateObject private var viewModel: PassengerViewModel
    
    var body: some View {
        List(dataStore.rides) { ride in
            // 显示司机发布的行程
            Text(ride.startLocation)
        }
    }
}
```

**新代码：**
```swift
struct ContentView: View {
    var body: some View {
        // ✅ 直接使用新的主界面
        PassengerMainView(
            passengerID: "user_123",
            passengerName: "张三",
            passengerPhone: "+853 6666 6666"
        )
    }
}
```

#### 3.2 替换司机端 View

**新代码：**
```swift
struct DriverView: View {
    var body: some View {
        DriverCarpoolHallView(
            driverID: "driver_123",
            driverName: "李师傅",
            driverPhone: "+853 8888 8888"
        )
    }
}
```

### Step 4: 迁移数据访问逻辑

#### 4.1 从 RideDataStore 迁移到 Firebase

**旧代码：**
```swift
class SomeViewModel: ObservableObject {
    let dataStore = RideDataStore()  // ❌ 本地数据
    
    func loadRides() {
        let rides = dataStore.rides  // 只能看到本地数据
    }
}
```

**新代码：**
```swift
class SomeViewModel: ObservableObject {
    let tripService = TripRealtimeService(userID: currentUserID)  // ✅ 实时服务
    
    func loadRides() {
        tripService.startListeningToAvailableTrips()  // 实时监听
    }
}
```

#### 4.2 数据模型转换

如果您需要保留旧数据，可以编写转换函数：

```swift
extension TripRequest {
    /// 从旧的 AdvancedRide 转换为新的 TripRequest
    init?(from oldRide: AdvancedRide) {
        // 只转换学生求车（现在由乘客发布）
        guard oldRide.rideType.isStudentRequest else {
            return nil
        }
        
        self.init(
            id: oldRide.id,
            passengerID: oldRide.publisherID,
            passengerName: oldRide.publisherName,
            passengerPhone: oldRide.publisherPhone,
            startLocation: oldRide.startLocation,
            startCoordinate: Coordinate(
                latitude: oldRide.driverCurrentLocation?.latitude ?? 0,
                longitude: oldRide.driverCurrentLocation?.longitude ?? 0
            ),
            endLocation: oldRide.endLocation,
            endCoordinate: Coordinate(
                latitude: oldRide.destinationLocation?.latitude ?? 0,
                longitude: oldRide.destinationLocation?.longitude ?? 0
            ),
            departureTime: oldRide.departureTime,
            numberOfPassengers: oldRide.totalCapacity,
            pricePerPerson: oldRide.unitPrice,
            status: mapStatus(oldRide.status)
        )
    }
    
    private static func mapStatus(_ oldStatus: RideStatus) -> TripStatus {
        switch oldStatus {
        case .pending:
            return .pending
        case .accepted:
            return .accepted
        case .enRoute:
            return .inProgress
        case .completed:
            return .completed
        }
    }
}
```

### Step 5: 更新业务逻辑

#### 5.1 发布行程逻辑变更

**关键变更：发布权限反转**

```swift
// ❌ 旧逻辑：司机发布行程
class DriverViewModel {
    func publishRide() {
        let ride = AdvancedRide(
            rideType: .driverOffer(totalFare: 120),
            publisherID: driverID,
            // ...
        )
        dataStore.addRide(ride)
    }
}

// ✅ 新逻辑：乘客发布请求
class RefactoredPassengerViewModel {
    func publishTrip() async {
        let trip = TripRequest(
            passengerID: currentPassengerID,
            passengerName: currentPassengerName,
            // ...
            numberOfPassengers: 2,
            pricePerPerson: 40.0
        )
        try await tripService.publishTrip(trip)
    }
}
```

#### 5.2 接单逻辑变更

```swift
// ❌ 旧逻辑：司机接受学生求车
func acceptRequest(ride: AdvancedRide, driverID: String) {
    var updatedRide = ride
    updatedRide.publisherID = driverID
    updatedRide.status = .accepted
}

// ✅ 新逻辑：司机接单乘客请求
func acceptTrip(_ trip: TripRequest) async {
    var updatedTrip = trip
    updatedTrip.driverID = currentDriverID
    updatedTrip.driverName = currentDriverName
    updatedTrip.status = .awaitingPayment  // ⚠️ 注意：直接进入待支付
    
    try await tripService.updateTrip(updatedTrip)
}
```

### Step 6: 添加支付功能

这是新系统的核心功能，旧系统没有：

```swift
// ✅ 新增：钱包服务
class WalletService {
    func addBalance(amount: Double) async throws {
        // 充值逻辑
    }
    
    func deductBalance(amount: Double) async throws {
        // 扣款逻辑
    }
}

// ✅ 新增：支付功能
func payForTrip(trip: TripRequest) async {
    // 1. 检查余额
    guard currentUser.walletBalance >= trip.totalCost else {
        errorAlert = ErrorAlert(title: "余额不足", message: "请先充值")
        return
    }
    
    // 2. 扣除余额
    try await walletService.deductBalance(amount: trip.totalCost)
    
    // 3. 更新订单状态
    var updatedTrip = trip
    updatedTrip.status = .paid
    try await tripService.updateTrip(updatedTrip)
}
```

---

## ⚠️ 重要变更清单

### 1. 逻辑反转

| 操作 | 旧系统 | 新系统 |
|------|--------|--------|
| 发布行程 | 司机 | 乘客 ✅ |
| 接单 | 司机接受学生求车 | 司机接受乘客请求 ✅ |
| 支付 | 无 | 乘客支付 ✅ |

### 2. 状态流转变更

```
旧系统：
pending → accepted → enRoute → completed

新系统：
pending → accepted → awaitingPayment → paid → inProgress → completed
                              ↑
                        ⚠️ 新增的关键状态
```

### 3. 费用计算变更

```swift
// ❌ 旧系统：司机设定总价
rideType: .driverOffer(totalFare: 120.0)

// ✅ 新系统：乘客设定单价和人数
numberOfPassengers: 2
pricePerPerson: 40.0
expectedIncome = 2 × 40 = 80.0  // 自动计算
```

---

## 🧪 迁移测试清单

### 测试 1: 基本功能

- [ ] ✅ 乘客能够发布行程
- [ ] ✅ 司机能够看到发布的行程
- [ ] ✅ 司机能够接单
- [ ] ✅ 乘客能够看到接单状态
- [ ] ✅ 乘客能够支付
- [ ] ✅ 状态正确流转

### 测试 2: 数据同步

- [ ] ✅ 两个模拟器能够实时同步
- [ ] ✅ 发布行程后 < 1 秒显示
- [ ] ✅ 接单后立即通知乘客
- [ ] ✅ 支付后立即更新状态

### 测试 3: 错误处理

- [ ] ✅ 余额不足时提示充值
- [ ] ✅ 网络错误时显示友好提示
- [ ] ✅ 重复接单时正确处理
- [ ] ✅ 取消行程正确处理

---

## 🔍 常见问题

### Q1: 旧数据怎么办？

**A:** 您有几个选择：

1. **清空重新开始**（推荐用于开发阶段）
   ```swift
   // 删除 Firestore collection
   // 清除本地缓存
   ```

2. **数据迁移**
   ```swift
   func migrateOldData() async {
       let oldRides = loadOldRides()
       
       for oldRide in oldRides {
           if let newTrip = TripRequest(from: oldRide) {
               try await tripService.publishTrip(newTrip)
           }
       }
   }
   ```

3. **并行运行**（暂时保留两套系统）
   ```swift
   // 使用不同的 Firestore collection
   let oldCollection = "rides"      // 旧系统
   let newCollection = "tripRequests"  // 新系统
   ```

### Q2: 如何处理已有的司机用户？

**A:** 司机用户不需要重新注册，只需要：

```swift
// 更新用户角色
var user = currentUser
user.role = .driver  // 或 .both（既是司机也是乘客）

// 司机端改为浏览和接单
// 不再发布行程
```

### Q3: 旧的推送通知还能用吗？

**A:** 可以，但需要调整通知内容：

```swift
// ❌ 旧通知
sendNewRequestNotification(to: driverID, ...)  // 司机发车，乘客请求

// ✅ 新通知
sendNewRequestNotification(to: driverID, ...)  // 乘客发单，通知司机
sendPaymentNotification(to: driverID, ...)     // 新增：支付通知
```

---

## 📊 迁移进度跟踪

使用此清单跟踪您的迁移进度：

```
第一阶段：准备工作
├─ [ ] 备份现有代码
├─ [ ] 创建新分支（git checkout -b refactor-passenger-publish）
├─ [ ] 阅读文档（REFACTOR_SUMMARY.md）
└─ [ ] 理解新架构

第二阶段：代码迁移
├─ [ ] 添加新文件到项目
├─ [ ] 解决类型冲突
├─ [ ] 更新 View 层
├─ [ ] 迁移 ViewModel
└─ [ ] 集成 Firebase

第三阶段：测试验证
├─ [ ] 单元测试
├─ [ ] 两个模拟器测试
├─ [ ] 真机测试
└─ [ ] 性能测试

第四阶段：部署上线
├─ [ ] 用户通知（逻辑变更）
├─ [ ] 数据迁移（如需要）
├─ [ ] 灰度发布
└─ [ ] 全量上线
```

---

## 🚀 迁移后的优势

完成迁移后，您将获得：

1. ✅ **更符合业务逻辑**：乘客发单，司机接单（类似滴滴）
2. ✅ **实时同步**：Firebase Snapshot Listener，延迟 < 1 秒
3. ✅ **完整支付流程**：钱包管理、充值、支付、交易记录
4. ✅ **清晰的状态管理**：7 种状态，完整的生命周期
5. ✅ **商业级代码**：MVVM 架构、错误处理、日志完整
6. ✅ **易于扩展**：支付宝/微信支付、实时追踪、聊天功能

---

## 📞 需要帮助？

如果在迁移过程中遇到问题：

1. 查看 **FIREBASE_SYNC_SOLUTION.md** 了解同步机制
2. 查看 **REFACTOR_SUMMARY.md** 了解完整架构
3. 查看 **QUICK_START.md** 快速开始使用
4. 检查日志输出，定位问题

---

**🎉 祝您迁移顺利！享受新系统带来的强大功能！**
