# Relay

> Relay is the new name for the former `codex-delegate-*` skill family.
>
> 把 agent 变成可控执行层，而不是失控自动驾驶。

如果你也有这种感觉:

- 想让 agent 干活更快
- 但又不想把 review、验证、提交权一起交出去
- 还希望不同后端能统一接入、统一路由、统一管理

那这个仓库大概率就是你要找的东西。

`Relay` 不是“让代理自己一路改到天亮”的全自动脚本，它更像一个面向 Codex 的委托平台:

- Codex 负责拆解任务、收紧边界、复核结果
- Claude / OpenCode / Antigravity 负责做一轮有约束的实现
- 最后由 Codex 决定要不要重试、验证、提交

一句话说，这是一套把“代理执行”做成可审查、可验证、可回滚、可路由流程的基础设施。

## 这个项目到底在解决什么

很多 agent 工作流的真实痛点，不是“模型不够聪明”，而是这两件事:

1. 改得很快，但 scope 很容易飘
2. 改完之后，没有稳定的 review 和 verification 闭环

`Relay` 的思路非常直接:

- 把执行交给后端
- 把判断留给 Codex
- 把路由、重试、安装、包装、共享逻辑收敛成可维护的脚本和 package

所以它更适合认真做工程的人，而不是只追求“一条命令全自动提交”的玩法。

## 适合谁

如果你属于下面这些场景，`Relay` 会很顺手:

- 你想让 Claude Code 落地实现，但不想让它直接 commit
- 你想统一接入多个 worker，而不是每个后端各玩各的
- 你希望先 `-WhatIf` 看路由结果，再决定是否真跑
- 你正在维护自己的 Codex skill / agent workflow，希望架构更清晰

如果你要的是“代理自己改、自己测、自己提交、自己收尾”，那它就不是按这个产品哲学设计的。

## 先记住这个定位

`Relay` 现在提供的是一套多后端委托能力:

- `relay-agent`
  默认推荐的统一入口，支持自动路由和显式后端选择
- `relay-claude`
  只走 Claude 的专用包
- `relay-opencode`
  只走 OpenCode 的专用包
- `relay-antigravity`
  只走 Antigravity CLI 的专用包

如果你是第一次接触，直接从 `relay-agent` 开始就对了。

## 3 分钟感受一下

### 1. 推荐入口：统一路由

```powershell
Set-Location .\packages\relay-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Review this API design and point out risks." -Backend auto -WhatIf
```

这一条最适合第一次上手，因为它会:

- 走统一入口
- 使用自动路由
- 先打印“它会选哪个 backend”
- 不真的执行后端

### 2. 明确指定 Claude

```powershell
Set-Location .\packages\relay-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Review this refactor plan in detail." -Backend claude -WhatIf
```

适合你已经知道这次就想让 Claude 来接。

### 3. 明确指定 Antigravity

```powershell
Set-Location .\packages\relay-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Use agy for this bounded coding task." -Backend antigravity -WhatIf
```

适合你想验证 `agy` 路径和 Antigravity 专用配置有没有接通。

## 我更推荐的真实使用姿势

别一上来就让后端真跑。更稳的顺序是:

1. 先用 `run_delegate_agent.ps1 -WhatIf` 看路由
2. 再用 `manage_auto_routing.ps1 -Action list` 看当前规则
3. 用 `manage_auto_routing.ps1 -Action explain` 看某条 prompt 为什么会分到那个后端
4. 确认没问题后，再去掉 `-WhatIf`

这套节奏的好处很实际:

- 安装问题会更早暴露
- 路由逻辑更透明
- 真实执行前你就知道风险点

## 仓库结构很克制，也很实用

这个仓库不是“只有几个脚本拼起来”的一次性产物，它已经拆成了几层:

- `shared/`
  共享文档和公共 PowerShell 逻辑
- `backends/`
  后端元数据、脚本和后端说明
- `packages/relay-agent/`
  统一入口 package
- `packages/relay-claude/`
  Claude package
- `packages/relay-opencode/`
  OpenCode package
- `packages/relay-antigravity/`
  Antigravity package
- `scripts/build-packages.ps1`
  重新生成 packages
- `scripts/validate-packages.ps1`
  校验生成结果

如果你是使用者，先看 `packages/`。

如果你是维护者，重点看 `shared/`、`backends/`、`scripts/` 和 `docs/`。

## 安装和维护建议

更推荐的维护方式，是把整个仓库放进 Codex skills 目录，然后生成并链接 package:

```powershell
.\scripts\build-packages.ps1
.\scripts\install-workspace-skill-links.ps1
```

这样会得到四个可安装 skill:

- `relay-agent`
- `relay-claude`
- `relay-opencode`
- `relay-antigravity`

如果你只是想快速使用，也可以直接复制已经生成好的 package。

完整安装说明在这里:

- [docs/installation.md](docs/installation.md)

## 推荐阅读顺序

如果你想快速建立全局理解，建议按这个顺序看:

1. [docs/quickstart.md](docs/quickstart.md)
2. [docs/package-selection.md](docs/package-selection.md)
3. [docs/routing-guide.md](docs/routing-guide.md)
4. [docs/installation.md](docs/installation.md)
5. [docs/troubleshooting.md](docs/troubleshooting.md)

如果你是维护者，再继续看:

- [docs/architecture.md](docs/architecture.md)
- [docs/platform-architecture-v2.md](docs/platform-architecture-v2.md)
- [docs/release-checklist.md](docs/release-checklist.md)

## 最后一句话

`Relay` 不是为了让 agent 更“放飞”，而是为了让多 agent 协作这件事，第一次变得足够可控、可解释、可工程化。

如果你喜欢“边界先说清，再把速度拉满”的工作方式，这个项目应该会很对味。
