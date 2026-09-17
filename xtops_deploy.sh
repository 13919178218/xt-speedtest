#!/bin/bash
# ============================================================
# xt-ops-speedtest 智慧运维平台·专业网络测速 v202609300000
# 交互式部署脚本 — 生产环境开箱即用
# ============================================================
# 注意: 不使用 set -e，避免用户输入非默认值时异常退出

# ─── 强制UTF-8编码（解决中文/emoji乱码）───
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true
export LANG=C.UTF-8 2>/dev/null || export LANG=en_US.UTF-8 2>/dev/null || true

# ─── 常量 ───
IMAGE_PKG="xt-ops-speedtest-v202609300000.tar.gz"
IMAGE_TAG="xt-ops-speedtest:v202609300000"
CONTAINER_NAME="xt-ops-speedtest"
DEFAULT_PORT=8009

# ─── 颜色 ───
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[1m'; D='\033[2m'; N='\033[0m'

info()  { echo -e "  ${C}▸${N} $1"; }
ok()    { echo -e "  ${G}✓${N} $1"; }
warn()  { echo -e "  ${Y}⚠${N} $1"; }
err()   { echo -e "  ${R}✗${N} $1"; }
title() { echo -e "\n  ${B}${C}━━━ $1 ━━━${N}\n"; }
sep()   { echo -e "  ${D}─────────────────────────────────────${N}"; }

# ─── 输入辅助函数 ───
# prompt: 始终显示默认值，回车保留默认
# [修复] 使用 read -p 替代 echo -ne + read -r，解决UOS/麒麟终端下
#        光标移动(←→)和删除键(Backspace/Delete)不可用的问题
prompt() {
    local label="$1" default="$2"
    if [ -n "$default" ]; then
        read -p "  $label [$default]: " -r _ANSWER
    else
        read -p "  $label: " -r _ANSWER
    fi
    [ -z "$_ANSWER" ] && _ANSWER="$default"
}


confirm() {
    local label="$1" default="${2:-Y}"
    if [ "$default" = "Y" ]; then
        read -p "  $label [Y/n]: " -r _CONFIRM
    else
        read -p "  $label [y/N]: " -r _CONFIRM
    fi
    _CONFIRM=${_CONFIRM:-$default}
    case "${_CONFIRM^^}" in Y|YES) return 0 ;; *) return 1 ;; esac
}

# ============================================================
# 0. 欢迎界面
# ============================================================
echo ""
echo -e "  ${B}${C}╔══════════════════════════════════════════════╗${N}"
echo -e "  ${B}${C}║${N}  ${B}xt-ops-speedtest 智慧运维平台·专业网络测速${N}    ${B}${C}║${N}"
echo -e "  ${B}${C}║${N}  ${D}v202609300000  交互式部署向导 (7步)${N}          ${B}${C}║${N}"
echo -e "  ${B}${C}╚══════════════════════════════════════════════╝${N}"
echo ""

# ============================================================
# 1. 系统环境检测（全面体检）
# ============================================================
title "1/7 系统环境检测"

_CHECK_ERRORS=0    # 致命错误计数（阻止部署）
_CHECK_WARNINGS=0  # 警告计数（可继续但需注意）

# ── 国产OS专用Docker安装指导函数 ──
show_docker_install_guide() {
    local os="$1"
    echo ""
    err "  ──── ${B}${os} Docker离线安装指导${N} ────"
    err "  （纯内网环境，无法联网，必须使用离线安装方式）"
    case "$os" in
        uos)
            err ""
            err "  [方法1: 应用商店（UOS预装，推荐）]"
            err "    打开「应用商店」→ 搜索「Docker」→ 安装"
            err ""
            err "  [方法2: 离线DEB包安装（纯内网）]"
            err "    # 在有网机器下载DEB包（基于Debian Buster）："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/debian/dists/buster/pool/stable/amd64/docker-ce_20.10.24~3-0~debian-buster_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/debian/dists/buster/pool/stable/amd64/docker-ce-cli_20.10.24~3-0~debian-buster_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/debian/dists/buster/pool/stable/amd64/containerd.io_1.6.9-1_amd64.deb"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo dpkg -i containerd.io_*.deb docker-ce-cli_*.deb docker-ce_*.deb"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [方法3: 系统自带仓库（可能版本较旧但可用）]"
            err "    sudo apt-get install -y docker.io"
            err "    sudo systemctl enable --now docker"
            ;;
        kylin)
            err ""
            err "  [方法1: 离线DEB包安装 - 麒麟V10 Ubuntu基座（纯内网）]"
            err "    # 在有网机器下载DEB包（基于Ubuntu Focal）："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_20.10.24~3-0~ubuntu-focal_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_20.10.24~3-0~ubuntu-focal_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.6.9-1_amd64.deb"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo dpkg -i containerd.io_*.deb docker-ce-cli_*.deb docker-ce_*.deb"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [方法2: 离线RPM包安装 - 麒麟V4 CentOS基座（纯内网）]"
            err "    # 在有网机器下载RPM包："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-20.10.24-3.el7.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-20.10.24-3.el7.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/containerd.io-1.6.9-3.1.el7.x86_64.rpm"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo yum localinstall -y containerd.io-*.rpm docker-ce-cli-*.rpm docker-ce-*.rpm"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [方法3: 系统自带仓库（可能版本较旧但可用）]"
            err "    sudo apt-get install -y docker.io  # Ubuntu基座"
            err "    sudo yum install -y docker          # CentOS基座"
            err "    sudo systemctl enable --now docker"
            ;;
        deepin)
            err ""
            err "  [方法1: 应用商店（Deepin预装，推荐）]"
            err "    打开「应用商店」→ 搜索「Docker」→ 安装"
            err ""
            err "  [方法2: 离线DEB包安装（纯内网）]"
            err "    # 在有网机器下载DEB包（基于Debian Buster）："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/debian/dists/buster/pool/stable/amd64/docker-ce_20.10.24~3-0~debian-buster_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/debian/dists/buster/pool/stable/amd64/docker-ce-cli_20.10.24~3-0~debian-buster_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/debian/dists/buster/pool/stable/amd64/containerd.io_1.6.9-1_amd64.deb"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo dpkg -i containerd.io_*.deb docker-ce-cli_*.deb docker-ce_*.deb"
            err "    sudo systemctl enable --now docker"
            ;;
        openeuler)
            err ""
            err "  [方法1: 离线RPM包安装（纯内网，推荐）]"
            err "    # 在有网机器下载RPM包（基于CentOS 8）："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/8/x86_64/stable/Packages/docker-ce-20.10.24-3.el8.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/8/x86_64/stable/Packages/docker-ce-cli-20.10.24-3.el8.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/8/x86_64/stable/Packages/containerd.io-1.6.9-3.1.el8.x86_64.rpm"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo yum localinstall -y containerd.io-*.rpm docker-ce-cli-*.rpm docker-ce-*.rpm"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [方法2: 系统自带仓库（可能版本较旧但可用）]"
            err "    sudo yum install -y docker"
            err "    sudo systemctl enable --now docker"
            ;;
        anolis)
            err ""
            err "  [方法1: 离线RPM包安装（纯内网，推荐）]"
            err "    # 同openEuler方式，下载RPM包后localinstall"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo yum localinstall -y containerd.io-*.rpm docker-ce-cli-*.rpm docker-ce-*.rpm"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [方法2: 系统自带仓库（可能版本较旧但可用）]"
            err "    sudo yum install -y docker"
            err "    sudo systemctl enable --now docker"
            ;;
        tencentos)
            err ""
            err "  [方法1: 离线RPM包安装（纯内网，推荐）]"
            err "    # 同CentOS方式，下载RPM包后localinstall"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo yum localinstall -y containerd.io-*.rpm docker-ce-cli-*.rpm docker-ce-*.rpm"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [方法2: 系统自带仓库（可能版本较旧但可用）]"
            err "    sudo yum install -y docker"
            err "    sudo systemctl enable --now docker"
            ;;
    esac
    err ""
    err "  [通用离线安装步骤]"
    err "    1. 在有互联网的机器上下载Docker安装包（DEB/RPM）"
    err "    2. 通过U盘或SCP传输到目标内网服务器"
    err "    3. 使用 dpkg -i（Debian系）或 yum localinstall（RHEL系）本地安装"
    err "    4. sudo systemctl enable --now docker"
}

