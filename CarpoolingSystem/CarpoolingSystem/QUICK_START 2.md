# 🚀 快速开始指南

## 立即使用新系统的 3 个步骤

### Step 1: 在您的应用入口使用新视图

#### 方案 A：直接启动乘客端（推荐用于演示）

```swift
// ContentView.swift 或 AppDelegate

import SwiftUI

@main
struct CarpoolingApp: App {
    var body: some Scene {
        WindowGroup {
            // ✅ 使用新的乘客端主界面
            PassengerMainView(
                passengerID: "passenger_001",
                passengerName: "张小明",
                passengerPhone: "+853 6611 1111"
            )
        }
    }
}
```

#### 方案 B：直接启动司机端

```swift
@main
struct CarpoolingApp: App {
    var body: some Scene {
        WindowGroup {
            // ✅ 使用新的司机端拼车大厅
            DriverCarpoolHallView(
                driverID: "driver_001",
                driverName: "李师傅",
                driverPhone: "+853 8888 8888"
            )
        }
    }
}
```

#### 方案 C：登录后选择角色

```swift
struct RoleSelectionView: View {
    @State private var selectedRole: UserRole?
    @State private var userName: String = ""
    @State private var userPhone: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择您的角色")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 用户信息输入
            TextField("姓名", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("电话", text: $userPhone)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // 角色选择
            HStack(spacing: 20) {
                // 乘客
                Button(action: {
                    selectedRole = .passenger
                }) {
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                        Text("乘客")
                            .font(.headline)
                    }
                    .frame(width: 150, height: 150)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
                }
                
                // 司机
                Button(action: {
                    selectedRole = .driver
                }) {
                    VStack {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                        Text("司机")
                            .font(.headline)
                    }
                    .frame(width: 150, height: 150)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
        .fullScreenCover(item: $selectedRole) { role in
            destinationView(for: role)
        }
    }
    
    @ViewBuilder
    private func destinationView(for role: UserRole) -> some View {
        let userID = UUID().uuidString
        
        switch role {
        case .passenger:
            PassengerMainView(
                passengerID: userID,
                passengerName: userName.isEmpty ? "测试乘客" : userName,
                passengerPhone: userPhone.isEmpty ? "+853 6666 6666" : userPhone
            )
        case .driver:
            DriverCarpoolHallView(
                driverID: userID,
                driverName: userName.isEmpty ? "测试司机" : userName,
                driverPhone: userPhone.isEmpty ? "+853 8888 8888" : userPhone
            )
        default:
            Text("未知角色")
        }
    }
}

// 扩展 UserRole 使其符合 Identifiable
extension UserRole: Identifiable {
    var id: String { rawValue }
}
```

---

### Step 2: 测试核心功能

#### 测试 1：乘客发布行程

```swift
// 1. 运行应用（选择"乘客"角色）
// 2. 进入"我的行程" Tab
// 3. 点击右上角 + 按钮
// 4. 填写表单：
//    - 起点：澳门科技大学
//    - 终点：澳门机场
//    - 时间：选择未来时间
//    - 人数：2
//    - 单价：40
// 5. 点击"确认发布"
//
// ✅ 预期结果：
//    - 显示"发布成功"
//    - 行程出现在列表中
//    - 状态显示"等待接单"
```

#### 测试 2：钱包充值

```swift
// 1. 进入"钱包" Tab
// 2. 点击"充值"按钮
// 3. 选择充值金额（例如：¥100）
// 4. 点击"确认充值"
//
// ✅ 预期结果：
//    - 显示"充值成功"
//    - 余额增加到 ¥100.00
```

#### 测试 3：司机接单（需要第二个模拟器）

```swift
// 模拟器 B：
// 1. 运行应用（选择"司机"角色）
// 2. 进入"拼车大厅"
// 3. 查看订单列表
// 4. 点击任意订单卡片
// 5. 点击"立即接单"
//
// ✅ 预期结果：
//    - 显示"接单成功"
//    - 显示"预期收入: ¥XX.XX"
//
// 模拟器 A（乘客）：
// ✅ 自动收到状态更新
//    - 行程状态变为"待支付"
//    - 显示"立即支付"按钮
```

#### 测试 4：乘客支付

```swift
// 模拟器 A（乘客）：
// 1. 进入"我的行程"
// 2. 找到状态为"待支付"的行程
// 3. 点击"立即支付"按钮
//
// ✅ 预期结果：
//    - 显示"支付成功"
//    - 余额扣除
//    - 行程状态变为"已支付"
```

---

