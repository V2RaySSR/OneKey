#!/usr/bin/env bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_VERSION="2026.04.21"
SUPPORTED_TEXT="Ubuntu / Debian 10 / 11 / 12 / CentOS 7 / CentOS Stream 8 / Rocky / AlmaLinux / Oracle Linux"

log() {
  printf "${BLUE}[INFO]${NC} %s\n" "$*"
}

ok() {
  printf "${GREEN}[OK]${NC} %s\n" "$*"
}

warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$*"
}

err() {
  printf "${RED}[ERROR]${NC} %s\n" "$*"
}

print_line() {
  printf '%s\n' "------------------------------------------------------------"
}

print_header() {
  clear
  printf "${GREEN}==================== Linux 防火墙管理脚本 ====================${NC}\n"
  printf "${BLUE} 脚本版本：%s${NC}\n" "${SCRIPT_VERSION}"
  printf "${BLUE} 本脚本支持：%s${NC}\n" "${SUPPORTED_TEXT}"
  printf "${BLUE} 原创：www.v2rayssr.com （已开启禁止国内访问）${NC}\n"
  printf "${BLUE} YouTube频道：波仔分享${NC}\n"
  printf "${BLUE} 本脚本禁止在国内任何网站转载${NC}\n"
  printf "${GREEN}=============================================================${NC}\n"
}

pause() {
  print_line
  read -rp "按 Enter 回到主菜单..."
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "请使用 root 用户运行本脚本。"
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

has_systemctl() {
  command_exists systemctl
}

service_exists() {
  local svc="$1"

  if ! has_systemctl; then
    return 1
  fi

  systemctl status "$svc" >/dev/null 2>&1 && return 0
  systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"
}

service_active() {
  local svc="$1"

  if ! has_systemctl; then
    return 1
  fi

  systemctl is-active --quiet "$svc" 2>/dev/null
}

service_enabled() {
  local svc="$1"

  if ! has_systemctl; then
    return 1
  fi

  systemctl is-enabled --quiet "$svc" 2>/dev/null
}

stop_disable_service() {
  local svc="$1"
  local name="$2"

  if service_exists "$svc"; then
    log "正在停止并禁用 ${name}..."
    systemctl stop "$svc" >/dev/null 2>&1 || true
    systemctl disable "$svc" >/dev/null 2>&1 || true
    ok "${name} 已尝试停止并禁用"
  else
    warn "未检测到 ${name}，跳过"
  fi
}

detect_os() {
  OS_NAME="Unknown"
  OS_VERSION="Unknown"
  OS_PRETTY="Unknown"

  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="${ID:-Unknown}"
    OS_VERSION="${VERSION_ID:-Unknown}"
    OS_PRETTY="${PRETTY_NAME:-${OS_NAME} ${OS_VERSION}}"
  fi
}

show_system_info() {
  detect_os
  log "当前系统：${OS_PRETTY}"
  log "内核版本：$(uname -r)"
}

safe_run() {
  "$@" >/dev/null 2>&1 || true
}

show_service_brief() {
  local svc="$1"
  local name="$2"

  printf "${BLUE}%s：${NC}\n" "$name"

  if service_exists "$svc"; then
    if service_active "$svc"; then
      warn "${name} 正在运行"
    else
      ok "${name} 当前未运行"
    fi

    if service_enabled "$svc"; then
      warn "${name} 已设置开机自启"
    else
      ok "${name} 未设置开机自启"
    fi
  else
    warn "未检测到 ${name}"
  fi

  print_line
}

show_firewall_status() {
  print_header
  show_system_info
  print_line

  log "正在检测常见防火墙和安全组件状态..."
  print_line

  printf "${BLUE}UFW 状态：${NC}\n"
  if command_exists ufw; then
    ufw status verbose || true
  else
    warn "未安装 ufw"
  fi
  print_line

  show_service_brief "firewalld" "firewalld"
  show_service_brief "nftables" "nftables"
  show_service_brief "netfilter-persistent" "netfilter-persistent"
  show_service_brief "iptables" "iptables 服务"
  show_service_brief "ip6tables" "ip6tables 服务"
  show_service_brief "csf" "CSF 防火墙"
  show_service_brief "lfd" "LFD 服务"
  show_service_brief "fail2ban" "fail2ban"

  printf "${BLUE}命令检测：${NC}\n"

  if command_exists iptables; then
    ok "iptables 命令存在"
  else
    warn "iptables 命令不存在"
  fi

  if command_exists ip6tables; then
    ok "ip6tables 命令存在"
  else
    warn "ip6tables 命令不存在"
  fi

  if command_exists nft; then
    ok "nft 命令存在"
  else
    warn "nft 命令不存在"
  fi

  if command_exists csf; then
    warn "检测到 csf 命令"
  else
    ok "未检测到 csf 命令"
  fi

  pause
}

clear_iptables_rules() {
  log "正在清空 iptables / ip6tables 规则..."

  if command_exists iptables; then
    safe_run iptables -P INPUT ACCEPT
    safe_run iptables -P FORWARD ACCEPT
    safe_run iptables -P OUTPUT ACCEPT
    safe_run iptables -F
    safe_run iptables -X
    safe_run iptables -Z
    ok "IPv4 iptables 规则已尝试清空，并设置默认策略为 ACCEPT"
  else
    warn "iptables 不存在，跳过 IPv4 iptables"
  fi

  if command_exists ip6tables; then
    safe_run ip6tables -P INPUT ACCEPT
    safe_run ip6tables -P FORWARD ACCEPT
    safe_run ip6tables -P OUTPUT ACCEPT
    safe_run ip6tables -F
    safe_run ip6tables -X
    safe_run ip6tables -Z
    ok "IPv6 ip6tables 规则已尝试清空，并设置默认策略为 ACCEPT"
  else
    warn "ip6tables 不存在，跳过 IPv6 ip6tables"
  fi
}

flush_nft_rules() {
  if command_exists nft; then
    warn "即将清空 nftables 当前规则。"
    read -rp "确认清空 nftables 规则？[y/N]: " confirm_nft

    case "$confirm_nft" in
      y|Y)
        safe_run nft flush ruleset
        ok "nftables 当前规则已尝试清空"
        ;;
      *)
        warn "已跳过清空 nftables 规则"
        ;;
    esac
  else
    warn "nft 命令不存在，跳过"
  fi
}