# ── 国产OS专用防火墙配置指导函数 ──
show_firewall_guide() {
    local os="$1" port="$2"
    echo ""
    info "  ──── ${B}${os} 防火墙配置指导（开放端口${port}）${N} ────"
    case "$os" in
        uos|deepin)
            info "  [UOS/Deepin - UFW防火墙]"
            info "    sudo ufw allow ${port}/tcp"
            info "    sudo ufw reload"
            info ""
            info "  [UOS/Deepin - iptables防火墙]"
            info "    sudo iptables -I INPUT -p tcp --dport ${port} -j ACCEPT"
            info "    sudo iptables-save | sudo tee /etc/iptables/rules.v4"
            ;;
        kylin)
            info "  [麒麟V10 - UFW防火墙（Ubuntu基座）]"
            info "    sudo ufw allow ${port}/tcp"
            info "    sudo ufw reload"
            info ""
            info "  [麒麟V4 - firewalld防火墙（CentOS基座）]"
            info "    sudo firewall-cmd --add-port=${port}/tcp --permanent"
            info "    sudo firewall-cmd --reload"
            info ""
            info "  [麒麟 - iptables防火墙]"
            info "    sudo iptables -I INPUT -p tcp --dport ${port} -j ACCEPT"
            ;;
        openeuler)
            info "  [openEuler - firewalld防火墙（推荐）]"
            info "    sudo firewall-cmd --add-port=${port}/tcp --permanent"
            info "    sudo firewall-cmd --reload"
            info ""
            info "  [openEuler - nftables防火墙（默认）]"
            info "    sudo nft add rule inet filter input tcp dport ${port} accept"
            info "    sudo nft list ruleset | sudo tee /etc/nftables.conf"
            info ""
            info "  [openEuler - iptables防火墙]"
            info "    sudo iptables -I INPUT -p tcp --dport ${port} -j ACCEPT"
            info "    sudo iptables-save | sudo tee /etc/sysconfig/iptables"
            ;;
        anolis|tencentos)
            info "  [Anolis/TencentOS - firewalld防火墙]"
            info "    sudo firewall-cmd --add-port=${port}/tcp --permanent"
            info "    sudo firewall-cmd --reload"
            info ""
            info "  [Anolis/TencentOS - iptables防火墙]"
            info "    sudo iptables -I INPUT -p tcp --dport ${port} -j ACCEPT"
            info "    sudo iptables-save | sudo tee /etc/sysconfig/iptables"
            ;;
    esac
}

# ── 通用依赖工具自动安装函数（首版策略）──
# 用法: try_install_tool "工具名" "Debian包名" "RHEL包名" 是否必需(true/false)
# 首版策略：缺失时先尝试从系统仓库自动安装，安装失败才中断并给出离线指导
try_install_tool() {
    local tool="$1" apt_pkg="$2" yum_pkg="$3" required="${4:-false}"
    local _installed=false

    info "正在尝试自动安装 $tool ..."
    if command -v apt-get &>/dev/null; then
        info "  尝试 apt-get install -y $apt_pkg ..."
        if apt-get install -y "$apt_pkg" 2>/dev/null; then
            _installed=true
        fi
    elif command -v yum &>/dev/null; then
        info "  尝试 yum install -y $yum_pkg ..."
        if yum install -y "$yum_pkg" 2>/dev/null; then
            _installed=true
        fi
    elif command -v dnf &>/dev/null; then
        info "  尝试 dnf install -y $yum_pkg ..."
        if dnf install -y "$yum_pkg" 2>/dev/null; then
            _installed=true
        fi
    fi

    if $_installed && command -v "$tool" &>/dev/null; then
        ok "$tool: ${B}自动安装成功${N}"
        return 0
    else
        # 安装失败——根据是否必需决定处理方式
        if $required; then
            err "$tool: ${B}自动安装失败${N}（必需工具，无法继续）"
            err "  原因：系统仓库中无安装包（纯内网无本地缓存）"
            err "  解决：使用离线安装方式（下载包→U盘传输→本地安装）"
            err ""
            if [ "$OS_FAMILY" = "rhel" ] || [ "$OS_BASE" = "centos" ]; then
                err "  [RHEL系 离线安装 $tool ($yum_pkg)]"
                err "    # 在有网机器下载RPM包："
                err "    wget https://mirrors.aliyun.com/centos/7/os/x86_64/Packages/$(rpm -q --whatprovides \$(which $tool) 2>/dev/null || echo $yum_pkg)*.rpm"
                err "    # U盘/SCP拷到目标服务器后："
                err "    sudo yum localinstall -y $yum_pkg*.rpm"
            elif [ "$OS_FAMILY" = "debian" ] || [ "$OS_BASE" = "ubuntu" ]; then
                err "  [Debian系 离线安装 $tool ($apt_pkg)]"
                err "    # 在有网机器下载DEB包："
                err "    wget https://mirrors.aliyun.com/ubuntu/pool/main/$(echo $apt_pkg | cut -c1)/$apt_pkg/*.deb"
                err "    # U盘/SCP拷到目标服务器后："
                err "    sudo dpkg -i $apt_pkg*.deb"
            else
                err "  [通用离线安装指导]"
                err "    RHEL系: 下载RPM包 → sudo yum localinstall -y *.rpm"
                err "    Debian系: 下载DEB包 → sudo dpkg -i *.deb"
                err "    下载地址: https://mirrors.aliyun.com/"
            fi
            _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
            return 1
        else
            warn "$tool: ${B}自动安装失败${N}（非必需，部分功能受限）"
            warn "  离线安装: RHEL系 yum localinstall $yum_pkg / Debian系 dpkg -i $apt_pkg"
            _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
            return 0
        fi
    fi
}

# ── 1a. 操作系统检测 ──
OS_ID="unknown"; OS_VERSION=""; OS_PRETTY=""; OS_FAMILY="unknown"
# 国产OS基座类型检测（用于选择正确的包管理器）
OS_BASE=""  # ubuntu/centos/unknown
if [ -f /etc/os-release ]; then
    OS_ID=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    # 检测国产OS基座类型
    OS_ID_LIKE=$(grep '^ID_LIKE=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
elif [ -f /etc/redhat-release ]; then
    OS_PRETTY=$(cat /etc/redhat-release 2>/dev/null)
    OS_ID="rhel"
fi
[ -z "$OS_PRETTY" ] && OS_PRETTY="$OS_ID $OS_VERSION"
ok "操作系统: ${B}$OS_PRETTY${N}"

# 判断国产OS基座
case "$OS_ID" in
    uos|deepin)            OS_BASE="ubuntu" ;;
    kylin)
        # 麒麟V10基于Ubuntu，V4基于CentOS
        if echo "$OS_PRETTY" | grep -qi "V10\|V4.*centos"; then
            if echo "$OS_PRETTY" | grep -qi "V4"; then OS_BASE="centos"; else OS_BASE="ubuntu"; fi
        elif [ -n "$OS_ID_LIKE" ] && echo "$OS_ID_LIKE" | grep -qi "ubuntu"; then
            OS_BASE="ubuntu"
        elif [ -n "$OS_ID_LIKE" ] && echo "$OS_ID_LIKE" | grep -qi "centos\|rhel\|fedora"; then
            OS_BASE="centos"
        else
            # 默认V10为Ubuntu基座
            OS_BASE="ubuntu"
        fi
        ;;
    openeuler|anolis|tencentos|tlinux)  OS_BASE="centos" ;;
