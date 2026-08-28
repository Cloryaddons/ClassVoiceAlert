# Changelog

本项目从 GitHub 基线版本 `0.1.0` 开始记录公开版本历史。

## [0.1.0] - 2026-08-26

### Added
- 建立 Root / Core / Feature Module 四 AddOn 套件结构。
- 加入死亡骑士白骨之盾提醒。
- 加入死亡骑士凋零地板提醒。
- 统一声音来源、TTS、LSM、全局音频设置与模块注册。
- 统一模块与子提醒的启用/禁用 UI 层级。
- 统一 EditBox 键盘焦点安全处理。
- 提醒时间支持整数滑杆与手动输入，并执行向上取整与有效范围约束。
- 建立 GitHub 仓库结构、静态验证、自动打包与 tag Release 工作流。

## 0.1.1

### 修复

- 修复修改 TTS 文本后，关闭设置界面可能导致 `ESC`、`C` 等按键无法正常响应的问题。
- 修复拖动提醒时间滑条后，关闭设置界面可能残留键盘焦点的问题。
- 优化设置界面的输入框焦点处理，避免隐藏后的输入控件继续占用键盘输入。

### 调整

- 为 `ClassVoiceAlert Toolbox`、`ClassVoiceAlert Core`、`BoneShieldVoiceAlert` 和 `DnDVoiceAlert` 添加统一的自定义插件图标。

## 0.1.2

### 修复

- 修复通过 `ESC -> 选项 -> 插件 -> ClassVoiceAlert Toolbox` 打开工具箱后，`ESC` 键可能无法正常响应的问题。
- 调整 Blizzard 设置入口的窗口处理方式，避免干扰系统界面状态。

### 说明

- 本次更新不涉及提醒逻辑或模块机制调整。
- `/cvat` 打开工具箱的方式保持不变。
