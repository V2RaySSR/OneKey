# Linux 一键换源脚本

这是一个基于 AI 工具辅助整理的 Linux 自动化脚本项目，主要用于快速完成常见的软件源切换操作。脚本目前支持 Ubuntu、Debian、CentOS、Rocky Linux、AlmaLinux 等常见发行版，提供交互式选择国内镜像源、自动备份原始配置、支持恢复原始源等功能，适合 VPS、服务器以及日常 Linux 环境初始化使用。

## 项目特点

- 支持多种常见 Linux 发行版
- 支持交互式选择国内镜像源
- 自动备份当前源配置
- 支持恢复原始软件源配置
- 支持非 root 用户运行时自动尝试提权
- 适合系统初始化、部署前准备与日常维护

## 支持系统

- Ubuntu
- Debian 10 / 11 / 12
- CentOS 7
- CentOS Stream 8
- Rocky Linux
- AlmaLinux

## 支持镜像源

- 清华 TUNA
- 阿里云
- 中科大 USTC
- 腾讯云
- 华为云

## 使用方式

### 方式一：直接在线运行

```bash
bash <(curl -fsSL https://v2rayssr.com/tool/change_mirror.sh)
