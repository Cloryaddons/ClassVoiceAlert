# ClassVoiceAlert

ClassVoiceAlert 是一个面向《魔兽世界》职业机制的模块化语音提醒框架。

当前版本包含死亡骑士的 `BoneShieldVoiceAlert` 与 `DnDVoiceAlert`，并通过共享 Core 统一管理声音来源、TTS、提醒时间和模块设置。

## 功能

- 统一设置入口：`/cvat`
- 也可通过 `ESC -> Options -> AddOns -> ClassVoiceAlert Toolbox` 打开
- 原生 AddOn 套件分组：

```text
ClassVoiceAlert Toolbox
    ClassVoiceAlert Core
    BoneShieldVoiceAlert
    DnDVoiceAlert
```

- 支持 Blizzard SoundKit
- 支持 LibSharedMedia
- 支持 WoW TTS
- 支持兼容的自定义语音包
- 提醒时间支持滑杆和手动数字输入
- 所有标准提醒统一使用整数秒，并自动限制在有效范围内
- 模块关闭后，其下属设置会自动锁定，避免误操作
- Core 统一处理输入框焦点，避免设置界面关闭后影响 `ESC`、`C` 等游戏按键

## 当前模块

### BoneShieldVoiceAlert

白骨之盾即将结束时进行语音提醒。

- 可启用或关闭提醒
- 提醒时间范围：`0-30` 秒
- 可选择不同声音来源
- 支持自定义 TTS 文本
- 可在设置界面直接测试声音

### DnDVoiceAlert

监控死亡骑士的凋零地板与粘滞效果，并根据实际状态提供两类提醒：

- **回地板提醒**：地板仍存在，但粘滞效果即将结束时提醒返回凋零地板
- **补凋零提醒**：地板已经消失，但粘滞效果即将结束时提醒重新施放凋零

两个提醒均可独立启用、配置声音和提醒时间。

## 安装

从 GitHub [Releases](https://github.com/Cloryaddons/ClassVoiceAlert/releases) 下载：

```text
ClassVoiceAlertSuite-x.y.z.zip
```

将 ZIP 中的四个 AddOn 文件夹解压到：

```text
World of Warcraft/_retail_/Interface/AddOns/
```

正确的目录结构应为：

```text
Interface/AddOns/
    ClassVoiceAlertToolbox/
    ClassVoiceAlertToolbox_Core/
    ClassVoiceAlertToolbox_Module_BoneShield/
    ClassVoiceAlertToolbox_Module_DnD/
```

不要把 GitHub 仓库中的 `addons/` 目录本身直接复制到 `Interface/AddOns/`。

## 使用

进入游戏后输入：

```text
/cvat
```

也可以通过：

```text
ESC -> Options -> AddOns -> ClassVoiceAlert Toolbox
```

打开设置界面。

所有功能模块统一由工具箱管理，不提供额外的 Slash Command。

## 下载

推荐始终从 GitHub Releases 下载正式安装包：

[Latest Releases](https://github.com/Cloryaddons/ClassVoiceAlert/releases)

GitHub 仓库中的源码目录主要用于开发，不建议普通用户直接复制源码目录安装。

## 问题反馈与功能建议

如果遇到 Bug，建议在 GitHub Issues 中提供：

- WoW 版本
- ClassVoiceAlert 版本
- 受影响的模块
- 可复现步骤
- Lua 报错信息（如有）
- 是否在关闭无关 AddOn 后仍能复现

功能建议也可以直接通过 GitHub Issues 提交。

[Open an Issue](https://github.com/Cloryaddons/ClassVoiceAlert/issues)

## 开发文档

如果你希望了解框架结构、Core API 或开发新的职业提醒模块，请参阅：

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/API.md`](docs/API.md)
- [`docs/MODULE_DEVELOPMENT.md`](docs/MODULE_DEVELOPMENT.md)
- [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Author

**Clory**

## 许可证

本项目采用 **PolyForm Noncommercial License 1.0.0**。

你可以在非商业用途下使用、修改和分享本项目；商业用途需要单独获得作者许可。

完整条款请参阅 [`LICENSE.md`](docs/LICENSE.md)。