disable_firewall() {
  print_header
  warn "即将尝试关闭常见 Linux 防火墙和部分安全组件。"
  warn "包括 ufw、firewalld、nftables、netfilter-persistent、iptables 服务、CSF/LFD。"
  warn "fail2ban 会单独询问是否关闭，因为它属于安全防护组件。"
  warn "如果你是远程 SSH 操作，请确认 SSH 端口已经在云厂商安全组放行。"
  print_line

  read -rp "确认继续关闭系统防火墙？[y/N]: " confirm
  case "$confirm" in
    y|Y)
      ;;
    *)
      warn "已取消操作。"
      pause
      return
      ;;
  esac

  print_line

  if command_exists ufw; then
    log "正在关闭 ufw..."
    safe_run ufw disable
    safe_run systemctl stop ufw
    safe_run systemctl disable ufw
    ok "ufw 已尝试关闭"
  else
    warn "未安装 ufw，跳过"
  fi

  stop_disable_service "firewalld" "firewalld"
  stop_disable_service "nftables" "nftables"
  stop_disable_service "netfilter-persistent" "netfilter-persistent"
  stop_disable_service "iptables" "iptables 服务"
  stop_disable_service "ip6tables" "ip6tables 服务"

  if command_exists csf || service_exists csf || service_exists lfd; then
    log "检测到 CSF / LFD，正在尝试关闭..."
    if command_exists csf; then
      safe_run csf -x
    fi
    safe_run systemctl stop csf
    safe_run systemctl disable csf
    safe_run systemctl stop lfd
    safe_run systemctl disable lfd
    ok "CSF / LFD 已尝试关闭"
  else
    warn "未检测到 CSF / LFD，跳过"
  fi

  print_line
  if service_exists fail2ban; then
    warn "检测到 fail2ban。它不是传统防火墙，但可能会封禁 SSH、面板或代理端口。"
    read -rp "是否停止并禁用 fail2ban？[y/N]: " disable_f2b
    case "$disable_f2b" in
      y|Y)
        stop_disable_service "fail2ban" "fail2ban"
        ;;
      *)
        warn "已保留 fail2ban"
        ;;
    esac
  else
    warn "未检测到 fail2ban，跳过"
  fi

  print_line
  read -rp "是否同时清空 iptables / ip6tables 规则？[y/N]: " clear_ipt
  case "$clear_ipt" in
    y|Y)
      clear_iptables_rules
      ;;
    *)
      warn "已跳过清空 iptables / ip6tables 规则"
      ;;
  esac

  print_line
  read -rp "是否同时清空 nftables 当前规则？[y/N]: " clear_nft
  case "$clear_nft" in
    y|Y)
      if command_exists nft; then
        safe_run nft flush ruleset
        ok "nftables 当前规则已尝试清空"
      else
        warn "nft 命令不存在，跳过"
      fi
      ;;
    *)
      warn "已跳过清空 nftables 规则"
      ;;
  esac

  print_line
  ok "防火墙关闭操作完成。"
  warn "注意：云服务器控制台安全组、防火墙策略、网络 ACL 无法通过本脚本关闭，需要在云厂商后台单独放行端口。"
  warn "如果你安装了宝塔、1Panel、aaPanel 等面板，面板自带防火墙也可能需要单独检查。"
  pause
}