esac

# 检查是否为已知兼容发行版
case "$OS_ID" in
    centos|rhel|rocky|almalinux|ol|fedora)
        OS_FAMILY="rhel"
        ok "发行版族: ${B}RHEL系${N} (CentOS/RHEL/Rocky/Alma/OL/Fedora)" ;;
    ubuntu|debian|linuxmint|pop)
        OS_FAMILY="debian"
        ok "发行版族: ${B}Debian系${N} (Ubuntu/Debian/LinuxMint/Pop)" ;;
    uos)
        OS_FAMILY="cnos"
        ok "发行版族: ${B}国产操作系统${N} (统信UOS, 基座: ${OS_BASE})"
        info "国产操作系统适配说明："
        info "  • 统信UOS Server 20/1060：基于Deepin/Debian，Docker可通过应用商店或APT安装"
        info "  • UOS 20 专业版：Docker 20.10+ 已预装"
        info "  • UOS 1060 企业版：需手动安装Docker（见下方指导）"
        info "  • 防火墙：默认UFW，部分版本使用iptables"
        info "  • 包管理器：apt-get（基座Debian）"
        ;;
    kylin)
        OS_FAMILY="cnos"
        ok "发行版族: ${B}国产操作系统${N} (银河麒麟, 基座: ${OS_BASE})"
        info "国产操作系统适配说明："
        info "  • 银河麒麟V10 SP1/SP2/SP3：基于Ubuntu 18.04/20.04，Docker安装同Ubuntu"
        info "  • 银河麒麟V4.0.2：基于CentOS 7，Docker安装同CentOS"
        info "  • 当前检测基座: ${B}${OS_BASE}${N}，将使用${OS_BASE}系包管理器"
        info "  • 防火墙：V10默认UFW，V4默认firewalld"
        ;;
    deepin)
        OS_FAMILY="cnos"
        ok "发行版族: ${B}国产操作系统${N} (深度Deepin, 基座: ${OS_BASE})"
        info "国产操作系统适配说明："
        info "  • Deepin 20/23：基于Debian，Docker可通过应用商店或APT安装"
        info "  • 防火墙：默认UFW"
        info "  • 包管理器：apt-get（基座Debian）"
        ;;
    openeuler|openeuler-host)
        OS_FAMILY="cnos"
        ok "发行版族: ${B}国产操作系统${N} (华为openEuler, 基座: ${OS_BASE})"
        info "国产操作系统适配说明："
        info "  • openEuler 20.03 LTS SP1/SP2/SP3：Docker通过yum安装"
        info "  • openEuler 22.03 LTS SP1/SP2/SP3：Docker通过yum/dnf安装"
        info "  • openEuler 24.03 LTS：Docker通过dnf安装"
        info "  • 防火墙：默认firewalld+nftables后端"
        info "  • 包管理器：yum/dnf（基座CentOS/RHEL）"
        ;;
    tencentos|tlinux)
        OS_FAMILY="cnos"
        ok "发行版族: ${B}国产操作系统${N} (TencentOS/TLinux, 基座: ${OS_BASE})"
        info "国产操作系统适配说明："
        info "  • TencentOS Server 2.4/3.1：基于CentOS/RHEL，Docker安装同CentOS"
        info "  • TLinux 2.0/3.0：腾讯内部版本，Docker已预装"
        info "  • 防火墙：默认firewalld"
        info "  • 包管理器：yum/dnf（基座CentOS/RHEL）"
        ;;
    anolis)
        OS_FAMILY="cnos"
        ok "发行版族: ${B}国产操作系统${N} (龙蜥Anolis OS, 基座: ${OS_BASE})"
        info "国产操作系统适配说明："
        info "  • Anolis OS 7.9：兼容CentOS 7.9，Docker安装同CentOS"
        info "  • Anolis OS 8.x/23：兼容CentOS 8/RHEL 8/9，Docker通过yum/dnf安装"
        info "  • 防火墙：默认firewalld"
        info "  • 包管理器：yum/dnf（基座CentOS/RHEL）"
        ;;
    arch|manjaro|gentoo)
        OS_FAMILY="arch"
        warn "发行版族: 滚动更新系 (Arch/Manjaro/Gentoo)，非官方测试环境"
        _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1)) ;;
    alpine)
        OS_FAMILY="alpine"
        warn "发行版族: Alpine Linux，部分命令可能不兼容" ;;
    *)  OS_FAMILY="unknown"
        warn "发行版族: 未知 ($OS_ID)，可能需要手动适配"
        _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1)) ;;
esac

# ── 1b. 内核版本检测 ──
KVER=$(uname -r)
KMAJOR=$(echo "$KVER" | cut -d. -f1)
KMINOR=$(echo "$KVER" | cut -d. -f2)
ok "内核版本: ${B}$KVER${N}"
if [ "$KMAJOR" -lt 3 ]; then
    err "内核版本过低 (需 ≥3.10)，当前容器支持不完整"
    _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
elif [ "$KMAJOR" -eq 3 ] && [ "$KMINOR" -lt 10 ]; then
    err "内核版本过低 (需 ≥3.10)，当前容器支持不完整"
    _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
elif [ "$KMAJOR" -eq 3 ]; then
    warn "内核 3.x 较旧，建议升级到 4.x+"
    _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
fi

# ── 1c. CPU架构检测 ──
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)  DOCKER_ARCH="amd64" ;;
    aarch64|arm64) DOCKER_ARCH="arm64" ;;
    *)  err "不支持的架构: ${B}$ARCH${N} (仅支持 x86_64/AMD64 和 ARM64/AArch64)"
        _CHECK_ERRORS=$((_CHECK_ERRORS + 1)) ;;
esac
[ -n "$DOCKER_ARCH" ] && ok "CPU架构: ${B}$ARCH${N} → Docker: ${B}linux/$DOCKER_ARCH${N}"

# ── 1d. 用户权限检测 ──
if [ "$(id -u)" -eq 0 ]; then
    ok "运行权限: ${B}root${N}"
else
    # 检查是否在docker组中
    if groups 2>/dev/null | grep -qw docker; then
        ok "运行权限: ${B}$(whoami)${N} (docker组成员)"
    else
        err "当前用户 ${B}$(whoami)${N} 无Docker权限"
        err "  解决: sudo usermod -aG docker $(whoami)  然后重新登录"
        _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
    fi
fi

# ── 1e. 磁盘空间检测 ──
# 镜像包~237MB + 运行时数据~200MB + 余量，至少需要1GB
DISK_AVAIL=$(df -BG / 2>/dev/null | awk 'NR==2{print $4}' | tr -d 'G')
if [ -n "$DISK_AVAIL" ]; then
    if [ "$DISK_AVAIL" -ge 2 ]; then
        ok "磁盘空间: ${B}${DISK_AVAIL}GB${N} 可用 (需 ≥1GB)"
    elif [ "$DISK_AVAIL" -ge 1 ]; then
        warn "磁盘空间: ${B}${DISK_AVAIL}GB${N} 可用 (偏低，建议 ≥2GB)"
        _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
    else
        err "磁盘空间: ${B}${DISK_AVAIL}GB${N} 可用 (不足1GB，无法部署)"
        _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
    fi
else
    warn "磁盘空间: 无法检测"
    _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
fi

