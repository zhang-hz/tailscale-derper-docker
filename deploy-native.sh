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

# 加载环境变量
if [ ! -f ".env" ]; then
    echo "错误: .env 文件不存在！"
    echo "请先复制: cp .env.example .env"
    exit 1
fi

source .env

# 检查必需变量
if [ -z "$DERP_DOMAIN" ]; then
    echo "错误: DERP_DOMAIN 未设置"
    exit 1
fi

if [ -z "$ACME_DNS_PROVIDER" ]; then
    echo "警告: ACME_DNS_PROVIDER 未设置，将不使用自动证书"
fi

# 1. 安装基础依赖
echo ""
echo "1/6 安装依赖..."
apt-get update
apt-get install -y curl wget git

# 2. 安装 Tailscale（用于 derper 和客户端验证）
echo ""
echo "2/6 安装 Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# 3. 安装 Go
echo ""
echo "3/6 安装 Go..."
if ! command -v go &> /dev/null; then
    cd /tmp
    wget -q https://go.dev/dl/go1.23.5.linux-amd64.tar.gz -O go.tar.gz
    tar -C /usr/local -xzf go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:/root/go/bin' >> /root/.bashrc
fi
export PATH=$PATH:/usr/local/go/bin:/root/go/bin

# 4. 编译安装 derper
echo ""
echo "4/6 编译安装 derper..."
go install tailscale.com/cmd/derper@latest

# 5. 安装 acme.sh
echo ""
echo "5/6 安装 acme.sh..."
if [ ! -f "/root/.acme.sh/acme.sh" ] && [ ! -z "$ACME_DNS_PROVIDER" ]; then
    curl https://get.acme.sh | sh -s email="$ACME_EMAIL"
fi

# 6. 创建目录和配置文件
echo ""
echo "6/6 配置服务..."
mkdir -p /opt/derper/certs
cp .env /opt/derper/config

# 复制 acme.env（如果存在）
if [ -f "acme.env" ]; then
    cp acme.env /opt/derper/
fi

# 签发证书（如果配置了 DNS）
if [ ! -z "$ACME_DNS_PROVIDER" ] && [ -f "acme.env" ]; then
    echo ""
    echo "签发证书..."
    export PATH="/root/.acme.sh:$PATH"
    source acme.env
    
    CERT_PATH="/opt/derper/certs/$DERP_DOMAIN.crt"
    KEY_PATH="/opt/derper/certs/$DERP_DOMAIN.key"
    
    if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
        /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        /root/.acme.sh/acme.sh --issue --dns "$ACME_DNS_PROVIDER" -d "$DERP_DOMAIN" \
            --cert-file "$CERT_PATH" \
            --key-file "$KEY_PATH" \
            --fullchain-file "$CERT_PATH"
    else
        echo "证书已存在"
        cp /root/.acme.sh/${DERP_DOMAIN}_ecc/fullchain.cer "$CERT_PATH"
        cp /root/.acme.sh/${DERP_DOMAIN}_ecc/$DERP_DOMAIN.key "$KEY_PATH"
    fi
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
    -a :${DERP_HTTPS_PORT:-14433} \\
    -certmode manual \\
    -certdir /opt/derper/certs \\
    -hostname ${DERP_DOMAIN} \\
    -stun-port ${DERP_STUN_PORT:-3478} \\
    ${DERP_VERIFY_CLIENTS:+ -verify-clients}
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
echo "常用命令："
echo "  查看服务状态: systemctl status derper"
echo "  查看日志:     journalctl -u derper -f"
echo "  重启服务:     systemctl restart derper"
echo "  手动续期:     /opt/derper/renew-cert.sh"
echo ""
echo "配置文件位置：/opt/derper/"
