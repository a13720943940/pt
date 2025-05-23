#!/bin/bash

set -e

# 清屏
tput sgr0; clear

## 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

## 日志函数
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()    { echo -e "${RED}[ERROR]${NC} $1" >&2; }
exit_fail() { fail "$1"; exit 1; }

## 检查是否以 root 权限运行
if [ "$(id -u)" != "0" ]; then
  exit_fail "请以 root 用户或使用 sudo 运行此脚本"
fi

## 操作系统检测
check_os_version() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    OS=Debian
    VER=$(cat /etc/debian_version)
  else
    exit_fail "不支持的操作系统，请使用 Debian 或 Ubuntu"
  fi

  if [[ ! "$OS" =~ "Debian" && ! "$OS" =~ "Ubuntu" ]]; then
    exit_fail "仅支持 Debian 和 Ubuntu 系统"
  fi

  if [[ "$OS" == "Debian" && "$VER" < 10 ]]; then
    exit_fail "Debian 版本必须 >= 10"
  fi

  if [[ "$OS" == "Ubuntu" && "$VER" < 20.04 ]]; then
    exit_fail "Ubuntu 版本必须 >= 20.04"
  fi
}

## 安装 Docker
install_docker() {
  if ! command -v docker > /dev/null; then
    info "正在安装 Docker..."
    apt-get update -qq
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common > /dev/null

    # 下载 Docker 的官方 GPG 密钥，并将其添加到 trusted.gpg.d 目录
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 设置 Docker 的 APT 仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null
    systemctl enable docker > /dev/null
    systemctl start docker
    info "Docker 安装完成！"
  else
    info "Docker 已安装。"
  fi
}

## 安装 qBittorrent 容器
install_qbittorrent_container() {
  local qb_user="$1"
  local qb_pass="$2"
  local qb_cache="$3"
  local qb_port="$4"
  local qb_incoming_port="$5"

  local PUID=$(id -u "$qb_user")
  local PGID=$(id -g "$qb_user")
  local TZ=$(timedatectl show --property=Timezone --value)

  local CONFIG_DIR="/home/$qb_user/.config/qbittorrent"
  local DOWNLOAD_DIR="/home/$qb_user/downloads"

  mkdir -p "$CONFIG_DIR" "$DOWNLOAD_DIR"
  chown -R "$qb_user:$qb_user" "$CONFIG_DIR" "$DOWNLOAD_DIR"

  info "启动 qBittorrent 容器..."

  docker run -d \
    --name qbittorrent \
    -e PUID=$PUID \
    -e PGID=$PGID \
    -e TZ="$TZ" \
    -e WEBUI_PORT="$qb_port" \
    -e U2BK_USERNAME="$qb_user" \
    -e U2BK_PASSWORD="$qb_pass" \
    -e CACHE_SIZE="$qb_cache" \
    -p "$qb_port":8080 \
    -p "$qb_incoming_port":6881/tcp \
    -p "$qb_incoming_port":6881/udp \
    -v "$CONFIG_DIR":/config \
    -v "$DOWNLOAD_DIR":/downloads \
    --restart unless-stopped \
    linuxserver/qbittorrent:latest

  info "qBittorrent 容器已启动！访问地址：http://$(hostname -I | awk '{print $1}'):$qb_port"
  info "用户名: $qb_user"
  info "密码: $qb_pass (请登录后尽快更改)"
}

## 主函数
main() {
  local username=""
  local password=""
  local cache=""
  local qb_install=0
  local qb_ver=""
  local lib_ver=""
  local qb_port=8080
  local qb_incoming_port=6881
  local vertex_install=0
  local bbrx_install=0

  while getopts "u:p:c:q:l:o:vxh" opt; do
    case "$opt" in
      u) username="$OPTARG" ;;
      p) password="$OPTARG" ;;
      c) cache="$OPTARG" ;;
      q) qb_install=1; qb_ver="$OPTARG" ;;
      l) lib_ver="$OPTARG" ;;
      o) 
        IFS="," read -r qb_port qb_incoming_port <<< "$OPTARG"
        ;;
      v) vertex_install=1 ;;
      x) bbrx_install=1 ;;
      h)
        echo "Usage: $0 -u <username> -p <password> -c <cache size(MiB)> -q <qb version> -l <libtorrent version> [-o web,port]"
        echo "示例: bash <(wget ...) -u user -p pass -c 3072 -q 4.3.9 -l v1.2.19 -v -x"
        exit 0
        ;;
      *)
        exit_fail "无效的参数"
        ;;
    esac
  done

  # 检查必要参数
  if [[ $qb_install -eq 1 ]]; then
    if [[ -z "$username" || -z "$password" || -z "$cache" ]]; then
      exit_fail "安装 qBittorrent 需要指定用户名、密码和缓存大小"
    fi
  fi

  check_os_version
  install_docker

  if [[ $qb_install -eq 1 ]]; then
    install_qbittorrent_container "$username" "$password" "$cache" "$qb_port" "$qb_incoming_port"
  fi

  if [[ $vertex_install -eq 1 ]]; then
    warn "Vertex 安装暂未实现"
  fi

  if [[ $bbrx_install -eq 1 ]]; then
    warn "BBRx 设置暂未实现"
  fi

  info "安装已完成！"
}

main "$@"