# ── 1f. 内存检测 ──
MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
if [ -n "$MEM_TOTAL_KB" ]; then
    MEM_MB=$((MEM_TOTAL_KB / 1024))
    if [ "$MEM_MB" -ge 2048 ]; then
        ok "系统内存: ${B}${MEM_MB}MB${N} (充裕)"
    elif [ "$MEM_MB" -ge 1024 ]; then
        ok "系统内存: ${B}${MEM_MB}MB${N} (满足最低要求)"
    elif [ "$MEM_MB" -ge 512 ]; then
        warn "系统内存: ${B}${MEM_MB}MB${N} (偏低，建议 ≥1GB)"
        _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
    else
        err "系统内存: ${B}${MEM_MB}MB${N} (不足512MB，可能无法运行)"
        _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
    fi
else
    warn "系统内存: 无法检测"
    _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
fi

# ── 1g. Docker 环境检测与自动兼容安装 ──
# 首版策略：检测不通过时，先尝试从系统仓库自动安装/升级Docker，
# 安装失败才中断脚本并给出离线指导方法
_DOCKER_NEED_INSTALL=false
_DOCKER_NEED_UPGRADE=false

if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    DOCKER_MAJOR=$(echo "$DOCKER_VER" | cut -d. -f1)
    DOCKER_MINOR=$(echo "$DOCKER_VER" | cut -d. -f2)
    ok "Docker版本: ${B}$DOCKER_VER${N}"

    # 版本要求 ≥18.09（支持 overlay2, --network host, docker load/exec/cp）
    if [ "$DOCKER_MAJOR" -lt 18 ] 2>/dev/null; then
        warn "Docker版本过低 (需 ≥18.09)，当前 $DOCKER_VER，将尝试自动升级"
        _DOCKER_NEED_UPGRADE=true
    elif [ "$DOCKER_MAJOR" -eq 18 ] && [ "$DOCKER_MINOR" -lt 9 ] 2>/dev/null; then
        warn "Docker版本过低 (需 ≥18.09)，当前 $DOCKER_VER，将尝试自动升级"
        _DOCKER_NEED_UPGRADE=true
    elif [ "$DOCKER_MAJOR" -lt 20 ] 2>/dev/null; then
        info "Docker版本 $DOCKER_VER 可用（≥18.09），建议升级到 ≥20.10"
    fi
else
    warn "Docker: ${B}未安装${N}，将尝试自动安装"
    _DOCKER_NEED_INSTALL=true
fi

# ── 尝试自动安装/升级Docker ──
if $_DOCKER_NEED_INSTALL || $_DOCKER_NEED_UPGRADE; then
    info "正在尝试从系统仓库安装/升级Docker（无需联网，使用本地缓存包）..."
    _DOCKER_INSTALL_OK=false

    # 根据包管理器尝试安装
    if command -v apt-get &>/dev/null; then
        # Debian系：先尝试 docker.io（系统仓库），再尝试 docker-ce
        info "  尝试 apt-get install docker.io ..."
        if apt-get install -y docker.io 2>/dev/null; then
            _DOCKER_INSTALL_OK=true
        else
            info "  docker.io 不可用，尝试 apt-get install docker-ce ..."
            if apt-get install -y docker-ce docker-ce-cli containerd.io 2>/dev/null; then
                _DOCKER_INSTALL_OK=true
            fi
        fi
    elif command -v yum &>/dev/null; then
        # RHEL系：先尝试 docker（系统仓库），再尝试 docker-ce
        info "  尝试 yum install docker ..."
        if yum install -y docker 2>/dev/null; then
            _DOCKER_INSTALL_OK=true
        else
            info "  docker 不可用，尝试 yum install docker-ce ..."
            if yum install -y docker-ce docker-ce-cli containerd.io 2>/dev/null; then
                _DOCKER_INSTALL_OK=true
            fi
        fi
    elif command -v dnf &>/dev/null; then
        # dnf系（Fedora/openEuler 22+）
        info "  尝试 dnf install docker ..."
        if dnf install -y docker 2>/dev/null; then
            _DOCKER_INSTALL_OK=true
        else
            info "  docker 不可用，尝试 dnf install docker-ce ..."
            if dnf install -y docker-ce docker-ce-cli containerd.io 2>/dev/null; then
                _DOCKER_INSTALL_OK=true
            fi
        fi
    fi

    # 启动Docker服务
    if $_DOCKER_INSTALL_OK; then
        systemctl enable --now docker 2>/dev/null
    fi

    # 验证安装结果
    if $_DOCKER_INSTALL_OK && command -v docker &>/dev/null; then
        DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        DOCKER_MAJOR=$(echo "$DOCKER_VER" | cut -d. -f1)
        DOCKER_MINOR=$(echo "$DOCKER_VER" | cut -d. -f2)
        if [ "$DOCKER_MAJOR" -gt 18 ] 2>/dev/null || { [ "$DOCKER_MAJOR" -eq 18 ] && [ "$DOCKER_MINOR" -ge 9 ]; } 2>/dev/null; then
            ok "Docker自动安装/升级成功！版本: ${B}$DOCKER_VER${N}"
        else
            warn "Docker已安装但版本仍为 $DOCKER_VER（≥18.09即可继续）"
        fi
    else
        # 安装失败——中断脚本，给出离线指导
        err ""
        err "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        err "  ${R}${B}Docker自动安装失败！${N}"
        err "  原因：系统仓库中无Docker安装包（纯内网无本地缓存）"
        err "  解决：使用离线安装方式（下载包→U盘传输→本地安装）"
        err "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        err ""
        if [ "$OS_FAMILY" = "cnos" ]; then
            show_docker_install_guide "$OS_ID"
        elif [ "$OS_FAMILY" = "rhel" ]; then
            err "  ──── ${B}RHEL系 Docker离线安装指导${N} ────"
            err "  在有网机器下载RPM包后U盘/SCP传输到本机："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-20.10.24-3.el7.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-20.10.24-3.el7.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/containerd.io-1.6.9-3.1.el7.x86_64.rpm"
            err "    sudo yum localinstall -y containerd.io-*.rpm docker-ce-cli-*.rpm docker-ce-*.rpm"
            err "    sudo systemctl enable --now docker"
        elif [ "$OS_FAMILY" = "debian" ]; then
            err "  ──── ${B}Debian系 Docker离线安装指导${N} ────"
            err "  在有网机器下载DEB包后U盘/SCP传输到本机："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_20.10.24~3-0~ubuntu-focal_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_20.10.24~3-0~ubuntu-focal_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.6.9-1_amd64.deb"
            err "    sudo dpkg -i containerd.io_*.deb docker-ce-cli_*.deb docker-ce_*.deb"
            err "    sudo systemctl enable --now docker"
        else
            err "  ──── ${B}通用离线安装指导${N} ────"
            err "  在有网机器下载安装包：https://mirrors.aliyun.com/docker-ce/linux/"
            err "  RHEL系: sudo yum localinstall -y *.rpm"
            err "  Debian系: sudo dpkg -i *.deb"
        fi
        _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
    fi
fi

# ── Docker已安装，继续检测服务状态 ──
if command -v docker &>/dev/null; then
    # Docker 服务状态
    if docker info &>/dev/null; then
        ok "Docker服务: ${B}运行中${N}"
    else
        warn "Docker服务: ${B}未运行${N}，尝试自动启动..."
        if systemctl start docker 2>/dev/null && sleep 2 && docker info &>/dev/null; then
            ok "Docker服务: ${B}已自动启动${N}"
            systemctl enable docker 2>/dev/null
        else
            err "Docker服务启动失败！"
            err "  原因可能是：Docker未正确安装、端口冲突、或权限不足"
            err "  排查命令："
            err "    systemctl status docker    # 查看服务状态"
            err "    journalctl -u docker -n 50  # 查看启动日志"
            _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
        fi
    fi

    # Docker 存储驱动
    STORAGE_DRIVER=$(docker info 2>/dev/null | grep 'Storage Driver' | awk '{print $3}')
    if [ -n "$STORAGE_DRIVER" ]; then
        if [ "$STORAGE_DRIVER" = "overlay2" ]; then
            ok "存储驱动: ${B}$STORAGE_DRIVER${N} (推荐)"
        elif [ "$STORAGE_DRIVER" = "devicemapper" ]; then
            warn "存储驱动: ${B}$STORAGE_DRIVER${N} (性能较差，建议切换到overlay2)"
            _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
        else
            ok "存储驱动: ${B}$STORAGE_DRIVER${N}"
        fi
    fi

    # Docker Compose 检测（可选，不强制）
    if command -v docker-compose &>/dev/null; then
        ok "Docker Compose: ${B}$(docker-compose --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)${N} (可选)"
    elif docker compose version &>/dev/null 2>&1; then
        ok "Docker Compose: ${B}$(docker compose version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)${N} (插件版, 可选)"
    else
        info "Docker Compose: 未安装 (可选，本脚本不依赖)"
    fi
