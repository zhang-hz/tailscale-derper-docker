#!/bin/bash

set -e

# Tailscale Derper 原生部署脚本
# 适用于 Linux 系统（systemd）

echo "=== Tailscale Derper 部署脚本 ==="

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行: sudo $0"
    exit 1
fi

# 解析命令行参数
DERP_DOMAIN=""
TS_AUTHKEY=""
SKIP_CERT=false

usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --domain <域名>          设置 DERP 域名 (必需)"
    echo "  --authkey <key>         设置 Tailscale Auth Key (用于 verify-clients)"
    echo "  --skip-cert             跳过证书签发"
    echo "  --help                  显示此帮助信息"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DERP_DOMAIN="$2"
            shift 2
            ;;
        --authkey)
            TS_AUTHKEY="$2"
            shift 2
            ;;
        --skip-cert)
            SKIP_CERT=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "未知选项: $1"
            usage
            ;;
    esac
done

# 如果没有通过参数传入，尝试从 .env 读取
if [ -z "$DERP_DOMAIN" ] && [ -f ".env" ]; then
    source .env
fi

if [ -z "$DERP_DOMAIN" ]; then
    echo "错误: DERP_DOMAIN 未设置"
    echo "可以通过 --domain 参数或 .env 文件设置"
    usage
fi

# 1. 安装基础依赖
echo ""
echo "1/8 安装依赖..."
apt-get update
apt-get install -y curl wget git jq

# 2. 安装 Tailscale（用于 derper 和客户端验证）
echo ""
echo "2/8 安装 Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# 3. 安装 Go
echo ""
echo "3/8 安装 Go..."
if ! command -v go &> /dev/null; then
    cd /tmp
    wget -q https://go.dev/dl/go1.23.5.linux-amd64.tar.gz -O go.tar.gz
    tar -C /usr/local -xzf go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:/root/go/bin' >> /root/.bashrc
fi
export PATH=$PATH:/usr/local/go/bin:/root/go/bin

# 4. 编译安装 derper
echo ""
echo "4/8 编译安装 derper..."
go install tailscale.com/cmd/derper@latest

# 5. 安装 acme.sh
echo ""
echo "5/8 安装 acme.sh..."
if [ ! -f "/root/.acme.sh/acme.sh" ] && [ -f "acme.env" ]; then
    source acme.env
    ACME_EMAIL_VAR="${ACME_EMAIL:-admin@example.com}"
    curl https://get.acme.sh | sh -s email="$ACME_EMAIL_VAR"
fi

# 6. 创建目录和配置文件
echo ""
echo "6/8 配置目录..."
mkdir -p /opt/derper/certs

# 创建配置
cat > /opt/derper/config << EOF
DERP_DOMAIN=$DERP_DOMAIN
DERP_STUN_PORT=${DERP_STUN_PORT:-3478}
DERP_HTTPS_PORT=${DERP_HTTPS_PORT:-14430}
DERP_VERIFY_CLIENTS=${DERP_VERIFY_CLIENTS:-false}
ACME_DNS_PROVIDER=${ACME_DNS_PROVIDER:-}
ACME_EMAIL=${ACME_EMAIL:-}
AUTO_RENEW_CERTS=${AUTO_RENEW_CERTS:-true}
RENEW_INTERVAL=${RENEW_INTERVAL:-2592000}
EOF

# 复制 acme.env（如果存在）
if [ -f "acme.env" ]; then
    cp acme.env /opt/derper/
fi

# 7. 签发证书
echo ""
echo "7/8 配置证书..."
if [ "$SKIP_CERT" = false ] && [ -f "acme.env" ]; then
    export PATH="/root/.acme.sh:$PATH"
    source acme.env
    
    CERT_PATH="/opt/derper/certs/$DERP_DOMAIN.crt"
    KEY_PATH="/opt/derper/certs/$DERP_DOMAIN.key"
    
    if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
        echo "签发证书..."
        /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        /root/.acme.sh/acme.sh --issue --dns "$ACME_DNS_PROVIDER" -d "$DERP_DOMAIN" \
            --cert-file "$CERT_PATH" \
            --key-file "$KEY_PATH" \
            --fullchain-file "$CERT_PATH"
    else
        echo "证书已存在，复制到目标位置..."
        cp /root/.acme.sh/${DERP_DOMAIN}_ecc/fullchain.cer "$CERT_PATH"
        cp /root/.acme.sh/${DERP_DOMAIN}_ecc/$DERP_DOMAIN.key "$KEY_PATH"
    fi
