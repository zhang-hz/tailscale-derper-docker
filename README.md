# Tailscale Derper Docker

一个带 ACME DNS-01 自动证书续期的 Tailscale derper 服务器，支持客户端验证。

## 功能特性

- ✅ Tailscale derper 服务器
- ✅ 自动证书签发和续期（通过 acme.sh + DNS-01）
- ✅ 支持多种 DNS 提供商（Cloudflare、DNSPod、阿里云等）
- ✅ 完全可配置（环境变量）
- ✅ 客户端验证支持（`-verify-clients`）
- ✅ 后台自动续期
- ✅ GitHub Actions 自动构建 Docker 镜像

## 目录

- [快速开始](#快速开始)
- [原生部署](#原生部署)
- [Docker 部署](#docker-部署)
- [配置说明](#配置说明)
- [客户端验证](#客户端验证)
- [GitHub Actions](#github-actions)
- [故障排查](#故障排查)

---

## 快速开始

### 原生部署（推荐）

```bash
# 克隆仓库
git clone https://github.com/zhang-hz/tailscale-derper-docker.git
cd tailscale-derper-docker

# 配置环境变量
cp .env.example .env
cp acme.env.example acme.env

# 编辑配置文件
vim .env      # 设置域名和端口
vim acme.env  # 设置 DNS 提供商凭据

# 运行部署脚本
chmod +x deploy-native.sh
sudo ./deploy-native.sh --domain derp.example.com --authkey tskey-auth-xxx
```

### Docker 部署

```bash
git clone https://github.com/zhang-hz/tailscale-derper-docker.git
cd tailscale-derper-docker

cp .env.example .env
cp acme.env.example acme.env

# 编辑配置文件后
docker-compose up -d
```

---

## 原生部署

适用于 Linux 服务器，不需要 Docker，更快更稳定。

### 前置要求

- Linux 系统（Ubuntu/Debian/CentOS 等）
- systemd
- root 权限

### 部署步骤

#### 1. 配置环境变量

创建 `.env` 文件：

```env
DERP_DOMAIN=derp.yourdomain.com
DERP_STUN_PORT=3478
DERP_HTTPS_PORT=14430
DERP_VERIFY_CLIENTS=true
ACME_DNS_PROVIDER=dns_dp
ACME_EMAIL=your@email.com
AUTO_RENEW_CERTS=true
RENEW_INTERVAL=2592000
```

创建 `acme.env` 文件（DNS 提供商凭据）：

```env
# DNSPod
DP_Id="123456"
DP_Key="your-dnspod-api-key"

# Cloudflare
# CF_Key="your-cloudflare-api-key"
# CF_Email="your@email.com"
```

#### 2. 运行部署脚本

```bash
chmod +x deploy-native.sh
sudo ./deploy-native.sh --domain derp.yourdomain.com --authkey tskey-auth-xxx
```

**参数说明：**

| 参数 | 说明 | 必填 |
|------|------|------|
| `--domain` | 你的 derper 域名 | 是 |
| `--authkey` | Tailscale Auth Key（用于 verify-clients） | 推荐 |
| `--skip-cert` | 跳过证书签发 | 否 |

#### 3. 管理服务

```bash
# 查看状态
sudo systemctl status derper

# 查看日志
sudo journalctl -u derper -f

# 重启服务
sudo systemctl restart derper

# 手动续期证书
sudo /opt/derper/renew-cert.sh

# 查看 Tailscale 状态
sudo tailscale status
```

---

## Docker 部署

### 前置要求

- Docker
- Docker Compose

### 部署步骤

1. 配置 `.env` 和 `acme.env`（同上）

2. 启动服务：

```bash
docker-compose up -d
```

3. 查看日志：

```bash
docker-compose logs -f
```

---

## 配置说明

### 环境变量 (.env)

| 变量 | 说明 | 默认值 | 必填 |
|------|------|---------|------|
| `DERP_DOMAIN` | 你的 derper 域名 | - | 是 |
| `DERP_STUN_PORT` | STUN 端口 | `3478` | 否 |
| `DERP_HTTPS_PORT` | HTTPS 端口 | `443` | 否 |
| `DERP_VERIFY_CLIENTS` | 验证 Tailscale 客户端 | `false` | 否 |
| `ACME_DNS_PROVIDER` | acme.sh DNS 提供商 | - | 推荐 |
| `ACME_EMAIL` | ACME 账户邮箱 | - | 使用 ACME 时 |
| `AUTO_RENEW_CERTS` | 启用自动续期 | `true` | 否 |
| `RENEW_INTERVAL` | 续期检查间隔（秒） | `86400` | 否 |

### 支持的 DNS 提供商

本项目使用 acme.sh，支持多种 DNS 提供商：

| 提供商 | 环境变量值 |
|--------|-----------|
| Cloudflare | `dns_cf` |
| DNSPod | `dns_dp` |
| 阿里云 DNS | `dns_ali` |
| GoDaddy | `dns_gd` |
| AWS Route53 | `dns_aws` |
| DNSPod 中国 | `dns_dp` |

完整列表：[acme.sh DNS API 文档](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)

---

## 客户端验证

启用 `DERP_VERIFY_CLIENTS=true` 时，derper 只允许你的 Tailnet 中的节点连接。

### 工作原理

`-verify-clients` 需要：
1. 服务器运行 `tailscaled` 并登录到你的 Tailnet
2. derper 通过本地 socket 连接到 `tailscaled` 进行验证

### 获取 Auth Key

1. 登录 [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. 创建一个新的 Auth Key（推荐使用带标签的 key，如 `tag:derper`）
3. 复制 key 用于部署

### 原生部署配置验证

```bash
# 查看 Tailscale 状态
sudo tailscale status

# 确认 derper 已启用验证
sudo journalctl -u derper -n 5 | grep verify-clients
```

---

## GitHub Actions

本仓库配置了自动构建 Docker 镜像的 GitHub Actions。

### 触发条件

| 事件 | 行为 |
|------|------|
| Push 到 main 分支 | 构建并推送 Docker 镜像 |
| 每周一 | 定时构建（确保使用最新 Tailscale） |
| 创建 tag (v*) | 构建并推送版本标签镜像 |
| 手动触发 | 可指定 Tailscale 版本 |

### 构建的镜像

- `ghcr.io/<user>/tailscale-derper:latest`
- `ghcr.io/<user>/tailscale-derper:<tailscale-version>`
- `ghcr.io/<user>/tailscale-derper:<commit-sha>`

### 多平台支持

- linux/amd64
- linux/arm64
- linux/arm/v7

---

## 故障排查

### 证书签发失败

- 检查 DNS 提供商凭据是否正确
- 确认域名 DNS 解析已生效
- 查看 acme.sh 日志：`tail /root/.acme.sh/acme.sh.log`

### 端口被占用

```bash
# 查看端口占用
sudo lsof -i :14430

# 或修改 .env 中的端口
```

### 服务无法启动

```bash
# 查看详细日志
sudo journalctl -u derper -n 50

# 检查证书文件权限
ls -la /opt/derper/certs/
```

### Tailscale 登录失败

如果使用 OAuth Auth Key 时提示需要 `--advertise-tags`：
- 使用普通的 Auth Key（非 OAuth 类型）
- 或在 Tailscale Admin Console 创建一个带标签的 key

---

## 文件结构

```
tailscale-derper-docker/
├── .github/
│   └── workflows/
│       └── docker-image.yml     # GitHub Actions 配置
├── .env.example                 # 环境变量示例
├── acme.env.example             # DNS 凭据示例
├── deploy-native.sh             # 原生部署脚本（推荐）
├── Dockerfile                   # Docker 镜像
├── docker-compose.yml           # Docker Compose 配置
├── entrypoint.sh               # Docker 入口脚本
├── acme-renew.sh               # Docker 证书续期脚本
└── README.md                   # 本文档
```

---

## 许可证

MIT