else
    err "Docker: ${B}未安装${N}"
    # 根据检测到的操作系统类型，给出精准安装指导
    case "$OS_FAMILY" in
        cnos)
            # 国产操作系统：使用专用安装指导函数
            show_docker_install_guide "$OS_ID"
            ;;
        rhel)
            err ""
            err "  ──── ${B}RHEL系 Docker离线安装指导${N} ────"
            err "  （纯内网环境，需在有网机器下载RPM包后U盘/SCP传输）"
            err "  [CentOS 7/RHEL 7 - 离线RPM包]"
            err "    # 在有网机器下载："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-20.10.24-3.el7.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-20.10.24-3.el7.x86_64.rpm"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/containerd.io-1.6.9-3.1.el7.x86_64.rpm"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo yum localinstall -y containerd.io-*.rpm docker-ce-cli-*.rpm docker-ce-*.rpm"
            err "    sudo systemctl enable --now docker"
            err ""
            err "  [CentOS 8/Rocky/Alma - 离线RPM包]"
            err "    # 同上，将路径中 7 改为 8，el7 改为 el8"
            ;;
        debian)
            err ""
            err "  ──── ${B}Debian系 Docker离线安装指导${N} ────"
            err "  （纯内网环境，需在有网机器下载DEB包后U盘/SCP传输）"
            err "  [Ubuntu 20.04 - 离线DEB包]"
            err "    # 在有网机器下载："
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_20.10.24~3-0~ubuntu-focal_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_20.10.24~3-0~ubuntu-focal_amd64.deb"
            err "    wget https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.6.9-1_amd64.deb"
            err "    # U盘/SCP拷到目标服务器后："
            err "    sudo dpkg -i containerd.io_*.deb docker-ce-cli_*.deb docker-ce_*.deb"
            err "    sudo systemctl enable --now docker"
            ;;
        *)
            err ""
            err "  ──── ${B}Docker通用离线安装指导${N} ────"
            err "  （纯内网环境，需在有网机器下载安装包后U盘/SCP传输）"
            err "  [RHEL系] 下载RPM包 → sudo yum localinstall -y *.rpm"
            err "  [Debian系] 下载DEB包 → sudo dpkg -i *.deb"
            err "  下载地址: https://mirrors.aliyun.com/docker-ce/linux/"
            ;;
    esac
    _CHECK_ERRORS=$((_CHECK_ERRORS + 1))
fi

# ── 1h. 依赖工具检测（首版策略：缺失时先尝试自动安装，失败才中断+离线指导）──
# curl: 服务就绪检测（非必需，缺失时部分功能受限）
if command -v curl &>/dev/null; then
    ok "curl: ${B}$(curl --version 2>/dev/null | head -1 | awk '{print $2}')${N}"
else
    warn "curl: ${B}未安装${N} (用于服务就绪检测，非必需)"
    try_install_tool "curl" "curl" "curl" false
fi

# ip: 网卡/IP检测（必需，缺失时无法进行网络配置）
if command -v ip &>/dev/null; then
    ok "ip命令: ${B}可用${N}"
else
    err "ip命令: ${B}未安装${N} (必需，用于网卡/IP检测)"
    try_install_tool "ip" "iproute2" "iproute" true
fi

# ss/netstat: 端口检测（至少一个，非必需但建议有）
if command -v ss &>/dev/null; then
    ok "ss命令: ${B}可用${N} (端口检测)"
elif command -v netstat &>/dev/null; then
    ok "netstat命令: ${B}可用${N} (端口检测, ss更优)"
    warn "  建议安装ss: sudo yum install -y iproute  或  sudo apt-get install -y iproute2"
else
    warn "ss/netstat: ${B}均未安装${N} (端口冲突检测将跳过)"
    # 尝试安装 iproute（提供ss命令）
    _SS_INSTALLED=false
    if command -v apt-get &>/dev/null; then
        info "  尝试 apt-get install -y iproute2 ..."
        if apt-get install -y iproute2 2>/dev/null && command -v ss &>/dev/null; then
            ok "ss: ${B}自动安装成功${N}"
            _SS_INSTALLED=true
        fi
    elif command -v yum &>/dev/null; then
        info "  尝试 yum install -y iproute ..."
        if yum install -y iproute 2>/dev/null && command -v ss &>/dev/null; then
            ok "ss: ${B}自动安装成功${N}"
            _SS_INSTALLED=true
        fi
    elif command -v dnf &>/dev/null; then
        info "  尝试 dnf install -y iproute ..."
        if dnf install -y iproute 2>/dev/null && command -v ss &>/dev/null; then
            ok "ss: ${B}自动安装成功${N}"
            _SS_INSTALLED=true
        fi
    fi
    if ! $_SS_INSTALLED; then
        warn "ss自动安装失败（非必需，端口冲突检测将跳过）"
        info "  离线安装: RHEL系 yum localinstall iproute / Debian系 dpkg -i iproute2"
        _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1))
    fi
fi

# awk: 数据处理（必需，缺失时脚本无法正常运行）
if command -v awk &>/dev/null; then
    ok "awk: ${B}可用${N}"
else
    err "awk: ${B}未安装${N} (必需，用于数据处理)"
    try_install_tool "awk" "gawk" "gawk" true
fi

# ── 1i. 安全策略检测 ──
# SELinux
if command -v getenforce &>/dev/null; then
    SELINUX_MODE=$(getenforce 2>/dev/null)
    case "$SELINUX_MODE" in
        Enforcing)
            warn "SELinux: ${B}Enforcing${N} (可能阻止容器运行，建议设为Permissive或关闭)"
            warn "  临时关闭: sudo setenforce 0"
            warn "  永久关闭: 编辑 /etc/selinux/config → SELINUX=permissive"
            _CHECK_WARNINGS=$((_CHECK_WARNINGS + 1)) ;;
        Permissive)
            ok "SELinux: ${B}Permissive${N} (不阻止，仅记录)" ;;
        Disabled)
            ok "SELinux: ${B}Disabled${N}" ;;
        *)  ok "SELinux: $SELINUX_MODE" ;;
    esac
fi

# AppArmor (Debian/Ubuntu系)
if [ -d /etc/apparmor.d ] 2>/dev/null; then
    AA_STATUS=$(aa-status 2>/dev/null | head -1)
    if [ -n "$AA_STATUS" ]; then
        ok "AppArmor: ${B}运行中${N}"
    else
        ok "AppArmor: ${B}已安装${N} (状态未知，通常不阻止Docker)"
    fi
fi