validate_port() {
  local port="$1"

  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    return 1
  fi

  return 0
}

ask_port_proto() {
  read -rp "请输入端口，例如 443、8443、20000: " PORT

  if ! validate_port "$PORT"; then
    err "端口格式错误，必须是 1-65535 的数字。"
    return 1
  fi

  read -rp "请选择协议 tcp/udp/all，默认 tcp: " PROTO
  PROTO="${PROTO:-tcp}"

  if [ "$PROTO" != "tcp" ] && [ "$PROTO" != "udp" ] && [ "$PROTO" != "all" ]; then
    err "协议只能是 tcp、udp 或 all。"
    return 1
  fi

  return 0
}

open_port_ufw() {
  if command_exists ufw; then
    if [ "$PROTO" = "all" ]; then
      safe_run ufw allow "$PORT"
    else
      safe_run ufw allow "${PORT}/${PROTO}"
    fi
    ok "ufw 已尝试放行 ${PORT}/${PROTO}"
  else
    warn "未安装 ufw，跳过 ufw"
  fi
}

open_port_firewalld() {
  if service_exists firewalld || command_exists firewall-cmd; then
    if command_exists firewall-cmd; then
      if [ "$PROTO" = "all" ]; then
        safe_run firewall-cmd --permanent --add-port="${PORT}/tcp"
        safe_run firewall-cmd --permanent --add-port="${PORT}/udp"
      else
        safe_run firewall-cmd --permanent --add-port="${PORT}/${PROTO}"
      fi
      safe_run firewall-cmd --reload
      ok "firewalld 已尝试放行 ${PORT}/${PROTO} 并重载"
    else
      warn "检测到 firewalld 服务，但没有 firewall-cmd 命令"
    fi
  else
    warn "未安装 firewalld，跳过 firewalld"
  fi
}

open_port_iptables() {
  if command_exists iptables; then
    if [ "$PROTO" = "all" ]; then
      iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || safe_run iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
      iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || safe_run iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT
    else
      iptables -C INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT 2>/dev/null || safe_run iptables -I INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT
    fi
    ok "iptables 已尝试放行 ${PORT}/${PROTO}"
  else
    warn "iptables 不存在，跳过 iptables"
  fi
}

open_port_nftables() {
  if command_exists nft; then
    warn "nftables 规则结构差异较大，本脚本不自动写入 nft 端口规则。"
    warn "如系统使用 nftables 且未关闭，请手动确认 nft list ruleset。"
  fi
}

open_port() {
  print_header
  log "放行指定端口"
  print_line

  ask_port_proto || {
    pause
    return
  }

  print_line
  log "准备放行端口：${PORT}，协议：${PROTO}"

  open_port_ufw
  open_port_firewalld
  open_port_iptables
  open_port_nftables

  print_line
  ok "端口放行操作完成。"
  warn "如果是云服务器，还需要在云厂商安全组中放行 ${PORT}/${PROTO}。"
  pause
}