### Step 3: 查看运行日志

#### 正常的日志输出应该是这样的：

```
🎯 RefactoredPassengerViewModel 初始化完成
📡 启动乘客端实时监听...
📡 开始监听我发布的行程: passenger_001
📡 开始监听用户信息: passenger_001
✅ 可用行程已更新: 0 条

// 用户点击"发布行程"
📝 发布行程请求...
✅ 行程已发布: 12345678-1234-1234-1234-123456789012
✅ 行程发布成功

// 司机接单（在另一个模拟器）
✅ [司机端] 接单: 12345678-1234-1234-1234-123456789012
✅ [司机端] 接单成功
📡 [乘客端] 检测到 1 个文档变更
✏️ [乘客端] 行程状态变更: 待支付
📲 本地通知: 司机已接单，请支付费用！

// 乘客支付
💳 [乘客端] 支付行程: 12345678-1234-1234-1234-123456789012
✅ 余额已扣除: -¥80.0
✅ 交易记录已保存: transaction-uuid
✅ 行程已更新: 12345678-1234-1234-1234-123456789012
✅ 支付成功
```

---

## 🎨 界面预览

### 乘客端

```
┌─────────────────────────────┐
│      我的行程    钱包    我的  │ ← Tab Bar
├─────────────────────────────┤
│  我的行程              [+]   │
│                             │
│  ┌───────────────────────┐  │
│  │ 🟠 等待接单            │  │
│  │                       │  │
│  │ 🟢 澳门科技大学        │  │
│  │ 🔴 澳门机场            │  │
│  │                       │  │
│  │ 总费用: ¥80.00        │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ 🟣 待支付   [立即支付]  │  │
│  │                       │  │
│  │ 🟢 澳门大学            │  │
│  │ 🔴 威尼斯人            │  │
│  │                       │  │
│  │ 总费用: ¥35.00        │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

### 司机端

```
┌─────────────────────────────┐
│  🚗 拼车大厅          [刷新]  │
├─────────────────────────────┤
│  🔍 搜索起点、终点...        │
│                             │
│  [筛选] [出发时间] [收入]... │
│                             │
│  ┌───────────────────────┐  │
│  │ 👤 张小明    2人       │  │
│  │           预期收入     │  │
│  │           ¥80.00 💰   │  │
│  ├───────────────────────┤  │
│  │ 🟢 澳门科技大学  1.2km │  │
│  │ 🔴 澳门机场            │  │
│  │ 🕐 12月07日 14:30      │  │
│  ├───────────────────────┤  │
│  │ 备注：有2个人，需要帮忙│  │
│  │ 搬行李    [立即接单]   │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

---

## 🔧 故障排除

### 问题 1：编译错误 - Type 'User' is ambiguous

**解决方案：**
确保使用新的类型名称：
- ✅ `AppUser`（新）
- ❌ `User`（旧，会冲突）

### 问题 2：看不到发布的行程

**原因：**
- 可能使用了本地数据源而不是 Firebase

**解决方案：**
1. 检查 ViewModel 是否启动了监听：
   ```swift
   viewModel.startListening()
   ```

2. 检查是否在 `.onAppear` 中调用：
   ```swift
   .onAppear {
       viewModel.startListening()
   }
   ```

### 问题 3：支付按钮不可点击

**原因：**
- 余额不足
- 行程状态不正确

**检查：**
```swift
// 查看余额
print("当前余额: \(viewModel.currentUser?.walletBalance ?? 0)")

// 查看行程状态
print("行程状态: \(trip.status)")
print("需要支付: \(trip.needsPayment)")
print("可以支付: \(viewModel.canPayForTrip(trip))")
```

---

## 📚 相关文档

- 📄 **REFACTOR_SUMMARY.md** - 完整重构总结
- 📄 **FIREBASE_SYNC_SOLUTION.md** - Firebase 同步方案
- 📄 **COMPLETE_FIX_SOLUTION.md** - 问题诊断报告

---

## 🎯 下一步建议

### 立即可做
1. ✅ 运行并测试基本功能
2. ✅ 查看日志输出
3. ✅ 两个模拟器测试同步

### 集成 Firebase（生产环境）
1. 安装 Firebase SDK
2. 配置 GoogleService-Info.plist
3. 替换临时服务为 FirebaseTripService

### 功能增强
1. 添加地图选点功能
2. 实现实时位置追踪
3. 集成真实支付系统

---

**🎉 现在开始使用您的新拼车系统吧！**

如有任何问题，请查看日志输出或参考相关文档。