# ── 1j. 已有容器冲突检测 ──
if command -v docker &>/dev/null && docker info &>/dev/null; then
    if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' 2>/dev/null | grep -q .; then
        OLD_STATUS=$(docker inspect "$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null)
        warn "同名容器: ${B}$CONTAINER_NAME${N} 已存在 (状态: $OLD_STATUS)"
        info "  部署时将自动停止并替换旧容器"
    fi
fi

# ── 1k. 防火墙工具检测 ──
_FIREWALL_TOOLS=""
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null 2>&1; then
    ok "防火墙: ${B}firewalld${N} (运行中，部署时将自动开放端口)"
    _FIREWALL_TOOLS="firewalld"
elif command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -qi "active"; then
    ok "防火墙: ${B}UFW${N} (运行中，部署时将自动开放端口)"
    _FIREWALL_TOOLS="ufw"
elif command -v nft &>/dev/null && nft list ruleset 2>/dev/null | grep -q "chain input"; then
    ok "防火墙: ${B}nftables${N} (运行中，部署时将自动开放端口)"
    _FIREWALL_TOOLS="nftables"
elif command -v iptables &>/dev/null; then
    ok "防火墙: ${B}iptables${N} (部署时将尝试开放端口)"
    _FIREWALL_TOOLS="iptables"
else
    info "防火墙: 未检测到活跃防火墙 (端口可能已开放)"
fi

# ── 检测结果汇总 ──
echo ""
sep
if [ "$_CHECK_ERRORS" -eq 0 ] && [ "$_CHECK_WARNINGS" -eq 0 ]; then
    ok "环境检测: ${B}全部通过${N} ✓"
elif [ "$_CHECK_ERRORS" -eq 0 ]; then
    warn "环境检测: ${B}${_CHECK_WARNINGS}个警告${N} (可继续部署，但建议关注)"
    echo ""
    read -p "  是否忽略警告继续？ [Y/n]: " -r _IGNORE_WARN
    case "${_IGNORE_WARN^^}" in N|NO) warn "部署已取消"; exit 0 ;; esac
else
    err "环境检测: ${B}${_CHECK_ERRORS}个致命错误${N} + ${_CHECK_WARNINGS}个警告"
    err "请修复以上致命错误后重新运行部署脚本"
    exit 1
fi
sep

# ============================================================
# 2. 网卡/IP检测与选择
# ============================================================
title "2/7 网络配置"

DEFAULT_IFACE=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}' || echo "")
DEFAULT_IP=""
[ -n "$DEFAULT_IFACE" ] && DEFAULT_IP=$(ip -4 addr show "$DEFAULT_IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)

declare -a IFACES=() IPS=()
while IFS= read -r line; do
    iface=$(echo "$line" | awk -F': ' '{print $2}')
    [[ "$iface" == lo* || "$iface" == docker* || "$iface" == br-* || "$iface" == veth* ]] && continue
    ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
    [ -z "$ip_addr" ] && continue
    IFACES+=("$iface"); IPS+=("$ip_addr")
done < <(ip -o link show 2>/dev/null)

[ ${#IFACES[@]} -eq 0 ] && { err "未检测到可用网卡！"; exit 1; }

info "检测到以下网卡:"
echo ""
for i in "${!IFACES[@]}"; do
    idx=$((i + 1))
    if [ "${IFACES[$i]}" = "$DEFAULT_IFACE" ]; then
        echo -e "    ${G}${B}[$idx]${N}  ${B}${IFACES[$i]}${N}  ${G}${IPS[$i]}${N}  ${D}(默认网关)${N}"
    else
        echo -e "    ${D}[$idx]${N}  ${IFACES[$i]}  ${IPS[$i]}"
    fi
done
echo ""

DEFAULT_IDX=1
for i in "${!IFACES[@]}"; do
    [ "${IFACES[$i]}" = "$DEFAULT_IFACE" ] && DEFAULT_IDX=$((i + 1)) && break
done

prompt "选择网卡序号" "$DEFAULT_IDX"
SELECTED_IDX=$_ANSWER
# 容错：非数字输入回退到默认
if ! [[ "$SELECTED_IDX" =~ ^[0-9]+$ ]] || [ "$SELECTED_IDX" -lt 1 ] || [ "$SELECTED_IDX" -gt "${#IFACES[@]}" ]; then
    warn "输入无效，使用默认: $DEFAULT_IDX"
    SELECTED_IDX=$DEFAULT_IDX
fi
SELECTED_IFACE="${IFACES[$((SELECTED_IDX - 1))]}"
SELECTED_IP="${IPS[$((SELECTED_IDX - 1))]}"
ok "选择: ${B}$SELECTED_IFACE${N} → ${B}$SELECTED_IP${N}"

# ============================================================
# 3. 端口冲突检测与选择
# ============================================================
title "3/7 端口配置"

check_port() {
    local port=$1
    # 兼容不同系统: 优先ss，回退netstat
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":${port} " && return 1
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":${port} " && return 1
    fi
    return 0
}

find_available_port() {
    local port=$1
    while [ $port -lt 65536 ]; do
        check_port $port && echo $port && return
        port=$((port + 1))
    done
}

if check_port $DEFAULT_PORT; then
    ok "默认端口 ${B}$DEFAULT_PORT${N} 可用"
    SELECTED_PORT=$DEFAULT_PORT
else
    # 兼容不同系统检测端口占用
    if command -v ss &>/dev/null; then
        OCCUPIED_BY=$(ss -tlnp 2>/dev/null | grep ":${DEFAULT_PORT} " | head -1)
    else
        OCCUPIED_BY=$(netstat -tlnp 2>/dev/null | grep ":${DEFAULT_PORT} " | head -1)
    fi
    warn "端口 ${B}$DEFAULT_PORT${N} 已被占用"
    RECOMMENDED=$(find_available_port $((DEFAULT_PORT + 1)))
    [ -n "$RECOMMENDED" ] && info "推荐可用端口: ${G}$RECOMMENDED${N}"
    echo ""
    echo -e "  ${B}端口选择:${N}"
    echo -e "    ${D}[1]${N}  使用推荐端口: ${G}$RECOMMENDED${N}"
    echo -e "    ${D}[2]${N}  自定义端口"
    echo ""
    prompt "选择" "1"
    case "$_ANSWER" in
        2) while true; do
               prompt "输入端口号 (1024-65535)" "$RECOMMENDED"
               SELECTED_PORT=$_ANSWER
               if [[ "$SELECTED_PORT" =~ ^[0-9]+$ ]] && [ "$SELECTED_PORT" -ge 1024 ] && [ "$SELECTED_PORT" -le 65535 ] && check_port $SELECTED_PORT; then break; fi
               warn "端口无效或已被占用，请重新输入"
           done ;;
        *) SELECTED_PORT=${RECOMMENDED:-$DEFAULT_PORT} ;;
    esac
fi
ok "服务端口: ${B}$SELECTED_PORT${N}"

# ============================================================
# 4. 持久化目录配置
# ============================================================
title "4/7 持久化目录配置"

DEFAULT_DATA_DIR="$(pwd)/xt-ops-speedtest-data"

echo -e "  ${D}数据库文件将持久化到该目录，容器重建后数据不丢失${N}"
echo ""
echo -e "  ${B}持久化方式:${N}"
echo -e "    ${D}[1]${N}  宿主机目录挂载 (推荐，数据直接可见可备份)"
echo -e "    ${D}[2]${N}  Docker命名卷 (数据由Docker管理，路径较深)"
echo ""

prompt "选择持久化方式" "1"
PERSIST_MODE=$_ANSWER

if [ "$PERSIST_MODE" = "2" ]; then
    DATA_DIR=""
    VOLUME_ARG="mysql_data:/var/lib/mysql"
    ok "持久化方式: ${B}Docker命名卷${N} (mysql_data)"
else
    prompt "持久化目录" "$DEFAULT_DATA_DIR"
    DATA_DIR=$_ANSWER
    [ -z "$DATA_DIR" ] && DATA_DIR="$DEFAULT_DATA_DIR"
    mkdir -p "$DATA_DIR" 2>/dev/null || { warn "无法创建目录，回退到Docker命名卷"; DATA_DIR=""; VOLUME_ARG="mysql_data:/var/lib/mysql"; }
    if [ -n "$DATA_DIR" ]; then
        VOLUME_ARG="${DATA_DIR}:/var/lib/mysql"
        ok "持久化方式: ${B}宿主机目录${N} → ${B}$DATA_DIR${N}"
    fi
fi

# ============================================================
# 5. 站点配置
# ============================================================
title "5/7 站点配置"

prompt "站点标题" "宽带测试"
SITE_TITLE=$_ANSWER

prompt "站点图标 (Emoji)" "🚀"
FAVICON_EMOJI=$_ANSWER

prompt "服务器位置 (如: 3楼机房A)" "XXX数据中心测速服务器01"
SERVER_LOCATION=$_ANSWER

ok "标题: ${B}$SITE_TITLE${N}  图标: ${B}$FAVICON_EMOJI${N}  位置: ${B}${SERVER_LOCATION:-(未设置)}${N}"

# ============================================================
# 6. 管理后台配置
# ============================================================
title "6/7 管理后台配置"

echo -e "  ${D}触发方式: CapsLock+X → T → O → P → S → 9 → 9${N}"
echo ""

prompt "超级管理员用户名" "admin"
ADMIN_USERNAME=$_ANSWER

echo -e "  ${Y}⚠ 密码要求: 至少8位，含大小写字母+数字${N}"
prompt "超级管理员密码" "xtops@2026"
ADMIN_PASSWORD=$_ANSWER

echo ""
echo -e "  ${D}留空=全部允许，多个IP用逗号分隔，如: 192.168.1.0/24,10.0.0.100${N}"
prompt "管理后台IP白名单" ""
ADMIN_IP_WHITELIST=$_ANSWER

ok "管理员: ${B}$ADMIN_USERNAME${N}  密码: ${B}$ADMIN_PASSWORD${N}  白名单: ${B}${ADMIN_IP_WHITELIST:-(全部允许)}${N}"

# ============================================================
# 7. 确认与部署
# ============================================================
title "7/7 部署确认"

sep
echo -e "  ${B}镜像包:${N}       $IMAGE_PKG"
echo -e "  ${B}系统架构:${N}     linux/$DOCKER_ARCH"
echo -e "  ${B}服务地址:${N}     ${G}https://${SELECTED_IP}:${SELECTED_PORT}${N}"
if [ -n "$DATA_DIR" ]; then
    echo -e "  ${B}持久化目录:${N}   ${B}$DATA_DIR${N} (宿主机挂载)"
else
    echo -e "  ${B}持久化目录:${N}   Docker命名卷 mysql_data"
fi
echo -e "  ${B}站点标题:${N}     $SITE_TITLE"
echo -e "  ${B}站点图标:${N}     $FAVICON_EMOJI"
echo -e "  ${B}服务器位置:${N}   ${SERVER_LOCATION:-(未设置)}"
echo -e "  ${B}管理员:${N}       $ADMIN_USERNAME / $ADMIN_PASSWORD"
echo -e "  ${B}IP白名单:${N}     ${ADMIN_IP_WHITELIST:-(全部允许)}"
sep
echo ""

confirm "确认部署？" || { warn "部署已取消"; exit 0; }

# ============================================================
# 执行部署
# ============================================================
echo ""; title "正在部署..."

# ── 查找镜像包（自动搜索多个路径）──
IMAGE_PATH=""
SEARCH_PATHS=(
    "$IMAGE_PKG"
    "./$IMAGE_PKG"
    "DELIVERY/$IMAGE_PKG"
    "../DELIVERY/$IMAGE_PKG"
    "/opt/$IMAGE_PKG"
    "/opt/DELIVERY/$IMAGE_PKG"
    "$(dirname "$0")/$IMAGE_PKG"
    "$(dirname "$0")/DELIVERY/$IMAGE_PKG"
)
for p in "${SEARCH_PATHS[@]}"; do
    if [ -f "$p" ]; then
        IMAGE_PATH="$p"
        break
    fi
done

# 加载镜像
if [ -n "$IMAGE_PATH" ]; then
    info "加载镜像包: $IMAGE_PATH"
    docker load -i "$IMAGE_PATH"
    ok "镜像加载完成"
elif docker images "$IMAGE_TAG" --format '{{.ID}}' 2>/dev/null | grep -q .; then
    ok "镜像已存在，跳过加载"
else
    err "镜像包 $IMAGE_PKG 未找到！"
    info "已搜索路径: 当前目录, DELIVERY/, /opt/, 脚本同目录"
    err "请将镜像包放到以上任一位置后重试"
    exit 1
fi

# 创建统一标签（根据架构选择正确的源tag）
# 镜像tag格式：AMD64=v202609300000, ARM64=arm64-v202609300000
case "$DOCKER_ARCH" in
    amd64)
        # AMD64镜像tag就是 v202609300000，无需重新tag
        if docker images "xt-ops-speedtest:v202609300000" --format '{{.ID}}' 2>/dev/null | grep -q .; then
            ok "架构标签: $IMAGE_TAG → amd64 (已就绪)"
        else
            err "AMD64镜像未找到！请确认镜像包完整"
            exit 1
        fi
        ;;
    arm64)
        # ARM64镜像tag是 arm64-v202609300000，需要重新tag为统一标签
        if docker images "xt-ops-speedtest:arm64-v202609300000" --format '{{.ID}}' 2>/dev/null | grep -q .; then
            docker tag "xt-ops-speedtest:arm64-v202609300000" "$IMAGE_TAG" 2>/dev/null
            ok "架构标签: xt-ops-speedtest:arm64-v202609300000 → $IMAGE_TAG (arm64)"
        else
            err "ARM64镜像未找到！请确认镜像包完整"
            exit 1
        fi
        ;;