remove_port() {
  print_header
  log "删除指定端口放行规则"
  print_line

  ask_port_proto || {
    pause
    return
  }

  print_line
  log "准备删除端口规则：${PORT}，协议：${PROTO}"

  if command_exists ufw; then
    if [ "$PROTO" = "all" ]; then
      safe_run ufw delete allow "$PORT"
    else
      safe_run ufw delete allow "${PORT}/${PROTO}"
    fi
    ok "ufw 已尝试删除 ${PORT}/${PROTO}"
  else
    warn "未安装 ufw，跳过 ufw"
  fi

  if service_exists firewalld || command_exists firewall-cmd; then
    if command_exists firewall-cmd; then
      if [ "$PROTO" = "all" ]; then
        safe_run firewall-cmd --permanent --remove-port="${PORT}/tcp"
        safe_run firewall-cmd --permanent --remove-port="${PORT}/udp"
      else
        safe_run firewall-cmd --permanent --remove-port="${PORT}/${PROTO}"
      fi
      safe_run firewall-cmd --reload
      ok "firewalld 已尝试删除 ${PORT}/${PROTO} 并重载"
    else
      warn "检测到 firewalld 服务，但没有 firewall-cmd 命令"
    fi
  else
    warn "未安装 firewalld，跳过 firewalld"
  fi

  if command_exists iptables; then
    if [ "$PROTO" = "all" ]; then
      while iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null; do
        iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || break
      done
      while iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null; do
        iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || break
      done
    else
      while iptables -C INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT 2>/dev/null; do
        iptables -D INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT 2>/dev/null || break
      done
    fi
    ok "iptables 已尝试删除 ${PORT}/${PROTO}"
  else
    warn "iptables 不存在，跳过 iptables"
  fi

  print_line
  ok "端口规则删除操作完成。"
  warn "nftables 规则结构差异较大，如果系统使用 nftables，请手动检查 nft list ruleset。"
  pause
}

reload_firewall() {
  print_header
  log "正在尝试重载防火墙..."
  print_line

  if command_exists ufw; then
    safe_run ufw reload
    ok "ufw 已尝试 reload"
  else
    warn "未安装 ufw，跳过"
  fi

  if command_exists firewall-cmd; then
    safe_run firewall-cmd --reload
    ok "firewalld 已尝试 reload"
  else
    warn "未检测到 firewall-cmd，跳过 firewalld reload"
  fi

  if service_exists nftables; then
    safe_run systemctl reload nftables
    safe_run systemctl restart nftables
    ok "nftables 已尝试 reload/restart"
  else
    warn "未安装 nftables 服务，跳过"
  fi

  if service_exists netfilter-persistent; then
    safe_run systemctl restart netfilter-persistent
    ok "netfilter-persistent 已尝试 restart"
  else
    warn "未安装 netfilter-persistent，跳过"
  fi

  print_line
  ok "重载操作完成。"
  pause
}

show_rules() {
  print_header
  log "查看当前防火墙规则"
  print_line

  printf "${BLUE}UFW：${NC}\n"
  if command_exists ufw; then
    ufw status verbose || true
  else
    warn "未安装 ufw"
  fi

  print_line
  printf "${BLUE}firewalld：${NC}\n"
  if command_exists firewall-cmd; then
    firewall-cmd --list-all 2>/dev/null || true
  else
    warn "未安装 firewall-cmd"
  fi

  print_line
  printf "${BLUE}nftables：${NC}\n"
  if command_exists nft; then
    nft list ruleset 2>/dev/null || true
  else
    warn "未安装 nft 命令"
  fi

  print_line
  printf "${BLUE}iptables：${NC}\n"
  if command_exists iptables; then
    iptables -L -n -v 2>/dev/null || true
  else
    warn "未安装 iptables"
  fi

  print_line
  printf "${BLUE}ip6tables：${NC}\n"
  if command_exists ip6tables; then
    ip6tables -L -n -v 2>/dev/null || true
  else
    warn "未安装 ip6tables"
  fi

  pause
}

show_listening_ports() {
  print_header
  log "查看当前监听端口"
  print_line

  if command_exists ss; then
    ss -lntup
  elif command_exists netstat; then
    netstat -lntup
  else
    err "系统未找到 ss 或 netstat 命令。"
    warn "Debian / Ubuntu 可安装：apt install -y iproute2 net-tools"
    warn "CentOS / Rocky / AlmaLinux 可安装：yum install -y iproute net-tools"
  fi

  pause
}

