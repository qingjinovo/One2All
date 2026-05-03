# One2All - 跨设备互联应用开发计划

## Context

用户计划开发一款跨手机、电脑、Linux 的多端互联应用，实现设备间文件、消息互传与数据互通。
- 技术栈：Flutter + Dart
- 通信方式：WebRTC P2P
- 优先级：消息互通优先，后续扩展文件传输和数据同步

## 架构设计

```
┌─────────────┐     WebRTC P2P      ┌─────────────┐
│  Device A   │◄──────────────────►│  Device B   │
│ (Flutter)   │                     │ (Flutter)   │
└──────┬──────┘                     └──────┬──────┘
       │                                    │
       │        Signaling (WebSocket)       │
       └──────────────┬─────────────────────┘
                      ▼
              ┌───────────────┐
              │ Signaling     │
              │ Server        │
              │ (Dart/shelf)  │
              └───────────────┘
```

### 核心模块

1. **信令服务器 (Signaling Server)**
   - 负责设备发现和 WebRTC 握手
   - 技术：Dart + shelf + shelf_web_socket
   - 部署：可本地运行或部署到云服务器
   - 功能：设备注册、SDP 交换、ICE 候选传递

2. **Flutter 客户端**
   - 跨平台 UI：iOS / Android / Windows / Linux / macOS
   - 核心依赖：
     - `flutter_webrtc` - WebRTC 连接
     - `web_socket_channel` - 信令通信
     - `provider` - 状态管理
     - `shared_preferences` - 本地存储
     - `file_picker` - 文件选择（后续文件传输用）

3. **消息系统**
   - 文本消息收发
   - 剪贴板同步
   - 设备通知转发（后续）

## 实施步骤

### Phase 1: 项目初始化（步骤 1-2）

**步骤 1: 创建 Flutter 项目**
- `flutter create --platforms=android,ios,windows,linux,macos one2all`
- 配置项目结构和依赖

**步骤 2: 搭建信令服务器**
- 创建 `server/` 目录
- 使用 Dart shelf + shelf_web_socket 实现 WebSocket 信令服务
- 实现设备注册、SDP 交换、ICE 候选转发

### Phase 2: WebRTC 连接层（步骤 3-5）

**步骤 3: 实现信令客户端**
- WebSocket 连接管理
- 消息序列化/反序列化
- 自动重连机制

**步骤 4: WebRTC 连接管理**
- 使用 `flutter_webrtc` 建立 P2P 连接
- DataChannel 创建和管理
- ICE/STUN 配置

**步骤 5: 设备发现与配对**
- 设备列表展示
- 配对请求/确认流程
- 设备昵称和标识管理

### Phase 3: 消息互通（步骤 6-8）

**步骤 6: 文本消息收发**
- 消息数据模型
- 通过 DataChannel 发送/接收文本
- 消息历史本地存储

**步骤 7: 剪贴板同步**
- 监听剪贴板变化
- 跨设备剪贴板内容同步
- 隐私控制选项

**步骤 8: UI 完善**
- 聊天界面
- 设备管理界面
- 设置页面

### Phase 4: 文件传输（后续扩展）

**步骤 9: 文件分块传输**
- 大文件分块通过 DataChannel 传输
- 进度显示和断点续传

**步骤 10: 数据同步**
- 联系人、日历等数据同步
- 自定义同步规则

## 目录结构

```
One2All/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── device.dart          # 设备模型
│   │   ├── message.dart         # 消息模型
│   │   └── signal_message.dart  # 信令消息模型
│   ├── services/
│   │   ├── signaling_service.dart   # 信令客户端
│   │   ├── webrtc_service.dart      # WebRTC 连接管理
│   │   ├── message_service.dart     # 消息收发服务
│   │   └── clipboard_service.dart   # 剪贴板同步
│   ├── screens/
│   │   ├── home_screen.dart         # 主页（设备列表）
│   │   ├── chat_screen.dart         # 聊天界面
│   │   ├── pairing_screen.dart      # 配对界面
│   │   └── settings_screen.dart     # 设置
│   └── widgets/
│       ├── device_card.dart         # 设备卡片组件
│       ├── message_bubble.dart      # 消息气泡
│       └── connection_status.dart   # 连接状态指示
├── server/
│   ├── pubspec.yaml
│   └── bin/
│       └── server.dart              # 信令服务器
├── pubspec.yaml
└── README.md
```

## 关键依赖

### Flutter 客户端 (pubspec.yaml)
```yaml
dependencies:
  flutter_webrtc: ^0.14.0
  web_socket_channel: ^2.4.0
  provider: ^6.1.0
  shared_preferences: ^2.2.0
  file_picker: ^8.0.0
  uuid: ^4.0.0
  json_annotation: ^4.8.0
  intl: ^0.18.0
```

### 信令服务器 (server/pubspec.yaml)
```yaml
dependencies:
  shelf: ^1.4.0
  shelf_web_socket: ^3.0.0
  uuid: ^4.0.0
  web_socket_channel: ^2.4.0
```

## 验证方式

1. **信令服务器测试**
   - 启动服务器，用 WebSocket 客户端工具测试连接
   - 验证设备注册和消息转发功能

2. **WebRTC 连接测试**
   - 在同一局域网的两台设备上运行 Flutter 应用
   - 验证 P2P 连接建立成功

3. **消息互通测试**
   - 两台设备互相发送文本消息
   - 验证消息实时到达和显示

4. **跨平台测试**
   - Windows + Android
   - Linux + iOS
   - 验证各平台功能一致性

## 注意事项

- WebRTC 需要 STUN/TURN 服务器处理 NAT 穿透，初期可用 Google 免费 STUN 服务器
- 信令服务器需要部署在公网可访问的地址（或使用内网穿透工具如 ngrok）
- Flutter WebRTC 在 Linux 上的支持可能需要额外配置
- 建议先在局域网内测试，再扩展到跨网络场景

## 当前状态

- ✅ Phase 1-3 已完成（项目初始化、WebRTC 连接层、消息互通）
- ✅ Windows 桌面端测试通过
- ✅ Android 真机测试通过
- ✅ MuMu 模拟器测试通过
- ⏳ 文件传输功能待实现
- ⏳ 数据同步功能待实现
