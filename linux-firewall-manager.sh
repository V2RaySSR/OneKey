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

  systemctl status "$svc" >/dev/null 2>&1 && return 0
  systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"
}

stop_disable_service() {
  local svc="$1"
  local name="$2"

  if service_exists "$svc"; then
    log "正在停止并禁用 ${name}..."
    systemctl stop "$svc" >/dev/null 2>&1 || true
    systemctl disable "$svc" >/dev/null 2>&1 || true
    ok "${name} 已尝试关闭"
  else
    warn "未检测到 ${name}，跳过"
  fi
}

clear_iptables_rules() {
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

clear_nftables_rules() {
  if command_exists nft; then
    log "正在清空 nftables 当前规则..."
    nft flush ruleset >/dev/null 2>&1 || true
    ok "nftables 当前规则已尝试清空"
  else
    warn "未检测到 nft 命令，跳过"
  fi
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

disable_csf_lfd() {
  if command_exists csf || service_exists csf || service_exists lfd; then
    log "正在关闭 CSF / LFD..."
    csf -x >/dev/null 2>&1 || true
    systemctl stop csf >/dev/null 2>&1 || true
    systemctl disable csf >/dev/null 2>&1 || true
    systemctl stop lfd >/dev/null 2>&1 || true
    systemctl disable lfd >/dev/null 2>&1 || true
    ok "CSF / LFD 已尝试关闭"
  else
    warn "未检测到 CSF / LFD，跳过"
  fi
}

main() {
  need_root
  print_header

  warn "本脚本会尝试关闭 Linux 常见系统防火墙。"
  warn "包括 ufw、firewalld、nftables、iptables、ip6tables、CSF/LFD 等。"
  warn "如果你正在使用 Docker，清空 iptables / nftables 规则可能影响 Docker 网络。"
  warn "如果你是 SSH 远程连接，请确认 SSH 端口已在云厂商安全组放行。"
  print_line

  read -rp "确认继续关闭防火墙？[y/N]: " confirm
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
  stop_disable_service "firewalld" "firewalld"
  stop_disable_service "nftables" "nftables"
  stop_disable_service "netfilter-persistent" "netfilter-persistent"
  stop_disable_service "iptables" "iptables 服务"
  stop_disable_service "ip6tables" "ip6tables 服务"
  disable_csf_lfd

  print_line
  clear_iptables_rules
  clear_nftables_rules

  print_line
  ok "系统防火墙关闭操作完成。"

  warn "重要提醒：云服务器控制台的安全组、防火墙策略、网络 ACL 无法通过本脚本关闭。"
  warn "如果端口仍然无法访问，请到云厂商后台单独放行端口。"
  warn "如果你使用宝塔、1Panel、aaPanel 等面板，也请检查面板自带防火墙。"

  print_line
  log "当前监听端口："
  if command_exists ss; then
    ss -lntp
  elif command_exists netstat; then
    netstat -lntp
  else
    warn "未检测到 ss 或 netstat，无法显示监听端口。"
  fi
}

main "$@"
