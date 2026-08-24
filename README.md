# DSH Agents

本目录管理多套彼此隔离的 DeepSeek Harness Web Agent。

仓库只保存管理脚本和实例清单，不保存 API Key、会话、Workspace、日志或 Harness 运行时。

## 当前实例

| Agent | Profile | 地址 | 独立数据目录 |
|---|---|---|---|
| HelloDesign Agent | `hello-design` | http://127.0.0.1:3081 | `~/.dsh-hello-design` |
| Allenchu Agent | `self-media` | http://127.0.0.1:3082 | `~/.dsh-self-media` |

每个实例都有独立的会话、Workspace、设置和凭据文件，不会互相读取或写入。

## 日常管理

```sh
./agents.sh status
./agents.sh start all
./agents.sh stop all
./agents.sh restart all
```

也可以只操作一个实例：

```sh
./agents.sh restart hello-design
./agents.sh restart self-media
```

## 新增 Agent

选择唯一的英文标识、未使用端口和显示名称：

```sh
./agents.sh create research 3083 "Research-Agent"
```

该命令会自动：

1. 创建独立的 `~/.dsh-research` 数据目录。
2. 创建 Web Profile。
3. 生成 macOS LaunchAgent。
4. 配置开机启动与崩溃重启。
5. 启动 `http://127.0.0.1:3083/`。
6. 将实例登记到 `agents.tsv`。

进入新实例后，在设置中配置模型、角色和 Skills。

## 稳定运行时

所有实例固定使用：

```text
~/.local/share/deepseek-harness-runtime
```

不会依赖 `~/.npm/_npx/` 临时缓存。当前固定版本为 `0.1.0-rc.6`。

版本由仓库根目录的 `VERSION` 文件固定。

## 更换电脑

在新 Mac 上安装符合 Harness 要求的 Node.js，然后克隆这个私人仓库：

```sh
git clone <private-repository-url> dsh-agents
cd dsh-agents
./install.sh
```

安装脚本会根据新电脑的 `$HOME` 和 Node.js 路径重新生成配置，安装固定版本的 Harness，并恢复 `agents.tsv` 中登记的全部实例。

安装完成后，分别打开各 Agent，在设置中重新填写模型凭据。凭据和历史数据不会通过 Git 迁移。

## 文件说明

```text
agents.sh        实例创建、启动、停止、重启和状态检查
agents.tsv       实例注册表
install.sh       新电脑一键安装
start-agents.sh  兼容旧入口，调用 agents.sh start
VERSION          固定的 Harness 版本
```

系统自启动配置位于：

```text
~/Library/LaunchAgents/com.allenchu.dsh-<slug>.plist
```

运行日志位于：

```text
~/Library/Logs/dsh-<slug>.log
~/Library/Logs/dsh-<slug>.err.log
```
