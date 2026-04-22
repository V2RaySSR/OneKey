#!/usr/bin/env bash
set -u

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_VERSION="2026.04.21"
BACKUP_ROOT="/var/backups/change-mirror"
TIMESTAMP="$(date +%F-%H%M%S)"
WORK_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
SUPPORTED_TEXT="Ubuntu / Debian 10 / 11 / 12 / CentOS 7 / CentOS Stream 8 / Rocky / AlmaLinux"

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
  printf "${GREEN}==================== 一键换源脚本 ====================${NC}\n"
  printf "${BLUE} 本脚本支持：%s${NC}\n" "${SUPPORTED_TEXT}"
  printf "${BLUE} 原创：www.v2rayssr.com （已开启禁止国内访问）${NC}\n"
  printf "${BLUE} YouTube频道：波仔分享${NC}\n"
  printf "${BLUE} 本脚本禁止在国内任何网站转载${NC}\n"
  printf "${GREEN}=====================================================${NC}\n"
}

pause_enter() {
  echo
  read -r -p "按回车继续..."
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

rerun_with_privilege() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  print_line
  warn "当前不是 root 用户。"
  warn "脚本需要管理员权限才能修改软件源。"
  echo

  if need_cmd sudo; then
    log "即将尝试使用 sudo 重新执行脚本。"
    log "请根据提示输入当前用户的 sudo 密码。"
    echo
    exec sudo -E bash "$0" "$@"
  else
    err "当前系统未安装 sudo，无法自动提权。"
    echo "请切换到 root 后重新运行："
    echo "bash $0"
    exit 1
  fi
}

ensure_os_release() {
  if [ ! -f /etc/os-release ]; then
    err "未找到 /etc/os-release，无法识别系统。"
    exit 1
  fi
  . /etc/os-release
}

detect_pkg_mgr() {
  if need_cmd apt; then
    PKG_MGR="apt"
  elif need_cmd dnf; then
    PKG_MGR="dnf"
  elif need_cmd yum; then
    PKG_MGR="yum"
  else
    PKG_MGR="unknown"
  fi
}

show_system_info() {
  print_line
  echo "脚本版本 : ${SCRIPT_VERSION}"
  echo "系统名称 : ${PRETTY_NAME:-未知}"
  echo "系统 ID  : ${ID:-未知}"
  echo "版本号   : ${VERSION_ID:-未知}"
  echo "架构     : $(dpkg --print-architecture 2>/dev/null || uname -m)"
  echo "包管理器 : ${PKG_MGR}"
  print_line
}

prepare_backup_dir() {
  mkdir -p "${BACKUP_ROOT}"
  mkdir -p "${WORK_DIR}"
  ok "备份目录已创建：${WORK_DIR}"
}

