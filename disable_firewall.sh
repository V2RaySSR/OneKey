#!/usr/bin/env bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_VERSION="2026.04.21"
SUPPORTED_TEXT="Ubuntu / Debian / CentOS / CentOS Stream / Rocky / AlmaLinux / Oracle Linux"

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
  printf "${GREEN}==================== 一键关闭防火墙脚本 ====================${NC}\n"
  printf "${BLUE} 脚本版本：%s${NC}\n" "${SCRIPT_VERSION}"
  printf "${BLUE} 本脚本支持：%s${NC}\n" "${SUPPORTED_TEXT}"
  printf "${BLUE} 原创：www.v2rayssr.com （已开启禁止国内访问）${NC}\n"
  printf "${BLUE} YouTube频道：波仔分享${NC}\n"
  printf "${BLUE} 本脚本禁止在国内任何网站转载${NC}\n"
  printf "${GREEN}===========================================================${NC}\n"
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

  systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"
}

service_active() {
  local svc="$1"

  if ! has_systemctl; then
    return 1
  fi

  systemctl is-active --quiet "$svc" 2>/dev/null
}

detect_os() {
  OS_PRETTY="Unknown"

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_PRETTY="${PRETTY_NAME:-Unknown}"
  fi
}

show_system_info() {
  detect_os
  log "当前系统：${OS_PRETTY}"
  log "内核版本：$(uname -r)"
}

show_ufw_status() {
  print_line
  printf "${BLUE}UFW 状态：${NC}\n"

  if command_exists ufw; then
    ufw status 2>/dev/null || true
  else
    warn "未检测到 ufw"
  fi
}

show_firewalld_status() {
  print_line
  printf "${BLUE}firewalld 状态：${NC}\n"

  if service_exists firewalld || command_exists firewall-cmd; then
    if service_active firewalld; then
      warn "firewalld 正在运行"

      if command_exists firewall-cmd; then
        ports="$(firewall-cmd --list-ports 2>/dev/null || true)"
        services="$(firewall-cmd --list-services 2>/dev/null || true)"

        [ -n "$ports" ] && printf "已放行端口：%s\n" "$ports" || printf "已放行端口：未检测到\n"
        [ -n "$services" ] && printf "已放行服务：%s\n" "$services" || printf "已放行服务：未检测到\n"
      fi
    else
      ok "firewalld 未运行"
    fi
  else
    warn "未检测到 firewalld"
  fi
}

show_nftables_status() {
  print_line
  printf "${BLUE}nftables 状态：${NC}\n"

  if service_exists nftables; then
    if service_active nftables; then
      warn "nftables 服务正在运行"
    else
      ok "nftables 服务未运行"
    fi
  else
    warn "未检测到 nftables 服务"
  fi

  if command_exists nft; then
    rules="$(nft list ruleset 2>/dev/null || true)"

    if [ -n "$rules" ]; then
      warn "检测到 nftables 规则，显示前 40 行："
      printf "%s\n" "$rules" | sed -n '1,40p'
    else
      ok "未检测到 nftables 规则"
    fi
  else
    warn "未检测到 nft 命令"
  fi
}

show_iptables_status() {
  print_line
  printf "${BLUE}iptables 状态：${NC}\n"

  if command_exists iptables; then
    iptables -L INPUT -n --line-numbers 2>/dev/null || true
  else
    warn "未检测到 iptables"
  fi
}

show_listening_ports() {
  print_line
  printf "${BLUE}当前监听端口：${NC}\n"

  if command_exists ss; then
    ss -lntp 2>/dev/null || true
  elif command_exists netstat; then
    netstat -lntp 2>/dev/null || true
  else
    warn "未检测到 ss 或 netstat，跳过监听端口显示"
  fi
}

show_firewall_status() {
  print_header
  show_system_info
  log "正在检测当前防火墙状态..."

  show_ufw_status
  show_firewalld_status
  show_nftables_status
  show_iptables_status
  show_listening_ports
}

disable_ufw() {
  if command_exists ufw; then
    log "正在关闭 ufw..."
    ufw disable >/dev/null 2>&1 || true
    systemctl stop ufw >/dev/null 2>&1 || true
    systemctl disable ufw >/dev/null 2>&1 || true
    ok "ufw 已尝试关闭"
  else
    warn "未检测到 ufw，跳过"
  fi
}

disable_firewalld() {
  if service_exists firewalld || command_exists firewall-cmd; then
    log "正在关闭 firewalld..."
    systemctl stop firewalld >/dev/null 2>&1 || true
    systemctl disable firewalld >/dev/null 2>&1 || true
    ok "firewalld 已尝试关闭"
  else
    warn "未检测到 firewalld，跳过"
  fi
}

disable_nftables() {
  if service_exists nftables || command_exists nft; then
    log "正在关闭 nftables..."
    systemctl stop nftables >/dev/null 2>&1 || true
    systemctl disable nftables >/dev/null 2>&1 || true

    if command_exists nft; then
      nft flush ruleset >/dev/null 2>&1 || true
    fi

    ok "nftables 已尝试关闭并清空规则"
  else
    warn "未检测到 nftables，跳过"
  fi
}

clear_iptables() {
  log "正在清空 iptables / ip6tables 规则..."

  if command_exists iptables; then
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    iptables -Z 2>/dev/null || true
    ok "IPv4 iptables 规则已尝试清空"
  else
    warn "未检测到 iptables，跳过"
  fi

  if command_exists ip6tables; then
    ip6tables -P INPUT ACCEPT 2>/dev/null || true
    ip6tables -P FORWARD ACCEPT 2>/dev/null || true
    ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
    ip6tables -F 2>/dev/null || true
    ip6tables -X 2>/dev/null || true
    ip6tables -Z 2>/dev/null || true
    ok "IPv6 ip6tables 规则已尝试清空"
  else
    warn "未检测到 ip6tables，跳过"
  fi
}

disable_firewall() {
  print_line
  warn "即将关闭新系统常见防火墙：ufw、firewalld、nftables、iptables。"
  warn "如果你正在通过 SSH 连接服务器，请确认 SSH 端口已在云厂商安全组放行。"
  print_line

  read -rp "确认关闭防火墙？[y/N]: " confirm

  case "$confirm" in
    y|Y)
      ;;
    *)
      warn "已取消操作。"
      exit 0
      ;;
  esac

  print_line

  disable_ufw
  disable_firewalld
  disable_nftables
  clear_iptables

  print_line
  ok "防火墙关闭完成。"

  warn "重要提醒：云厂商安全组、防火墙策略、网络 ACL 无法通过本脚本关闭。"
  warn "如果端口仍然无法访问，请到云服务器控制台单独放行端口。"
}

main() {
  need_root
  show_firewall_status
  disable_firewall
}

main "$@"