esac

# ── 清理无用架构镜像（节省磁盘）──
case "$DOCKER_ARCH" in
    amd64)
        # 清理ARM64镜像
        for _rm_tag in "xt-ops-speedtest:arm64-v202609300000" "xt-ops-speedtest:latest-arm64"; do
            if docker images "$_rm_tag" --format '{{.ID}}' 2>/dev/null | grep -q .; then
                info "清理非本机架构镜像 (arm64: $_rm_tag)..."
                docker rmi "$_rm_tag" 2>/dev/null || true
            fi
        done
        ok "已释放 arm64 镜像空间"
        ;;
    arm64)
        # 清理AMD64镜像（按image ID删除，因为v202609300000已被重新tag到ARM64）
        _AMD64_ID=$(docker images "xt-ops-speedtest:v202609300000" --format '{{.ID}}' 2>/dev/null | head -1)
        _ARM64_ID=$(docker images "xt-ops-speedtest:arm64-v202609300000" --format '{{.ID}}' 2>/dev/null | head -1)
        if [ -n "$_AMD64_ID" ] && [ "$_AMD64_ID" != "$_ARM64_ID" ]; then
            info "清理非本机架构镜像 (amd64)..."
            docker rmi "$_AMD64_ID" 2>/dev/null || true
            ok "已释放 amd64 镜像空间"
        fi
        ;;
esac

# 停止旧容器
if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    info "停止旧容器..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# 构建运行参数（不传中文/emoji环境变量，避免编码乱码）
RUN_ARGS=(
    -d --name "$CONTAINER_NAME" --network host
    -v "$VOLUME_ARG"
    -e "MYSQL_ROOT_PASSWORD=${ADMIN_PASSWORD}"
    -e "STATS_PASSWORD=${ADMIN_PASSWORD}"
    -e "ADMIN_USERNAME=${ADMIN_USERNAME}"
)
[ -n "$ADMIN_IP_WHITELIST" ] && RUN_ARGS+=(-e "ADMIN_IP_WHITELIST=${ADMIN_IP_WHITELIST}")

# 启动容器
info "启动容器..."
docker run "${RUN_ARGS[@]}" "$IMAGE_TAG"

