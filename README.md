# ClassVoiceAlert

一个面向《魔兽世界》职业机制的模块化语音提醒框架。当前包含死亡骑士的**白骨之盾提醒**与**凋零地板提醒**，并通过共享 Core 统一管理设置、声音来源、TTS、LSM 和模块 UI。

**当前公开基线版本：`0.1.0`**  
**Author / Maintainer: Clory**  
**WoW Interface：`120100`**

## 功能

- 一个统一入口：`/cvat`
- `Options -> AddOns -> ClassVoiceAlert Toolbox` 可打开设置入口
- 原生 AddOn 套件层级：

```text
ClassVoiceAlert Toolbox
    ClassVoiceAlert Core
    BoneShieldVoiceAlert
    DnDVoiceAlert
```

- 共享声音后端：Blizzard SoundKit、LibSharedMedia、兼容自定义语音提供者、WoW TTS
- 标准化提醒 UI：模块开关、子提醒开关、提醒时间、声音来源、TTS 文本、测试
- 提醒时间支持滑杆与手动数字输入，统一整数化、向上取整与上下限约束
- Core 统一处理 EditBox 焦点，避免配置界面隐藏后继续吞掉 `ESC`、`C` 等游戏按键

## 当前模块

| AddOn | 作用 |
|---|---|
| `ClassVoiceAlertToolbox` | Suite Root；插件列表父节点、Blizzard Settings 入口、唯一 `/cvat` 命令 |
| `ClassVoiceAlertToolbox_Core` | 公共 Core；DB、Registry、UI、LSM、TTS、声音播放 |
| `ClassVoiceAlertToolbox_Module_BoneShield` | 白骨之盾即将结束提醒 |
| `ClassVoiceAlertToolbox_Module_DnD` | 凋零地板 / 粘滞凋零状态提醒 |

## 安装

下载 GitHub Release 中的：

```text
ClassVoiceAlertSuite-x.y.z.zip
```

将 ZIP 中四个 AddOn 文件夹解压到：

```text
World of Warcraft/_retail_/Interface/AddOns/
```

最终应为：

```text
Interface/AddOns/
    ClassVoiceAlertToolbox/
    ClassVoiceAlertToolbox_Core/
    ClassVoiceAlertToolbox_Module_BoneShield/
    ClassVoiceAlertToolbox_Module_DnD/
```

不要把仓库中的 `addons/` 目录本身复制进 `Interface/AddOns/`。

## 使用

进入游戏后：

```text
/cvat
```

也可以使用：

```text
ESC -> Options -> AddOns -> ClassVoiceAlert Toolbox
```

只有 Root 注册 Slash Command；功能模块不注册独立命令。

## 仓库结构

```text
ClassVoiceAlert/
├── addons/                  # 实际 WoW AddOn 源码
├── docs/                    # API、架构与开发规范
├── scripts/                 # 版本、验证与打包脚本
├── .github/
│   ├── workflows/           # CI / Release
│   └── ISSUE_TEMPLATE/      # Bug / Feature 模板
├── VERSION                  # 唯一 Suite 版本源
├── CHANGELOG.md
└── README.md
```

## 开发原则

最重要的边界是：

> **Core 负责“怎么播、怎么存、怎么显示”；Module 负责“什么时候播”。**

功能模块不得复制 LSM、TTS、声音浏览器、全局音频设置或公共 UI 逻辑。详细约束见：

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/API.md`](docs/API.md)
- [`docs/MODULE_DEVELOPMENT.md`](docs/MODULE_DEVELOPMENT.md)

## 本地验证与打包

验证仓库：

```bash
python scripts/validate.py
```

生成安装 ZIP：

```bash
python scripts/package.py
```

输出：

```text
dist/ClassVoiceAlertSuite-0.1.0.zip
```

## 发布新版本

版本以根目录 `VERSION` 为唯一来源。发布例如 `0.1.1`：

```bash
python scripts/set_version.py 0.1.1
python scripts/validate.py
git add .
git commit -m "Release 0.1.1"
git push origin main
git tag v0.1.1
git push origin v0.1.1
```

推送符合 `vX.Y.Z` 的 tag 后，GitHub Actions 会验证源码、生成安装 ZIP，并自动创建 GitHub Release。

## 版本规则

- Suite、Root、Core 和当前官方模块统一使用仓库版本，例如 `0.1.0`。
- `CVA.API_VERSION` 是独立的运行时兼容版本，目前为 `1`；只有发生破坏性 Core API 变更时才提升。
- 不使用旧开发阶段的 `0.3.x / 1.9.x` 版本号；GitHub 公开维护从 `0.1.0` 开始。

## License

当前仓库**不预设开源许可证**。如果仓库公开，在你主动添加许可证前，默认版权规则仍适用。准备允许他人修改、再发布或贡献前，请先选择合适的许可证；参见 [`docs/LICENSING.md`](docs/LICENSING.md)。


## Public AddOn metadata

- Author: `Clory`
- Blizzard AddOns-list titles are English: `ClassVoiceAlert Toolbox`, `ClassVoiceAlert Core`, `BoneShieldVoiceAlert`, and `DnDVoiceAlert`.
- The custom toolbox UI may remain Chinese for player-facing configuration.