else
    echo "跳过证书配置"
fi

# 8. 配置 tailscaled 和 derper 服务
echo ""
echo "8/8 配置服务..."

# 配置 tailscaled（如果提供了 authkey）
if [ -n "$TS_AUTHKEY" ]; then
    echo "配置 Tailscale 登录..."
    systemctl start tailscaled
    sleep 2
    tailscale up --authkey="$TS_AUTHKEY"
    systemctl enable tailscaled
    echo "Tailscale 已登录并启用"
else
    echo "警告: 未提供 --authkey，跳过 Tailscale 登录"
    echo "如果不使用 verify-clients，可以忽略此警告"
fi

# 创建证书续期脚本
cat > /opt/derper/renew-cert.sh << 'EOF'
#!/bin/bash
export PATH="/root/.acme.sh:/usr/local/go/bin:/root/go/bin:$PATH"

# 加载配置
if [ -f "/opt/derper/acme.env" ]; then
    source /opt/derper/acme.env
fi
if [ -f "/opt/derper/config" ]; then
    source /opt/derper/config
fi

CERT_PATH="/opt/derper/certs/$DERP_DOMAIN.crt"
KEY_PATH="/opt/derper/certs/$DERP_DOMAIN.key"

echo "[$(date)] 续期证书..."
/root/.acme.sh/acme.sh --renew -d "$DERP_DOMAIN" \
    --cert-file "$CERT_PATH" \
    --key-file "$KEY_PATH" \
    --fullchain-file "$CERT_PATH"

echo "[$(date)] 重启 derper 服务..."
systemctl reload derper || systemctl restart derper

echo "[$(date)] 完成！"
EOF

chmod +x /opt/derper/renew-cert.sh

# 确定 verify-clients 参数
VERIFY_CLIENTS_ARG=""
if [ "${DERP_VERIFY_CLIENTS:-false}" = "true" ]; then
    VERIFY_CLIENTS_ARG="--verify-clients"
fi

# 创建 systemd 服务
cat > /etc/systemd/system/derper.service << EOF
[Unit]
Description=Tailscale Derper Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/derper
Environment="PATH=/root/go/bin:/usr/local/go/bin:/root/.acme.sh:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/root/go/bin/derper \\
    -a :${DERP_HTTPS_PORT:-14430} \\
    -certmode manual \\
    -certdir /opt/derper/certs \\
    -hostname ${DERP_DOMAIN} \\
    -stun-port ${DERP_STUN_PORT:-3478} \\
    ${VERIFY_CLIENTS_ARG}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 添加每月续期的 cron 任务
echo ""
echo "配置证书自动续期..."
(crontab -l 2>/dev/null | grep -v -F "/opt/derper/renew-cert.sh"; echo "0 0 1 * * /opt/derper/renew-cert.sh >> /var/log/derper-renew.log 2>&1") | crontab -

# 启动服务
echo ""
echo "启动 derper 服务..."
systemctl daemon-reload
systemctl enable --now derper

# 等待服务启动
sleep 3

echo ""
echo "=== 部署完成！==="
echo ""
echo "服务状态："
systemctl status derper --no-pager
echo ""
echo "Tailscale 状态："
tailscale status 2>/dev/null || echo "Tailscale 未登录"
echo ""
echo "常用命令："
echo "  查看服务状态: systemctl status derper"
echo "  查看日志:     journalctl -u derper -f"
echo "  重启服务:     systemctl restart derper"
echo "  手动续期:     /opt/derper/renew-cert.sh"
echo "  Tailscale:    tailscale status"
echo ""
echo "配置文件位置：/opt/derper/"
