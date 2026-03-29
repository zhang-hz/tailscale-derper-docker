# Tailscale Derper Docker

一个带 ACME DNS-01 自动证书续期的 Tailscale derper 服务器。

## 功能特性

- ✅ Tailscale derper 服务器
- ✅ 自动证书签发和续期（通过 acme.sh + DNS-01）
- ✅ 支持多种 DNS 提供商（Cloudflare、DNSPod、阿里云等）
- ✅ 完全可配置（环境变量）
- ✅ 客户端验证支持（`-verify-clients`）
- ✅ 后台自动续期

## 两种部署方式

### 方式一：原生部署（推荐，更快更稳定）

适用于 Linux 服务器，不需要 Docker。

#### 1. 克隆仓库

```bash
git clone https://github.com/zhang-hz/tailscale-derper-docker.git
cd tailscale-derper-docker
```

#### 2. 配置环境变量

复制示例配置文件：

```bash
cp .env.example .env
cp acme.env.example acme.env
```

编辑 `.env`：

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

编辑 `acme.env`（填入你的 DNS 提供商凭据）：

```env
# DNSPod 示例
DP_Id="your-dnspod-id"
DP_Key="your-dnspod-key"

# Cloudflare 示例
# CF_Key="your-cloudflare-api-key"
# CF_Email="your-cloudflare-email"
```

#### 3. 运行部署脚本

```bash
chmod +x deploy-native.sh
sudo ./deploy-native.sh
```

#### 4. 管理服务

```bash
# 查看状态
sudo systemctl status derper

# 查看日志
sudo journalctl -u derper -f

# 重启服务
sudo systemctl restart derper

# 手动续期证书
sudo /opt/derper/renew-cert.sh
```

---

### 方式二：Docker 部署

#### 1. 克隆仓库

```bash
git clone https://github.com/zhang-hz/tailscale-derper-docker.git
cd tailscale-derper-docker
```

#### 2. 配置环境变量

```bash
cp .env.example .env
cp acme.env.example acme.env
```

编辑 `.env` 和 `acme.env`（同上）

#### 3. 启动服务

```bash
docker-compose up -d
```

---

## 配置说明

### 环境变量 (.env)

| 变量 | 说明 | 默认值 | 必填 |
|------|------|---------|------|
| `DERP_DOMAIN` | 你的 derper 域名 | - | 是 |
| `DERP_CERT_DIR` | 证书存储目录 | `/app/certs` | 否 |
| `DERP_STUN_PORT` | STUN 端口 | `3478` | 否 |
| `DERP_HTTPS_PORT` | HTTPS 端口 | `443` | 否 |
| `DERP_VERIFY_CLIENTS` | 验证 Tailscale 客户端 | `false` | 否 |
| `ACME_DNS_PROVIDER` | acme.sh DNS 提供商 | - | 否 |
| `ACME_EMAIL` | ACME 账户邮箱 | - | 使用 ACME 时必填 |
| `AUTO_RENEW_CERTS` | 启用自动续期 | `true` | 否 |
| `RENEW_INTERVAL` | 续期检查间隔（秒） | `86400` | 否 |

### 支持的 DNS 提供商

本项目使用 acme.sh，支持多种 DNS 提供商：

- `dns_cf` - Cloudflare
- `dns_dp` - DNSPod
- `dns_ali` - 阿里云 DNS
- `dns_gd` - GoDaddy
- `dns_aws` - AWS Route53
- 更多支持：[acme.sh DNS API 文档](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)

### 客户端验证 (VERIFY_CLIENTS)

启用 `DERP_VERIFY_CLIENTS=true` 时，derper 只允许你的 Tailnet 中的节点连接。

**原生部署方式**：
- 脚本会自动配置并启用验证
- 确保你的服务器能访问 Tailscale 控制平面

**Docker 部署方式**：
- 需要在同一网络中运行 tailscaled
- 或提供 Tailscale OAuth 凭证

---

## 文件结构

```
tailscale-derper-docker/
├── Dockerfile              # Docker 镜像
├── docker-compose.yml      # Docker Compose 配置
├── entrypoint.sh           # Docker 入口脚本
├── acme-renew.sh           # Docker 证书续期脚本
├── deploy-native.sh        # 原生部署脚本（推荐）
├── .env.example            # 环境变量示例
├── acme.env.example        # DNS 凭据示例
├── .gitignore
└── README.md               # 本文档
```

---

## 故障排查

### 证书签发失败

- 检查 DNS 提供商凭据是否正确
- 确认域名 DNS 解析正确
- 查看 acme.sh 日志：`/root/.acme.sh/acme.sh.log`

### 端口被占用

- 修改 `DERP_HTTPS_PORT` 为其他端口
- 或停止占用端口的服务

### 服务无法启动

- 查看日志：`journalctl -u derper -n 50`
- 检查证书文件权限：`ls -la /opt/derper/certs/`

---

## 许可证

MIT
