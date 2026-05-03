# One2All

跨平台设备互联应用 —— 实现手机、电脑、Linux 多端消息互通与剪贴板同步。

## 功能特性

- **P2P 消息收发** — 通过 WebRTC DataChannel 设备间直连通信
- **剪贴板同步** — 跨设备自动同步剪贴板内容
- **设备配对** — 6 位配对码快速连接
- **自动重连** — 网络断开后自动恢复连接
- **消息历史** — 本地持久化存储聊天记录

## 技术栈

| 组件 | 技术 |
|---|---|
| 客户端 | Flutter + Dart |
| 信令服务器 | Dart + shelf + shelf_web_socket |
| P2P 通信 | WebRTC (flutter_webrtc) |
| 状态管理 | Provider |
| 本地存储 | SharedPreferences |

## 架构

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
              │ (Dart)        │
              └───────────────┘
```

## 快速开始

### 1. 启动信令服务器

```bash
cd server
dart pub get
dart run bin/server.dart
# 默认监听 ws://0.0.0.0:8080
```

### 2. 运行客户端

```bash
flutter pub get

# Windows 桌面端
flutter run -d windows

# Android 手机
flutter run -d <device-id>

# 构建 APK
flutter build apk --debug
```

### 3. 连接配置

客户端默认连接 `ws://192.168.249.155:8080`（可在设置页面修改）。

确保手机和电脑在同一局域网，且电脑防火墙允许 8080 端口。

## 项目结构

```
One2All/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── models/
│   │   ├── device.dart              # 设备模型
│   │   ├── message.dart             # 消息模型
│   │   └── signal_message.dart      # 信令消息模型
│   ├── services/
│   │   ├── signaling_service.dart   # WebSocket 信令客户端
│   │   ├── webrtc_service.dart      # WebRTC P2P 连接管理
│   │   ├── message_service.dart     # 消息收发服务
│   │   └── clipboard_service.dart   # 剪贴板同步
│   ├── screens/
│   │   ├── home_screen.dart         # 设备列表主页
│   │   ├── chat_screen.dart         # 聊天界面
│   │   ├── pairing_screen.dart      # 设备配对
│   │   └── settings_screen.dart     # 设置页面
│   └── widgets/
│       ├── device_card.dart         # 设备卡片
│       ├── message_bubble.dart      # 消息气泡
│       └── connection_status.dart   # 连接状态指示
├── server/
│   ├── pubspec.yaml
│   └── bin/server.dart              # 信令服务器
├── android/                         # Android 平台配置
├── windows/                         # Windows 平台配置
├── pubspec.yaml
└── CLAUDE.md
```

## 平台支持

| 平台 | 状态 |
|---|---|
| Windows | 已测试 |
| Android | 已测试 |
| Linux | 未测试 |
| macOS | 未测试 |
| iOS | 未测试 |

## 依赖版本

- Flutter 3.41.8 / Dart 3.11.5
- flutter_webrtc: ^0.14.0
- file_picker: ^8.0.0
- provider: ^6.1.0
- shared_preferences: ^2.2.0

## 已知问题

- 文件传输功能未实现（UI 已预留入口）
- 配对码到设备 ID 的映射尚未实现（当前直接使用配对码作为设备 ID）
- 单机运行多个实例会共享设备 ID（SharedPreferences 冲突）

## 开发说明

- 使用 `flutter analyze` 进行静态分析（当前 0 issues）
- 使用 `.withValues(alpha: x)` 替代已弃用的 `.withOpacity(x)`
- 信令服务器仅负责连接建立，不中转消息数据
- WebRTC 使用 Google 公共 STUN 服务器处理 NAT 穿透
