# Role C 对接说明（OCR / 本地通知 / 图表 / 本地存储）

本文档面向 **角色 A（前端）** 与 **角色 B（Firebase）**，说明当前仓库中角色 C 的实现位置、接口约定、真机测试步骤及已知限制。下次迭代计划见文末。

## 1. 架构与入口

| 能力 | Dart 接口 | 实现类 | 注入位置 |
|------|------------|--------|----------|
| OCR | `OcrPort` | `MlKitOcrPort` | `lib/main.dart` → `CareStore` |
| 本地通知 | `NotificationPort` | `LocalNotificationPort` | `lib/main.dart` → `CareStore` |
| 症状照片路径 | `StoragePort` | `LocalStoragePort` | `lib/main.dart`（占位，等 B 换云端） |
| OCR 释放 | `DisposableIntegration` | `MlKitOcrPort` | `CareStore.dispose()` |

UI 不直接依赖插件，只调用 `CareStore` 与 `OcrReviewScreen` 等。

## 2. OCR（ML Kit）

- **文件**：`lib/features/care/integrations/mlkit_ocr_port.dart`
- **脚本**：仅 **`TextRecognitionScript.latin`**。在无 Google Play 服务的华为等设备上，**不得**在未添加对应原生依赖的情况下启用 `chinese` 脚本（会触发 `ChineseTextRecognizerOptions` 类缺失崩溃）。
- **流程**：`InputImage.fromFilePath` → 按 block/line 归一化空白 → 关键词 + 简单英文时间解析 → `List<OcrCandidate>`（**不自动建任务**）。
- **复核页**：`lib/features/care/presentation/screens.dart` → `OcrReviewScreen`（Camera / Gallery、`rootNavigator` 打开）。
- **候选卡**：可编辑原文、下拉修正 **Detected type**（Medication / Appointment / Instruction / Other）。
- **落库**：`CareStore.createTasksFromOcr` → `DemoCareRepository.createTasksFromOcrCandidates`（当前仍为本地 demo；B 接 Firebase 后替换 Repository 即可）。

**任务标题与分配人（demo 层）**：`lib/features/care/data/demo_care_repository.dart` 中根据候选类型与文本生成标题，并优先将任务分配给该患者的 **primaryCarer**，否则 patient / 首位成员，最后 `Unassigned`。列表中 “Anyone” 表示 **未指定执行人**，不是全员任务。

## 3. 本地通知（flutter_local_notifications）

- **文件**：`lib/features/care/integrations/local_notification_port.dart`
- **初始化**：`main.dart` 在 `runApp` 前 `await notificationPort.initialize()`。
- **权限**：`requestPermission()` 内请求通知权限与精确闹钟（Android 实现类上调用）。
- **调度**：`zonedSchedule`，UTC 映射避免部分机型时区名无法解析；`exactAllowWhileIdle` 失败时降级 `inexactAllowWhileIdle`。调试日志前缀：`CareBridge notifications:`。
- **业务绑定**：`CareStore` 在 `load`、`selectPatient`、`saveTask`、`deleteTask`、`markTaskStatus`、`setNotificationsEnabled`、`createTasksFromOcr` 等处 schedule / cancel / reschedule。

**Manifest（必须）**：`android/app/src/main/AndroidManifest.xml` 已注册 `ScheduledNotificationReceiver`、`ScheduledNotificationBootReceiver`、`ActionBroadcastReceiver` 及 `RECEIVE_BOOT_COMPLETED`，否则会出现「即时通知有、定时通知无」。

**设置页自检**：`SettingsScreen` 内提供「即时测试通知」与「约 5 秒后测试」列表项，用于与业务任务提醒区分排查。

## 4. 图表（fl_chart）

- **文件**：`lib/features/care/presentation/screens.dart` → `MiniTrendChart`
- **数据**：`CareStore.lastSevenLogs`（疼痛 + 体温双曲线示意，右轴刻度为换算后的温度标签）。

## 5. 角色 B 对接要点

1. 保持 `CareRepository` 与 `integration_ports.dart` 中抽象方法签名不变。
2. 替换 `main.dart` 中 `DemoCareRepository` 为 `FirebaseCareRepository`（或等价实现）。
3. `StoragePort.uploadSymptomPhoto` / `uploadDischargeImage` 返回云端 URL 后，`SymptomLog.photoUrls` 与任务来源字段可存 URL；当前 `LocalStoragePort` 仅校验本地文件并返回路径字符串。

## 6. 真机测试步骤（建议顺序）

1. `flutter pub get` → `flutter run -d <device>`（修改 Manifest 后建议 `flutter clean` 后全量安装一次）。
2. **通知**：设置页 → 即时测试 → 应立刻出现；再测 5 秒延迟（可切后台）。
3. **OCR**：首页 `Scan doc` → Gallery 或 Camera → 勾选行 → `Create tasks` → 任务列表检查标题、类型图标、分配人。
4. **图表**：底部 `Log` → 查看近 7 天趋势区。

## 7. 本迭代变更摘要（代码层面）

- 新增并实现：`mlkit_ocr_port.dart`、`local_notification_port.dart`、`local_storage_port.dart`；`main.dart` 注入；`CareStore` 扩展 OCR/通知/照片路径逻辑。
- UI：`OcrReviewScreen` 布局与导航修复；`MiniTrendChart` 使用 `fl_chart`；设置页通知自检。
- Android：`AndroidManifest.xml` 权限与 scheduled notification receivers；`build.gradle.kts` 启用 core library desugaring（配合 `flutter_local_notifications` / timezone）。
- 依赖：`pubspec.yaml` 中 ML Kit、本地通知、timezone、fl_chart、image_picker、uuid 等（已移除易引发崩溃场景的 `flutter_timezone` 与中文 OCR 脚本依赖）。
- 清理：删除未使用的 `SymptomTrendPoint`；移除 Finder 产生的重复 `.flutter-plugins-dependencies *` 文件并在 `.gitignore` 中忽略同名副本。

## 8. 已知限制与下迭代 Backlog

- OCR 准确率：当前为英文拉丁脚本 + 规则解析；手写/模糊图仍依赖用户复核。下迭代：可调置信度排序、复核页「建议标题」可编辑输入框、更多英文关键词与日期格式。
- 多语言 OCR：若需中文识别，须在 Android 侧引入 ML Kit 中文 text 对应依赖后再启用脚本，并做好无模块时的降级。
- 通知：部分厂商仍可能限制后台闹钟，需用户在系统设置中允许「自启动 / 后台活动 / 忽略电池优化」。

---

维护分支：由角色 C 在远程创建 **`zhanmohan`** 分支推送本迭代合并内容；主分支合并策略由组内统一。
