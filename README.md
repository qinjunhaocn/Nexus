# Nexus

A Material Design 3 aggregation toolbox for **Android** and **Windows**. The current release establishes an adaptive, feature-empty application shell ready for future tools.

## Highlights

- Material Design 3 UI with responsive desktop and mobile navigation.
- Android 12+ dynamic colors with a stable Material 3 fallback palette.
- Automatic light/dark mode controlled by the operating system.
- Android application ID: `com.voxyn.nexus`.
- 玩机空间提供 Android Root 状态检查、设备相关的 LSPosed 启动器，以及只读的原始分区镜像导出。

## Development

This project is generated and maintained with Flutter **3.44.6**.

```powershell
flutter pub get
flutter analyze
flutter test
```

Run against an attached Android device/emulator or Windows desktop target:

```powershell
flutter run
```

## Root tools and data safety

玩机空间中的 Root 工具只支持 Android；Windows 仅显示不可用状态。Root 授权、secret-code 广播以及分区布局会因设备、Android 版本和 OEM 固件而不同，LSPosed 启动入口无法保证所有设备可用。

分区管理器会从 `/dev/block/by-name` 增量发现可识别条目：先发现的分区会立即出现在可搜索列表中，避免等待完整扫描。导出时，系统文件选择器会默认使用原始分区名（例如 `boot.img`）。它只提供**导出**：创建的原始镜像可能包含个人数据、设备标识或其他敏感内容，请仅保存到可信位置。Nexus 不提供向真实设备分区写入镜像的功能；十秒阅读提示无法消除镜像兼容性、动态分区、加密或部分写入导致的永久损坏风险。

## CI

GitHub Actions validates formatting-relevant static analysis and tests, builds a debug Android APK, and uploads it as the `nexus-debug-apk` workflow artifact. Trigger it with a push, pull request, or the **Run workflow** button in GitHub Actions.
