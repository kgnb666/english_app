# 英语教练（AI English Coach）— Flutter 前端

AI 英语学习助手 App 前端，基于 Flutter 3.38+、Provider、GoRouter、Dio。

## 运行

```bash
flutter pub get
flutter run
```

## API 服务器地址配置

App 不再在代码中硬编码服务器 IP，地址按以下优先级解析：

1. **编译期 `--dart-define`**（优先级最高）
   - `--dart-define=API_BASE_URL=http://192.168.x.x:8002/api/v1`：直接覆盖地址
   - `--dart-define=API_ENV=dev|test|prod`：选择环境配置
2. **App 内“服务器设置”**（个人中心 -> 服务器设置）
   - 用户可输入地址并测试连接，保存后持久化到本机，优先级高于配置文件
3. **配置文件** `assets/config/app_config.json`
   - 每个环境一个 `apiBaseUrl`，修改该文件即可更换服务器地址
4. 本地兜底 `http://localhost:8002/api/v1`（仅用于未配置时的回退）

示例：

```bash
# 使用测试环境配置
flutter run --dart-define=API_ENV=test

# 直接指定服务器（例如真机调试时指向电脑局域网 IP）
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8002/api/v1
```

> 说明：`assets/config/app_config.json` 中 dev/test 的默认地址沿用项目原有局域网地址，
> 是为了保证现有设备上的接口调用不受影响；发布时请改为实际部署地址。

## 学习提醒

- 入口：个人中心 -> 学习提醒（首页铃铛也可进入）
- 支持开关与每日提醒时间（默认 20:00）
- 基于 `flutter_local_notifications` 本地定时通知，点击通知跳转单词学习页
- Android 13+ 首次开启会请求通知权限；已声明 `POST_NOTIFICATIONS`、
  `SCHEDULE_EXACT_ALARM`、`RECEIVE_BOOT_COMPLETED` 等权限

## 数据备份

- 入口：个人中心 -> 数据备份
- 一键导出学习数据（单词记录、聊天记录、阅读记录、作文记录、每日统计）
- 导出文件保存在应用文档目录 `backups/` 下，可查看导出状态
- 点击备份文件可恢复数据到当前账号

## 测试

```bash
flutter analyze
flutter test
```