list_backups() {
  print_line
  echo "可用备份列表："
  if [ ! -d "${BACKUP_ROOT}" ]; then
    warn "备份目录不存在。"
    return 1
  fi

  local found=0
  local i=1
  for dir in "${BACKUP_ROOT}"/*; do
    [ -d "$dir" ] || continue
    echo "  ${i}) $(basename "$dir")"
    i=$((i + 1))
    found=1
  done

  if [ "$found" -eq 0 ]; then
    warn "当前没有可恢复的备份。"
    return 1
  fi
  return 0
}

select_backup_dir() {
  list_backups || return 1
  echo
  read -r -p "请输入要恢复的备份编号: " BACKUP_NUM

  local i=1
  for dir in "${BACKUP_ROOT}"/*; do
    [ -d "$dir" ] || continue
    if [ "$i" = "$BACKUP_NUM" ]; then
      SELECTED_BACKUP="$dir"
      return 0
    fi
    i=$((i + 1))
  done

  err "输入的备份编号无效。"
  return 1
}

backup_file_if_exists() {
  local src="$1"
  if [ -e "$src" ]; then
    cp -a "$src" "${WORK_DIR}/"
    ok "已备份文件：$src"
  else
    warn "未找到文件：$src"
  fi
}

backup_dir_if_exists() {
  local src="$1"
  if [ -d "$src" ]; then
    cp -a "$src" "${WORK_DIR}/"
    ok "已备份目录：$src"
  else
    warn "未找到目录：$src"
  fi
}

choose_main_menu() {
  print_line
  echo "请选择要执行的操作："
  echo
  echo "  1) 更换软件源"
  echo "  2) 恢复之前的备份"
  echo "  0) 退出脚本"
  echo
  read -r -p "请输入编号: " MAIN_ACTION
}

choose_mirror() {
  print_line
  echo "请选择镜像源："
  echo
  echo "  1) 清华 TUNA"
  echo "  2) 阿里云"
  echo "  3) 中科大 USTC"
  echo "  4) 腾讯云"
  echo "  5) 华为云"
  echo "  0) 返回上一级"
  echo
  read -r -p "请输入编号: " MIRROR_CHOICE
}

set_mirror_vars() {
  case "${MIRROR_CHOICE}" in
    1)
      MIRROR_NAME="清华 TUNA"
      UBUNTU_URL="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
      UBUNTU_PORTS_URL="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports"
      DEBIAN_URL="https://mirrors.tuna.tsinghua.edu.cn/debian"
      DEBIAN_SECURITY_URL="https://mirrors.tuna.tsinghua.edu.cn/debian-security"
      EL_URL="https://mirrors.tuna.tsinghua.edu.cn"
      ;;
    2)
      MIRROR_NAME="阿里云"
      UBUNTU_URL="https://mirrors.aliyun.com/ubuntu"
      UBUNTU_PORTS_URL="https://mirrors.aliyun.com/ubuntu-ports"
      DEBIAN_URL="https://mirrors.aliyun.com/debian"
      DEBIAN_SECURITY_URL="https://mirrors.aliyun.com/debian-security"
      EL_URL="https://mirrors.aliyun.com"
      ;;
    3)
      MIRROR_NAME="中科大 USTC"
      UBUNTU_URL="https://mirrors.ustc.edu.cn/ubuntu"
      UBUNTU_PORTS_URL="https://mirrors.ustc.edu.cn/ubuntu-ports"
      DEBIAN_URL="https://mirrors.ustc.edu.cn/debian"
      DEBIAN_SECURITY_URL="https://mirrors.ustc.edu.cn/debian-security"
      EL_URL="https://mirrors.ustc.edu.cn"
      ;;
    4)
      MIRROR_NAME="腾讯云"
      UBUNTU_URL="https://mirrors.cloud.tencent.com/ubuntu"
      UBUNTU_PORTS_URL="https://mirrors.cloud.tencent.com/ubuntu-ports"
      DEBIAN_URL="https://mirrors.cloud.tencent.com/debian"
      DEBIAN_SECURITY_URL="https://mirrors.cloud.tencent.com/debian-security"
      EL_URL="https://mirrors.cloud.tencent.com"
      ;;
    5)
      MIRROR_NAME="华为云"
      UBUNTU_URL="https://repo.huaweicloud.com/ubuntu"
      UBUNTU_PORTS_URL="https://repo.huaweicloud.com/ubuntu-ports"
      DEBIAN_URL="https://repo.huaweicloud.com/debian"
      DEBIAN_SECURITY_URL="https://repo.huaweicloud.com/debian-security"
      EL_URL="https://repo.huaweicloud.com"
      ;;
    0)
      return 1
      ;;
    *)
      err "镜像源编号无效。"
      return 1
      ;;
  esac
  return 0
}

apt_update_cache() {
  print_line
  log "正在刷新 APT 缓存，请稍等……"
  apt clean
  if apt update; then
    ok "APT 缓存刷新完成。"
  else
    err "APT 刷新失败，请检查网络或源配置。"
    return 1
  fi
}

yum_update_cache() {
  print_line
  log "正在刷新 YUM/DNF 缓存，请稍等……"
  if need_cmd dnf; then
    dnf clean all
    if dnf makecache; then
      ok "DNF 缓存刷新完成。"
    else
      err "DNF 刷新失败，请检查网络或源配置。"
      return 1
    fi
  else
    yum clean all
    if yum makecache; then
      ok "YUM 缓存刷新完成。"
    else
      err "YUM 刷新失败，请检查网络或源配置。"
      return 1
    fi
  fi
}

ubuntu_is_new_sources() {
  [ -f /etc/apt/sources.list.d/ubuntu.sources ]
}

write_ubuntu_sources() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || true)"

  local main_uri security_uri
  if [ "$arch" = "amd64" ] || [ "$arch" = "i386" ]; then
    main_uri="${UBUNTU_URL}"
    security_uri="http://security.ubuntu.com/ubuntu/"
  else
    main_uri="${UBUNTU_PORTS_URL}"
    security_uri="http://ports.ubuntu.com/ubuntu-ports/"
  fi

  backup_file_if_exists /etc/apt/sources.list.d/ubuntu.sources
  backup_file_if_exists /etc/apt/sources.list

  cat > /etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb
URIs: ${main_uri}
Suites: ${VERSION_CODENAME} ${VERSION_CODENAME}-updates ${VERSION_CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: ${security_uri}
Suites: ${VERSION_CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

  ok "Ubuntu .sources 配置写入完成。"
}

write_ubuntu_list() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || true)"

  local main_uri security_uri
  if [ "$arch" = "amd64" ] || [ "$arch" = "i386" ]; then
    main_uri="${UBUNTU_URL}"
    security_uri="http://security.ubuntu.com/ubuntu/"
  else
    main_uri="${UBUNTU_PORTS_URL}"
    security_uri="http://ports.ubuntu.com/ubuntu-ports/"
  fi

  backup_file_if_exists /etc/apt/sources.list
  backup_file_if_exists /etc/apt/sources.list.d/ubuntu.sources

  cat > /etc/apt/sources.list <<EOF
deb ${main_uri} ${VERSION_CODENAME} main restricted universe multiverse
deb ${main_uri} ${VERSION_CODENAME}-updates main restricted universe multiverse
deb ${main_uri} ${VERSION_CODENAME}-backports main restricted universe multiverse
deb ${security_uri} ${VERSION_CODENAME}-security main restricted universe multiverse
EOF

  ok "Ubuntu sources.list 配置写入完成。"
}

write_debian_list() {
  backup_file_if_exists /etc/apt/sources.list

  cat > /etc/apt/sources.list <<EOF
deb ${DEBIAN_URL} ${VERSION_CODENAME} main contrib non-free non-free-firmware
deb ${DEBIAN_URL} ${VERSION_CODENAME}-updates main contrib non-free non-free-firmware
deb ${DEBIAN_SECURITY_URL} ${VERSION_CODENAME}-security main contrib non-free non-free-firmware
EOF

  ok "Debian sources.list 配置写入完成。"
}

backup_el_repos() {
  backup_dir_if_exists /etc/yum.repos.d
}

write_centos7_repo() {
  rm -f /etc/yum.repos.d/*.repo

  cat > /etc/yum.repos.d/CentOS-Base.repo <<EOF
[base]
name=CentOS-\$releasever - Base
baseurl=${EL_URL}/centos/7/os/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-\$releasever - Updates
baseurl=${EL_URL}/centos/7/updates/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-\$releasever - Extras
baseurl=${EL_URL}/centos/7/extras/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF

  ok "CentOS 7 repo 写入完成。"
}

write_el8_stream_repo() {
  rm -f /etc/yum.repos.d/*.repo

  cat > /etc/yum.repos.d/CentOS-Stream.repo <<EOF
[baseos]
name=BaseOS
baseurl=${EL_URL}/centos/8-stream/BaseOS/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[appstream]
name=AppStream
baseurl=${EL_URL}/centos/8-stream/AppStream/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[extras]
name=Extras
baseurl=${EL_URL}/centos/8-stream/extras/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

  ok "CentOS Stream 8 repo 写入完成。"
}

write_rocky_repo() {
  local releasever="${VERSION_ID%%.*}"
  rm -f /etc/yum.repos.d/*.repo

  cat > /etc/yum.repos.d/Rocky.repo <<EOF
[baseos]
name=Rocky Linux \$releasever - BaseOS
baseurl=${EL_URL}/rocky/${releasever}/BaseOS/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial

[appstream]
name=Rocky Linux \$releasever - AppStream
baseurl=${EL_URL}/rocky/${releasever}/AppStream/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial

[extras]
name=Rocky Linux \$releasever - Extras
baseurl=${EL_URL}/rocky/${releasever}/extras/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
EOF

  ok "Rocky Linux repo 写入完成。"
}

write_alma_repo() {
  local releasever="${VERSION_ID%%.*}"
  rm -f /etc/yum.repos.d/*.repo

  cat > /etc/yum.repos.d/AlmaLinux.repo <<EOF
[baseos]
name=AlmaLinux \$releasever - BaseOS
baseurl=${EL_URL}/almalinux/${releasever}/BaseOS/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[appstream]
name=AlmaLinux \$releasever - AppStream
baseurl=${EL_URL}/almalinux/${releasever}/AppStream/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[extras]
name=AlmaLinux \$releasever - Extras
baseurl=${EL_URL}/almalinux/${releasever}/extras/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux
EOF

  ok "AlmaLinux repo 写入完成。"
}

restore_backup() {
  if ! select_backup_dir; then
    return 1
  fi

  print_line
  warn "即将恢复备份：$(basename "$SELECTED_BACKUP")"
  read -r -p "确认恢复吗？输入 yes 继续: " CONFIRM_RESTORE
  if [ "$CONFIRM_RESTORE" != "yes" ]; then
    warn "你已取消恢复操作。"
    return 1
  fi

  if [ -f "${SELECTED_BACKUP}/sources.list" ]; then
    cp -a "${SELECTED_BACKUP}/sources.list" /etc/apt/sources.list
    ok "已恢复 /etc/apt/sources.list"
  fi

  if [ -f "${SELECTED_BACKUP}/ubuntu.sources" ]; then
    mkdir -p /etc/apt/sources.list.d
    cp -a "${SELECTED_BACKUP}/ubuntu.sources" /etc/apt/sources.list.d/ubuntu.sources
    ok "已恢复 /etc/apt/sources.list.d/ubuntu.sources"
  fi

  if [ -d "${SELECTED_BACKUP}/yum.repos.d" ]; then
    rm -rf /etc/yum.repos.d
    cp -a "${SELECTED_BACKUP}/yum.repos.d" /etc/yum.repos.d
    ok "已恢复 /etc/yum.repos.d"
  fi

  if [ "${PKG_MGR}" = "apt" ]; then
    apt_update_cache
  else
    yum_update_cache
  fi

  ok "恢复完成。"
  return 0
}

change_source() {
  choose_mirror
  set_mirror_vars || return 1

  print_line
  log "你选择的镜像源是：${MIRROR_NAME}"
  read -r -p "确认开始更换软件源吗？输入 yes 继续: " CONFIRM_CHANGE
  if [ "${CONFIRM_CHANGE}" != "yes" ]; then
    warn "你已取消换源操作。"
    return 1
  fi

  prepare_backup_dir

  case "${ID}" in
    ubuntu)
      log "检测到 Ubuntu 系统。"
      if ubuntu_is_new_sources; then
        log "检测到新版 .sources 格式，准备写入 ubuntu.sources。"
        write_ubuntu_sources
      else
        log "检测到传统 sources.list 格式，准备写入 /etc/apt/sources.list。"
        write_ubuntu_list
      fi
      apt_update_cache
      ;;
    debian)
      log "检测到 Debian 系统。"
      write_debian_list
      apt_update_cache
      ;;
    centos)
      log "检测到 CentOS 系统。"
      backup_el_repos
      if [[ "${VERSION_ID}" =~ ^7 ]]; then
        write_centos7_repo
      elif [[ "${VERSION_ID}" =~ ^8 ]]; then
        warn "CentOS 8 已停止常规维护，这里按 CentOS Stream 8 处理。"
        write_el8_stream_repo
      else
        err "当前 CentOS 版本暂未适配：${VERSION_ID}"
        return 1
      fi
      yum_update_cache
      ;;
    rocky)
      log "检测到 Rocky Linux 系统。"
      backup_el_repos
      write_rocky_repo
      yum_update_cache
      ;;
    almalinux)
      log "检测到 AlmaLinux 系统。"
      backup_el_repos
      write_alma_repo
      yum_update_cache
      ;;
    *)
      err "暂不支持当前系统：${ID:-未知}"
      return 1
      ;;
  esac

  print_line
  ok "软件源更换完成。"
  echo "本次备份目录：${WORK_DIR}"
  print_line
  return 0
}

main() {
  print_header
  rerun_with_privilege "$@"
  ensure_os_release
  detect_pkg_mgr
  show_system_info

  while true; do
    choose_main_menu
    case "${MAIN_ACTION}" in
      1)
        change_source || true
        pause_enter
        ;;
      2)
        restore_backup || true
        pause_enter
        ;;
      0)
        ok "已退出脚本。"
        exit 0
        ;;
      *)
        warn "输入无效，请重新选择。"
        pause_enter
        ;;
    esac
  done
}

main "$@"