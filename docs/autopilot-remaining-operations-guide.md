# 剩余事项操作指南(逐步命令版)

日期:2026-09-07。配套:`docs/autopilot-central-deployment-checklist.md`
(总清单)与 `docs/REQUIREMENTS_MATRIX.md`(证据状态)。本文把"剩余
NO 行"翻译成可执行步骤。标 ⛔ 的只能由你(账号所有者)完成;标 ✅ 的
可由我代做。

## Phase A — 你的账户动作(顺序执行,一次约 20-30 分钟)

### A1. ⛔ controller 仓分支保护(免费计划 403 的解法)

二选一:

- 升级 Pro:github.com/settings/billing → **Get GitHub Pro**($4/月);
- 或改公开:repo → Settings → General → Danger Zone → Change
  visibility → Public(代码将可见,谨慎)。

完成后启用保护(我可以代跑,或你自己粘贴):

```bash
gh api -X PUT repos/Amada203/project-autopilot/branches/main/protection --input - <<'EOF'
{"required_status_checks":{"strict":false,"contexts":["test","cross-repo"]},"enforce_admins":false,"required_pull_request_reviews":null,"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF
```

### A2. ⛔ GitHub App 创建(无 API,只能网页表单)

1. 打开 github.com/settings/apps/new,逐字段:
   - GitHub App name: `amada203-autopilot`
   - Homepage URL: `https://github.com/Amada203/ai-full-harness`
   - Identifying/authorization callback URL:留空;Webhook:**取消勾选 Active**
   - Permissions:Contents → **Read and write**;Pull requests → **Read
     and write**;Metadata → Read-only(默认);其余全部 No access
   - Where can this app be installed:Any account
2. Create GitHub App → 记下页面上的 **App ID** 与 **Client ID**。
3. Private keys → **Generate a private key**(.pem 自动下载)。
4. 左侧 Install App → 仅选择试点仓库。
5. 入库 secret(命令可由我代跑,需要你把 .pem 路径告诉我):

```bash
gh secret set AUTOPILOT_APP_PRIVATE_KEY --repo Amada203/project-autopilot < /path/to/*.pem
gh variable set AUTOPILOT_APP_ID --repo Amada203/project-autopilot --body "<AppID>"
```

### A3. ✅ 账本仓与首个 grant(我可以代做,涉及你的账号凭据时需确认)

```bash
gh repo create Amada203/autopilot-ledger --private   # 持久账本仓
./bin/autopilot-ledger init ~/autopilot-ledger.jsonl  # 本地主权账本
# 试点项目生成后:把项目的 .autopilot/GITHUB_GRANT.yml 填成有效签发,
# 再同步签入账本(两侧字段必须一致):
./bin/autopilot-ledger issue ~/autopilot-ledger.jsonl <project>/.autopilot/GITHUB_GRANT.yml
./bin/autopilot-ledger verify ~/autopilot-ledger.jsonl <project>/.autopilot/GITHUB_GRANT.yml --expect-tip <上一步输出的entry_hash>
# 推送快照到账本仓 + 配置 workflow 的 ledger-snapshot / ledger-token 两个 secret
```

### A4. ✅ 一次性试点(本地生成我来,远程需要 A1-A3 就绪)

```bash
./bin/new-full-project --autopilot enabled \
  --autopilot-controller-ref b2e5d9a6caf1$(git -C ~/project-autopilot rev-parse v0.1.0 | cut -c9-) \
  autopilot-pilot ~/Pilots
# 1) 完成 PROBLEM_FRAMING.md(删 REQUIRED 标记,写 Risk Level: M)
# 2) scripts/record-lifecycle-gate.sh plan && scripts/check-lifecycle-gate.sh plan
# 3) scripts/transition-autopilot.sh STAGE0_PASSED → … → ACTIVE(带 reason)
# 4) push 到私有仓 → 安装 App → workflow_dispatch(observe → dry-run=true → run)
```

验收点:dry-run 零写入;run 产生草稿 PR;撤销/暂停/SAFE_STOP 反例全部
拒绝;每次结果存档进 `docs/reviews/`。

### A5. ⛔ 真实多工具续接演练(需要你操作各工具)

同一试点项目:Codex 做一步并 snapshot → Claude 打开先跑
`node scripts/project-continuity.mjs audit` 确认 CONSISTENT 再继续 →
Cursor 同样。任何一步 audit 非 CONSISTENT 而工具继续改代码,即为反例。
全程留屏录/日志作为 H 类证据。

## Phase B — 我可继续开发的(按试点需求驱动)

| 项 | 内容 | 触发条件 |
| --- | --- | --- |
| B1 | 注册迁移 preview/apply/restore 命令(`bin/install-ai-full-harness` 扩展) | 你说"做默认注册" |
| B2 | 升级推送器 + 版本清单 + 项目迁移器( Harness self-upgrade 闭环) | 首个真实升级需求 |
| B3 | 反馈投递/去重/采纳回归闭环 | 试点产生真实反馈后 |
| B4 | 签名/时间戳账本服务(替代 tip 锚定的最终方案) | 多机/多项目共用账本时 |
| B5 | 知识同步断电恢复日志(lease/owner/逐文件操作日志) | 你要求"断电级"保证时 |

## 边界提醒

- A 阶段每一步都是你的授权动作;我代跑任何一步前都会先向你复述命令。
- 全程不碰:生产部署、默认分支直推合并、App 权限扩大。
- 试点产生的所有证据按 local/remote/human 分类记入验收报告。