install_basic_tools() {
  print_header
  log "安装常用网络工具：curl、wget、net-tools、dnsutils/bind-utils、iptables、nftables"
  print_line

  detect_os

  if command_exists apt; then
    apt update
    apt install -y curl wget net-tools dnsutils iptables nftables
    ok "Debian / Ubuntu 常用工具安装完成"
  elif command_exists dnf; then
    dnf makecache
    dnf install -y curl wget net-tools bind-utils iptables iptables-services nftables
    ok "dnf 系统常用工具安装完成"
  elif command_exists yum; then
    yum makecache
    yum install -y curl wget net-tools bind-utils iptables iptables-services nftables
    ok "yum 系统常用工具安装完成"
  else
    err "未识别的软件包管理器，请手动安装工具。"
  fi

  pause
}

show_cloud_security_notice() {
  print_header
  printf "${YELLOW}重要提醒：云服务器安全组说明${NC}\n"
  print_line
  printf "本脚本只能管理 VPS 系统内部的防火墙规则，例如：\n\n"
  printf "  - ufw\n"
  printf "  - firewalld\n"
  printf "  - nftables\n"
  printf "  - iptables / ip6tables\n"
  printf "  - CSF / LFD\n"
  printf "  - netfilter-persistent\n\n"
  printf "但它无法关闭云厂商控制台里的安全组、防火墙策略或网络 ACL。\n\n"
  printf "如果你使用的是以下平台，需要到对应后台单独放行端口：\n\n"
  printf "  - 搬瓦工 / BandwagonHost\n"
  printf "  - Vultr\n"
  printf "  - AWS\n"
  printf "  - GCP\n"
  printf "  - Azure\n"
  printf "  - Oracle Cloud\n"
  printf "  - 阿里云\n"
  printf "  - 腾讯云\n"
  printf "  - 其他云服务器平台\n\n"
  printf "${YELLOW}如果系统防火墙已经关闭，但端口仍然无法访问，优先检查云厂商安全组。${NC}\n"
  pause
}

show_menu() {
  print_header
  show_system_info
  print_line
  printf "${GREEN}请选择需要执行的操作：${NC}\n"
  printf "  ${BLUE}1.${NC} 检测防火墙状态\n"
  printf "  ${BLUE}2.${NC} 一键关闭常见防火墙\n"
  printf "  ${BLUE}3.${NC} 放行指定端口\n"
  printf "  ${BLUE}4.${NC} 删除指定端口放行规则\n"
  printf "  ${BLUE}5.${NC} 重载防火墙\n"
  printf "  ${BLUE}6.${NC} 查看当前防火墙规则\n"
  printf "  ${BLUE}7.${NC} 查看当前监听端口\n"
  printf "  ${BLUE}8.${NC} 一键清空 iptables / ip6tables 规则\n"
  printf "  ${BLUE}9.${NC} 安装常用网络工具\n"
  printf "  ${BLUE}10.${NC} 查看云服务器安全组提醒\n"
  printf "  ${BLUE}0.${NC} 退出脚本\n"
  print_line
}

main() {
  need_root

  while true; do
    show_menu
    read -rp "请输入选项 [0-10]: " choice

    case "$choice" in
      1)
        show_firewall_status
        ;;
      2)
        disable_firewall
        ;;
      3)
        open_port
        ;;
      4)
        remove_port
        ;;
      5)
        reload_firewall
        ;;
      6)
        show_rules
        ;;
      7)
        show_listening_ports
        ;;
      8)
        print_header
        warn "即将清空 iptables / ip6tables 规则。"
        warn "如果你使用 Docker，清空 iptables 可能影响 Docker 网络。"
        read -rp "确认继续？[y/N]: " confirm
        case "$confirm" in
          y|Y)
            clear_iptables_rules
            ok "iptables / ip6tables 清空完成。"
            ;;
          *)
            warn "已取消操作。"
            ;;
        esac
        pause
        ;;
      9)
        install_basic_tools
        ;;
      10)
        show_cloud_security_notice
        ;;
      0)
        ok "已退出脚本。"
        exit 0
        ;;
      *)
        err "无效选项，请重新输入。"
        sleep 1
        ;;
    esac
  done
}

main "$@"
