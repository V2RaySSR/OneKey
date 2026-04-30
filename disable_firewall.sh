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

print_safety_notice() {
  print_line
  warn "安全提示：本脚本适合新 VPS 初始化、测试环境、个人学习环境使用。"
  warn "禁止在生产环境直接运行一键关闭防火墙脚本。"
  warn "生产环境建议按需放行端口，不建议完全关闭防火墙。"
  warn "本脚本不会清空 nftables / iptables 规则，避免影响 Docker 网络。"
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
    # shellcheck disable=SC1091
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
    ufw_status="$(ufw status 2>/dev/null || true)"
    printf "%s\n" "$ufw_status"

    if printf "%s\n" "$ufw_status" | grep -qi "Status: active"; then
      warn "UFW 正在运行"
    else
      ok "UFW 未运行"
    fi
  else
    ok "未检测到 ufw，无需处理"
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

        if [ -n "$ports" ]; then
          printf "已放行端口：%s\n" "$ports"
        else
          printf "已放行端口：未检测到\n"
        fi

        if [ -n "$services" ]; then
          printf "已放行服务：%s\n" "$services"
        else
          printf "已放行服务：未检测到\n"
        fi
      fi
    else
      ok "firewalld 未运行"
    fi
  else
    ok "未检测到 firewalld，无需处理"
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
    ok "未检测到 nftables 服务，无需处理"
  fi

  if command_exists nft; then
    rules="$(nft list ruleset 2>/dev/null || true)"

    if [ -n "$rules" ]; then
      if printf "%s\n" "$rules" | grep -qi "DOCKER"; then
        log "检测到 Docker 网络规则，通常是容器 NAT / 端口映射规则。"
        log "为避免影响 Docker 网络，本脚本不会清空 nftables 规则。"
      else
        warn "检测到 nftables 规则，可能存在系统防火墙规则。"
        warn "为避免误伤系统网络，本脚本不会自动清空 nftables 规则。"
      fi
    else
      ok "未检测到 nftables 规则"
    fi
  else
    ok "未检测到 nft 命令，无需处理"
  fi
}

show_iptables_status() {
  print_line
  printf "${BLUE}iptables 状态：${NC}\n"

  if command_exists iptables; then
    rules="$(iptables -L INPUT -n --line-numbers 2>/dev/null || true)"

    if [ -n "$rules" ]; then
      printf "%s\n" "$rules"

      if printf "%s\n" "$rules" | grep -Eiq "DROP|REJECT"; then
        warn "检测到 iptables INPUT 链中存在 DROP / REJECT 规则"
        warn "本脚本不会自动清空 iptables 规则，避免影响 Docker 或系统网络。"
      else
        ok "iptables INPUT 链未检测到明显 DROP / REJECT 规则"
      fi
    else
      ok "未检测到 iptables INPUT 规则"
    fi
  else
    ok "未检测到 iptables，无需处理"
  fi
}

show_ip6tables_status() {
  print_line
  printf "${BLUE}ip6tables 状态：${NC}\n"

  if command_exists ip6tables; then
    rules="$(ip6tables -L INPUT -n --line-numbers 2>/dev/null || true)"

    if [ -n "$rules" ]; then
      printf "%s\n" "$rules"

      if printf "%s\n" "$rules" | grep -Eiq "DROP|REJECT"; then
        warn "检测到 ip6tables INPUT 链中存在 DROP / REJECT 规则"
        warn "本脚本不会自动清空 ip6tables 规则。"
      else
        ok "ip6tables INPUT 链未检测到明显 DROP / REJECT 规则"
      fi
    else
      ok "未检测到 ip6tables INPUT 规则"
    fi
  else
    ok "未检测到 ip6tables，无需处理"
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
    ok "未检测到 ss 或 netstat，跳过监听端口显示"
  fi
}

show_firewall_status() {
  print_header
  print_safety_notice
  print_line
  show_system_info
  log "正在检测当前防火墙状态..."

  show_ufw_status
  show_firewalld_status
  show_nftables_status
  show_iptables_status
  show_ip6tables_status
  show_listening_ports
}

disable_ufw() {
  if command_exists ufw; then
    log "正在关闭 ufw..."
    ufw disable >/dev/null 2>&1 || true

    if has_systemctl; then
      systemctl stop ufw >/dev/null 2>&1 || true
      systemctl disable ufw >/dev/null 2>&1 || true
    fi

    ok "ufw 已尝试关闭"
  else
    ok "未检测到 ufw，跳过"
  fi
}

disable_firewalld() {
  if service_exists firewalld || command_exists firewall-cmd; then
    log "正在关闭 firewalld..."

    if has_systemctl; then
      systemctl stop firewalld >/dev/null 2>&1 || true
      systemctl disable firewalld >/dev/null 2>&1 || true
    fi

    ok "firewalld 已尝试关闭"
  else
    ok "未检测到 firewalld，跳过"
  fi
}

disable_nftables_service_only() {
  if service_exists nftables; then
    log "正在关闭 nftables 服务..."

    if has_systemctl; then
      systemctl stop nftables >/dev/null 2>&1 || true
      systemctl disable nftables >/dev/null 2>&1 || true
    fi

    ok "nftables 服务已尝试关闭"
    warn "本脚本不会执行 nft flush ruleset，避免影响 Docker 或系统网络规则。"
  else
    ok "未检测到 nftables 服务，跳过"
  fi
}

disable_firewall() {
  print_line
  warn "即将关闭常见 Linux 防火墙服务：ufw、firewalld、nftables。"
  warn "本脚本不会清空 nftables / iptables 规则，避免影响 Docker 网络。"
  warn "禁止在生产环境直接运行一键关闭防火墙脚本。"
  warn "生产环境建议按需放行端口，不建议完全关闭防火墙。"
  warn "如果你正在通过 SSH 连接服务器，请确认 SSH 端口已在云厂商安全组中放行。"
  print_line

  read -rp "确认关闭防火墙？默认 N，输入 y 继续关闭防火墙 [y/N]: " confirm

  case "$confirm" in
    y|Y)
      log "已确认继续关闭防火墙。"
      ;;
    *)
      warn "未输入 y，已取消关闭防火墙操作。"
      exit 0
      ;;
  esac

  print_line

  disable_ufw
  disable_firewalld
  disable_nftables_service_only

  print_line
  ok "防火墙服务关闭操作完成。"

  warn "重要提醒：云厂商安全组、防火墙策略、网络 ACL 无法通过本脚本关闭。"
  warn "如果端口仍然无法访问，请到云服务器控制台单独放行端口。"
  warn "生产环境请重新评估安全策略，不建议长期关闭防火墙。"
}

show_final_status() {
  print_line
  log "关闭后再次检测防火墙状态..."

  show_ufw_status
  show_firewalld_status
  show_nftables_status
  show_iptables_status
  show_ip6tables_status
  show_listening_ports

  print_line
  ok "脚本执行结束。"
}

main() {
  need_root
  show_firewall_status
  disable_firewall
  show_final_status
}

main "$@"
