# Linux 自动化一键脚本

这是一个 Linux 自动化一键脚本合集，后续会持续整理和更新常用 VPS、服务器初始化、系统维护、环境配置相关脚本。

脚本主要适用于 Ubuntu、Debian、CentOS、Rocky Linux、AlmaLinux、Oracle Linux 等常见 Linux 发行版。

## 支持系统

- Ubuntu
- Debian
- CentOS
- CentOS Stream
- Rocky Linux
- AlmaLinux
- Oracle Linux

## Linux 一键换源脚本

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/V2RaySSR/OneKey/main/change_mirror.sh)
```

## Linux 一键关闭防火墙脚本

禁止在生产环境直接运行一键关闭防火墙脚本。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/V2RaySSR/OneKey/main/disable_firewall.sh)
```
