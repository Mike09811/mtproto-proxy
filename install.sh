#!/bin/bash
set -e

# ============================================================
# MTProto Proxy 一键安装脚本
# https://github.com/Mike09811/mtproto-proxy
# Version: 1.1.0
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/mtproto-proxy"
SERVICE_NAME="mtprotoproxy"
REPO_URL="https://github.com/Mike09811/mtproto-proxy.git"

print_msg() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
print_err() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_err "请使用 root 用户运行此脚本"
        exit 1
    fi
}

get_public_ip() {
    local ip=""
    for url in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
        ip=$(curl -s --max-time 5 "$url" 2>/dev/null)
        if [ -n "$ip" ]; then
            echo "$ip"
            return
        fi
    done
    echo "YOUR_SERVER_IP"
}

generate_secret() {
    head -c 16 /dev/urandom | xxd -ps
}

check_and_skip_deps() {
    # 如果 python3 git curl xxd 都已存在，跳过包管理器
    command -v python3 &>/dev/null && command -v git &>/dev/null && \
    command -v curl &>/dev/null && command -v xxd &>/dev/null
}

install_deps() {
    print_info "检查依赖..."

    if check_and_skip_deps; then
        print_msg "基础依赖已就绪，跳过系统包安装"
    else
        print_info "安装系统依赖（可能需要几分钟）..."
        if command -v apt-get &>/dev/null; then
            # 跳过慢源，只用主源，加超时
            apt-get update -qq -o Acquire::http::Timeout=15 -o Acquire::Retries=2 2>/dev/null || \
                print_warn "apt update 部分失败，继续尝试安装..."
            apt-get install -y -qq --no-install-recommends python3 python3-pip git curl xxd 2>/dev/null || \
                apt-get install -y -qq python3 git curl 2>/dev/null || true
        elif command -v yum &>/dev/null; then
            yum install -y -q python3 python3-pip git curl vim-common 2>/dev/null || true
        elif command -v dnf &>/dev/null; then
            dnf install -y -q python3 python3-pip git curl vim-common 2>/dev/null || true
        fi

        # 最终检查
        if ! command -v python3 &>/dev/null; then
            print_err "python3 未安装，请手动安装后重试"
            exit 1
        fi
        if ! command -v git &>/dev/null; then
            print_err "git 未安装，请手动安装后重试"
            exit 1
        fi
        print_msg "系统依赖安装完成"
    fi

    # pip 安装加速模块（非必须，失败不影响）
    print_info "安装 Python 加速模块（可选）..."
    pip3 install -q --timeout 15 cryptography 2>/dev/null || \
        python3 -m pip install -q --timeout 15 cryptography 2>/dev/null || \
        print_warn "cryptography 安装失败，将使用内置加密（较慢但可用）"
    pip3 install -q --timeout 15 uvloop 2>/dev/null || \
        python3 -m pip install -q --timeout 15 uvloop 2>/dev/null || \
        print_warn "uvloop 安装失败，不影响使用"
    print_msg "依赖检查完成"
}

install_proxy() {
    print_info "下载 MTProto Proxy..."
    if [ -d "$INSTALL_DIR" ]; then
        print_warn "检测到已有安装，备份旧配置..."
        cp -f "$INSTALL_DIR/config.py" "/tmp/mtproto_config_backup.py" 2>/dev/null || true
        rm -rf "$INSTALL_DIR"
    fi

    # 尝试 GitHub，失败则用镜像
    if ! timeout 30 git clone --depth 1 -q "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
        print_warn "GitHub 连接慢，尝试镜像..."
        local MIRROR_URL="https://ghproxy.com/$REPO_URL"
        if ! timeout 30 git clone --depth 1 -q "$MIRROR_URL" "$INSTALL_DIR" 2>/dev/null; then
            MIRROR_URL="https://mirror.ghproxy.com/$REPO_URL"
            timeout 60 git clone --depth 1 -q "$MIRROR_URL" "$INSTALL_DIR" || {
                print_err "下载失败，请检查网络后重试"
                exit 1
            }
        fi
    fi
    print_msg "下载完成"
}