# 端口适配（非8009时修改nginx配置）
if [ "$SELECTED_PORT" != "$DEFAULT_PORT" ]; then
    sleep 2
    info "适配端口 $SELECTED_PORT..."
    docker exec "$CONTAINER_NAME" sed -i "s/listen 8009 ssl/listen $SELECTED_PORT ssl/g" /etc/nginx/nginx.conf
    docker exec "$CONTAINER_NAME" sed -i "s/listen 8009/listen $SELECTED_PORT/g" /etc/nginx/nginx.conf 2>/dev/null || true
    docker exec "$CONTAINER_NAME" nginx -s reload 2>/dev/null || true
    ok "端口已适配: $SELECTED_PORT"
fi

# 等待服务就绪
info "等待服务启动..."
for i in $(seq 1 30); do
    if curl -sk "https://127.0.0.1:${SELECTED_PORT}/" -o /dev/null 2>/dev/null; then
        ok "服务就绪！(耗时 ${i}s)"; break
    fi
    sleep 1
done

# ── 写入站点配置到数据库（避免Docker -e传中文/emoji乱码）──
info "写入站点配置..."
# [修复] 使用 --default-character-set=utf8mb4 确保中文/emoji正确写入数据库
docker exec "$CONTAINER_NAME" mysql --default-character-set=utf8mb4 -u root -p"${ADMIN_PASSWORD}" xtops_speedtest -e "
    REPLACE INTO speedtest_settings (key_name, value, description) VALUES
    ('site_title', '${SITE_TITLE}', '站点标题'),
    ('favicon_emoji', '${FAVICON_EMOJI}', '站点图标Emoji'),
    ('server_location', '${SERVER_LOCATION}', '服务器位置标识');
" 2>/dev/null
ok "站点配置已写入: 标题=${SITE_TITLE}, 位置=${SERVER_LOCATION:-(未设置)}"

# ── 防火墙配置（自动检测并开放端口）──
FIREWALL_OK=false
# 1. firewalld（RHEL系/openEuler/Anolis/TencentOS/麒麟V4）
if command -v firewall-cmd &>/dev/null; then
    if systemctl is-active firewalld &>/dev/null; then
        if ! firewall-cmd --list-ports 2>/dev/null | grep -q "${SELECTED_PORT}/tcp"; then
            info "检测到 firewalld，开放端口 ${SELECTED_PORT}/tcp..."
            firewall-cmd --add-port=${SELECTED_PORT}/tcp --permanent 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            ok "firewalld: 端口 ${SELECTED_PORT}/tcp 已开放"
        else
            ok "firewalld: 端口 ${SELECTED_PORT}/tcp 已开放"
        fi
        FIREWALL_OK=true
    fi
fi
# 2. UFW（Ubuntu系/UOS/Deepin/麒麟V10）
if ! $FIREWALL_OK && command -v ufw &>/dev/null; then
    if ufw status 2>/dev/null | grep -qi "active"; then
        if ! ufw status 2>/dev/null | grep -q "${SELECTED_PORT}/tcp"; then
            info "检测到 UFW，开放端口 ${SELECTED_PORT}/tcp..."
            ufw allow ${SELECTED_PORT}/tcp 2>/dev/null
            ok "UFW: 端口 ${SELECTED_PORT}/tcp 已开放"
        else
            ok "UFW: 端口 ${SELECTED_PORT}/tcp 已开放"
        fi
        FIREWALL_OK=true
    fi
fi
# 3. nftables（openEuler默认后端）
if ! $FIREWALL_OK && command -v nft &>/dev/null; then
    if nft list ruleset 2>/dev/null | grep -q "chain input"; then
        if ! nft list ruleset 2>/dev/null | grep -q "dport ${SELECTED_PORT}"; then
            info "检测到 nftables，开放端口 ${SELECTED_PORT}/tcp..."
            nft add rule inet filter input tcp dport ${SELECTED_PORT} accept 2>/dev/null
            ok "nftables: 端口 ${SELECTED_PORT}/tcp 已开放"
        else
            ok "nftables: 端口 ${SELECTED_PORT}/tcp 已开放"
        fi
        FIREWALL_OK=true
    fi
fi
# 4. iptables（通用回退）
if ! $FIREWALL_OK && command -v iptables &>/dev/null; then
    if ! iptables -L INPUT -n 2>/dev/null | grep -q "${SELECTED_PORT}"; then
        info "检测到 iptables，开放端口 ${SELECTED_PORT}..."
        iptables -I INPUT -p tcp --dport ${SELECTED_PORT} -j ACCEPT 2>/dev/null
        ok "iptables: 端口 ${SELECTED_PORT} 已开放"
    fi
    FIREWALL_OK=true
fi

# ── 验证外部可达性 ──
sleep 1
if curl -sk "https://${SELECTED_IP}:${SELECTED_PORT}/" -o /dev/null 2>/dev/null; then
    ok "外部访问验证: ${SELECTED_IP}:${SELECTED_PORT} ✓"
else
    warn "外部访问验证: ${SELECTED_IP}:${SELECTED_PORT} 未响应"
    warn "请检查防火墙是否放行了端口 ${SELECTED_PORT}/tcp"
    # 根据OS类型给出精准防火墙指导
    if [ "$OS_FAMILY" = "cnos" ]; then
        show_firewall_guide "$OS_ID" "$SELECTED_PORT"
    else
        info "手动开放命令:"
        info "  firewall-cmd --add-port=${SELECTED_PORT}/tcp --permanent && firewall-cmd --reload"
        info "  或: ufw allow ${SELECTED_PORT}/tcp"
        info "  或: iptables -I INPUT -p tcp --dport ${SELECTED_PORT} -j ACCEPT"
    fi
fi

# ============================================================
# 部署完成
# ============================================================
echo ""
echo -e "  ${G}${B}╔══════════════════════════════════════════════╗${N}"
echo -e "  ${G}${B}║${N}  ${B}部署完成！${N}                                   ${G}${B}║${N}"
echo -e "  ${G}${B}╚══════════════════════════════════════════════╝${N}"
echo ""
echo -e "  ${B}访问地址:${N}     ${G}https://${SELECTED_IP}:${SELECTED_PORT}${N}"
echo -e "  ${B}运行架构:${N}     linux/$DOCKER_ARCH"
if [ -n "$DATA_DIR" ]; then
    echo -e "  ${B}持久化目录:${N}   ${B}$DATA_DIR${N}"
else
    echo -e "  ${B}持久化目录:${N}   Docker命名卷 mysql_data"
fi
echo -e "  ${B}站点标题:${N}     $SITE_TITLE"
echo ""
echo -e "  ${B}[管理后台]${N}"
echo -e "  触发方式:     ${D}CapsLock+X → T → O → P → S → 9 → 9${N}"
echo -e "  超级管理员:   ${B}$ADMIN_USERNAME${N}"
echo -e "  管理员密码:   ${B}$ADMIN_PASSWORD${N}"
[ -n "$ADMIN_IP_WHITELIST" ] && echo -e "  IP白名单:     $ADMIN_IP_WHITELIST"
echo ""
echo -e "  ${B}[常用命令]${N}"
echo -e "  查看日志:     ${D}docker logs $CONTAINER_NAME${N}"
echo -e "  停止服务:     ${D}docker stop $CONTAINER_NAME${N}"
echo -e "  重启服务:     ${D}docker restart $CONTAINER_NAME${N}"
if [ -n "$DATA_DIR" ]; then
    echo -e "  数据备份:     ${D}tar czf xtops-backup.tar.gz $DATA_DIR${N}"
    echo -e "  危险-重置:    ${D}docker rm -f $CONTAINER_NAME && rm -rf $DATA_DIR${N}"
else
    echo -e "  危险-重置:    ${D}docker rm -f $CONTAINER_NAME && docker volume rm mysql_data${N}"
fi
echo ""
