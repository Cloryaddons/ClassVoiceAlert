# GitHub 初次上传指南

## 推荐做法：先建 Private 仓库

仓库名建议：`ClassVoiceAlert`

第一次建立 GitHub 仓库时，不要让 GitHub 自动生成 README、`.gitignore` 或 LICENSE，因为本地包已经包含 README 和 `.gitignore`；自动生成会让第一次 push 多一个需要合并的历史。

## 方法 A：GitHub 网页建空仓库 + Git 命令行

1. GitHub 右上角 `+` -> `New repository`。
2. Repository name：`ClassVoiceAlert`。
3. Visibility：建议先选 `Private`。
4. **不要勾选** Add README / Add .gitignore / Choose a license。
5. 创建仓库。
6. 解压 `ClassVoiceAlert-GitHub-0.1.0.zip`。
7. 在解压后的仓库根目录打开 PowerShell / Terminal。

```bash
git init
git branch -M main
git add .
git commit -m "Initial release 0.1.0"
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/ClassVoiceAlert.git
git push -u origin main
```

8. 确认 GitHub 上文件正确后，再发布首个 tag：

```bash
git tag v0.1.0
git push origin v0.1.0
```

这会触发 `.github/workflows/release.yml`，自动生成并上传：

```text
ClassVoiceAlertSuite-0.1.0.zip
```

到 GitHub Releases。

## 方法 B：GitHub CLI

如果已经安装并登录 `gh`：

```bash
git init
git branch -M main
git add .
git commit -m "Initial release 0.1.0"
gh repo create ClassVoiceAlert --private --source=. --remote=origin --push

git tag v0.1.0
git push origin v0.1.0
```

之后需要公开时，可在 GitHub Repository Settings 中修改 visibility。

## 第一次上传后建议检查

### Actions

进入 GitHub 仓库 -> `Actions`：
- `Validate` 应成功；
- 推送 `v0.1.0` 后，`Release` 应成功。

### Releases

右侧 `Releases` 应出现 `v0.1.0`，并附带：

```text
ClassVoiceAlertSuite-0.1.0.zip
```

下载 ZIP 检查，其顶层必须直接是四个 AddOn 文件夹，而不是 `addons/`。

### Issues

仓库已经包含 Bug Report 与 Feature Request 模板。以后新需求/故障尽量先建 Issue，再让 AI/人工修改代码；这样需求和代码历史都留在 GitHub，不依赖聊天上下文。

## 日常修改流程

小项目可以保持简单 GitHub Flow：

```bash
git switch -c fix/some-bug
# 修改、测试
python scripts/validate.py
git add .
git commit -m "Fix: ..."
git push -u origin fix/some-bug
```

在 GitHub 建 Pull Request 合并到 `main`。

如果只是自己快速维护，也可以直接在 `main` 修改，但涉及 Core/架构改动时建议使用分支。

## 发布后续版本

例如 `0.1.1`：

```bash
python scripts/set_version.py 0.1.1
python scripts/validate.py
python scripts/package.py
```

先在本地 WoW 测试 `dist/ClassVoiceAlertSuite-0.1.1.zip`。确认后：

```bash
git add .
git commit -m "Release 0.1.1"
git push origin main
git tag v0.1.1
git push origin v0.1.1
```

**先 push main，再 push tag。**

## License

当前仓库没有自动替你选择许可证。建议第一次先建 Private 仓库。准备公开并允许他人修改/再发布时，再决定 MIT、GPL-3.0 或其他许可证，并在仓库根目录加入 `LICENSE`。