configure_proxy() {
    local secret
    local port
    local ad_tag
    local tls_domain

    echo ""
    echo -e "${CYAN}========== 配置代理 ==========${NC}"
    echo ""

    # 端口
    read -rp "$(echo -e "${CYAN}[?]${NC}") 监听端口 [默认 443]: " port
    port=${port:-443}

    # 密钥
    local default_secret
    default_secret=$(generate_secret)
    read -rp "$(echo -e "${CYAN}[?]${NC}") 用户密钥 [回车自动生成]: " secret
    secret=${secret:-$default_secret}

    # TLS 域名
    read -rp "$(echo -e "${CYAN}[?]${NC}") TLS 伪装域名 [默认 go.microsoft.com]: " tls_domain
    tls_domain=${tls_domain:-go.microsoft.com}

    # 生成 dd 开头的 secure secret（用于推广链接）
    local dd_secret="dd${secret}"
    # 生成 ee 开头的 TLS secret（更隐蔽）
    local ee_secret="ee${secret}$(echo -n "$tls_domain" | xxd -ps | tr -d '\n')"

    echo ""
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}  请先去 Telegram @MTProxybot 注册代理${NC}"
    echo -e "${YELLOW}============================================${NC}"
    echo ""
    echo -e "  1. 打开 Telegram 搜索 ${CYAN}@MTProxybot${NC}"
    echo -e "  2. 发送 ${CYAN}/newproxy${NC}"
    echo -e "  3. 输入服务器 IP 和端口: ${CYAN}$(get_public_ip):${port}${NC}"
    echo -e "  4. 当机器人要求输入 secret (32 hex) 时，发送:"
    echo ""
    echo -e "     ${GREEN}${secret}${NC}"
    echo ""
    echo -e "  5. 按提示绑定你要推广的频道"
    echo -e "  6. 机器人会给你一个 TAG，复制过来"
    echo ""
    echo -e "${YELLOW}============================================${NC}"
    echo ""

    # AD_TAG
    read -rp "$(echo -e "${CYAN}[?]${NC}") 推广 TAG (粘贴上面获取的 tag，留空跳过): " ad_tag

    # 写配置
    local ad_tag_line="# AD_TAG = \"\""
    if [ -n "$ad_tag" ]; then
        ad_tag_line="AD_TAG = \"$ad_tag\""
    fi

    cat > "$INSTALL_DIR/config.py" << EOF
PORT = $port

USERS = {
    "tg": "$secret",
}

MODES = {
    "classic": False,
    "secure": True,
    "tls": True,
}

TLS_DOMAIN = "$tls_domain"

$ad_tag_line

MASK = True
MASK_HOST = TLS_DOMAIN
MASK_PORT = 443
EOF

    print_msg "配置写入完成"
}

setup_systemd() {
    print_info "配置 systemd 服务..."
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=MTProto Proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/mtprotoproxy.py
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    systemctl restart "$SERVICE_NAME"
    print_msg "服务已启动并设为开机自启"
}

show_info() {
    local ip
    ip=$(get_public_ip)

    local port
    port=$(python3 -c "exec(open('$INSTALL_DIR/config.py').read()); print(PORT)" 2>/dev/null || echo "443")

    local secret
    secret=$(python3 -c "exec(open('$INSTALL_DIR/config.py').read()); print(list(USERS.values())[0])" 2>/dev/null || echo "unknown")

    local tls_domain
    tls_domain=$(python3 -c "exec(open('$INSTALL_DIR/config.py').read()); print(TLS_DOMAIN)" 2>/dev/null || echo "go.microsoft.com")

    local dd_secret="dd${secret}"
    local ee_secret="ee${secret}$(echo -n "$tls_domain" | xxd -ps)"

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  MTProto Proxy 安装成功！${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "  服务器 IP:  ${CYAN}$ip${NC}"
    echo -e "  端口:       ${CYAN}$port${NC}"
    echo -e "  密钥:       ${CYAN}$secret${NC}"
    echo -e "  TLS 域名:   ${CYAN}$tls_domain${NC}"
    echo ""
    echo -e "  ${YELLOW}推广链接（带频道推广，分享给用户用这个）:${NC}"
    echo -e "  tg://proxy?server=${ip}&port=${port}&secret=${dd_secret}"
    echo -e "  https://t.me/proxy?server=${ip}&port=${port}&secret=${dd_secret}"
    echo ""
    echo -e "  ${YELLOW}TLS 链接（更隐蔽，无推广）:${NC}"
    echo -e "  tg://proxy?server=${ip}&port=${port}&secret=${ee_secret}"
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "  管理命令:"
    echo -e "    启动:   ${CYAN}systemctl start $SERVICE_NAME${NC}"
    echo -e "    停止:   ${CYAN}systemctl stop $SERVICE_NAME${NC}"
    echo -e "    重启:   ${CYAN}systemctl restart $SERVICE_NAME${NC}"
    echo -e "    状态:   ${CYAN}systemctl status $SERVICE_NAME${NC}"
    echo -e "    日志:   ${CYAN}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "    卸载:   ${CYAN}bash $INSTALL_DIR/install.sh uninstall${NC}"
    echo ""
}

uninstall() {
    print_info "卸载 MTProto Proxy..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    rm -rf "$INSTALL_DIR"
    print_msg "卸载完成"
    exit 0
}

main() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  MTProto Proxy 一键安装脚本${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""

    if [ "${1}" = "uninstall" ]; then
        check_root
        uninstall
    fi

    check_root
    install_deps
    install_proxy
    configure_proxy
    setup_systemd
    show_info
}

main "$@"
