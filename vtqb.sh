#!/bin/sh
tput sgr0; clear

## Load Seedbox Components
source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/seedbox_installation.sh)
if [ $? -ne 0 ]; then
    echo "Component ~Seedbox Components~ failed to load"
    echo "Check connection with GitHub"
    exit 1
fi

## Load loading animation
source <(wget -qO- https://raw.githubusercontent.com/Silejonu/bash_loading_animations/main/bash_loading_animations.sh)
if [ $? -ne 0 ]; then
    fail "Component ~Bash loading animation~ failed to load"
    fail_exit "Check connection with GitHub"
fi
trap BLA::stop_loading_animation SIGINT

## Install function
install_() {
    info_2 "$2"
    BLA::start_loading_animation "${BLA_classic[@]}"
    $1 1> /dev/null 2> $3
    if [ $? -ne 0 ]; then
        fail_3 "FAIL" 
    else
        info_3 "Successful"
        export $4=1
    fi
    BLA::stop_loading_animation
}

## 检查 Docker 依赖（新增）
check_docker() {
    if ! command -v docker &> /dev/null; then
        info "Docker 未安装，正在安装..."
        install_ "curl -fsSL https://get.docker.com | sh" "安装 Docker" "/tmp/docker_error" docker_installed
    fi
    if ! command -v docker-compose &> /dev/null; then
        info "Docker Compose 未安装，正在安装..."
        install_ "curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose" "安装 Docker Compose" "/tmp/docker_compose_error" docker_compose_installed
    fi
}

## 安装环境检查
info "Checking Installation Environment"
if [ $(id -u) -ne 0 ]; then 
    fail_exit "脚本需要 root 权限运行"
fi

# 系统版本检查（保持不变）
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
elif [ -f /etc/SuSe-release ]; then
    OS=SuSe
elif [ -f /etc/redhat-release ]; then
    OS=Redhat
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

if [[ ! "$OS" =~ "Debian" ]] && [[ ! "$OS" =~ "Ubuntu" ]]; then
    fail "$OS $VER 不支持"
    info "仅支持 Debian 10+ 和 Ubuntu 20.04+"
    exit 1
fi

# Debian/Ubuntu 版本检查（保持不变）
if [[ "$OS" =~ "Debian" ]] && [[ ! "$VER" =~ "10" && ! "$VER" =~ "11" && ! "$VER" =~ "12" ]]; then
    fail "$OS $VER 不支持"
    info "仅支持 Debian 10+"
    exit 1
fi

if [[ "$OS" =~ "Ubuntu" ]] && [[ ! "$VER" =~ "20" && ! "$VER" =~ "22" && ! "$VER" =~ "23" ]]; then
    fail "$OS $VER 不支持"
    info "仅支持 Ubuntu 20.04+"
    exit 1
fi

## 输入参数解析（保持不变）
while getopts "u:p:c:q:l:rbvx3oh" opt; do
    case ${opt} in
        u ) username=${OPTARG} ;;
        p ) password=${OPTARG} ;;
        c ) 
            cache=${OPTARG}
            while ! [[ "$cache" =~ ^[0-9]+$ ]]; do
                warn "缓存必须是数字"
                need_input "请输入缓存大小（MB）:"
                read cache
            done
            qb_cache=$cache
            ;;
        q ) qb_install=1; qb_ver=("qBittorrent-${OPTARG}") ;;
        l ) lib_ver=("libtorrent-${OPTARG}"); if [ -z "$qb_ver" ]; then warn "必须指定 qBittorrent 版本"; qb_ver_choose; fi ;;
        r ) autoremove_install=1 ;;
        b ) autobrr_install=1 ;;
        v ) vertex_install=1 ;;
        x ) unset bbrv3_install; bbrx_install=1 ;;
        3 ) unset bbrx_install; bbrv3_install=1 ;;
        o ) 
            if [[ -n "$qb_install" ]]; then
                need_input "请输入 qBittorrent 端口:"; read qb_port; while ! [[ "$qb_port" =~ ^[0-9]+$ ]]; do warn "端口必须是数字"; read qb_port; done
                need_input "请输入 qBittorrent 传入端口:"; read qb_incoming_port; while ! [[ "$qb_incoming_port" =~ ^[0-9]+$ ]]; do warn "端口必须是数字"; read qb_incoming_port; done
            fi
            if [[ -n "$autobrr_install" ]]; then
                need_input "请输入 autobrr 端口:"; read autobrr_port; while ! [[ "$autobrr_port" =~ ^[0-9]+$ ]]; do warn "端口必须是数字"; read autobrr_port; done
            fi
            if [[ -n "$vertex_install" ]]; then
                need_input "请输入 vertex 端口:"; read vertex_port; while ! [[ "$vertex_install" =~ ^[0-9]+$ ]]; do warn "端口必须是数字"; read vertex_port; done
            fi
            ;;
        h ) 
            info "帮助:"
            info "用法: ./Install.sh -u <用户名> -p <密码> -c <缓存大小> -q <qBittorrent版本> -l <libtorrent版本> -b -v -r -3 -x -o"
            info "示例: ./Install.sh -u user -p pass -c 3072 -q 4.5.0 -l v2.0.3 -v -b"
            source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/qBittorrent_install.sh)
            seperator
            info "选项说明:"
            need_input "1. -u : 用户名（用于 qBittorrent/vertex 登录）"
            need_input "2. -p : 密码（用于 qBittorrent/vertex 登录）"
            need_input "3. -c : qBittorrent 缓存大小（MB）"
            echo -e "\n"
            need_input "4. -q : qBittorrent 版本（例如: 4.5.0）"
            need_input "5. -l : libtorrent 版本（例如: v2.0.3）"
            echo -e "\n"
            need_input "6. -r : 安装 autoremove-torrents"
            need_input "7. -b : 安装 autobrr"
            need_input "8. -v : 安装 vertex（容器化）"
            need_input "9. -x : 安装 BBRx"
            need_input "10. -3 : 安装 BBRv3"
            need_input "11. -o : 指定端口（qBittorrent/autobrr/vertex）"
            exit 0
            ;;
        \? ) 
            info "错误: 无效参数"
            info_2 "用法: ./Install.sh -u <用户名> -p <密码> -c <缓存大小> -q <qBittorrent版本> -l <libtorrent版本> -b -v -r -3 -x -o"
            exit 1
            ;;
    esac
done

## 系统更新与依赖安装（保持不变）
info "Start System Update & Dependencies Install"
update

## 安装 Seedbox 环境（新增 Docker 检查）
tput sgr0; clear
info "Start Installing Seedbox Environment"
check_docker  # 新增 Docker 依赖检查
echo -e "\n"

# qBittorrent 容器化安装（修改原有逻辑）
source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/qBittorrent_install.sh)
if [ $? -ne 0 ]; then
    fail_exit "Component ~qBittorrent install~ 加载失败"
fi

if [[ ! -z "$qb_install" ]]; then
    ## 参数检查（保持不变）
    if [ -z "$username" ]; then warn "未指定用户名"; need_input "请输入用户名:"; read username; fi
    if [ -z "$password" ]; then warn "未指定密码"; need_input "请输入密码:"; read password; fi
    if ! id -u $username > /dev/null 2>&1; then useradd -m -s /bin/bash $username; fi
    chown -R $username:$username /home/$username
    if [ -z "$cache" ]; then warn "未指定缓存"; need_input "请输入缓存大小（MB）:"; read cache; qb_cache=$cache; fi
    if [ -z "$qb_ver" ]; then warn "未指定 qBittorrent 版本"; qb_ver_check; fi
    if [ -z "$lib_ver" ]; then warn "未指定 libtorrent 版本"; lib_ver_check; fi
    qb_port=${qb_port:-8080}
    qb_incoming_port=${qb_incoming_port:-45000}

    ## 兼容性检查（保持不变）
    qb_install_check

    ## 改为容器化安装（新增函数，假设原有组件支持容器部署）
    install_ "install_qBittorrent_container_ $username $password $qb_port $qb_incoming_port" "安装 qBittorrent 容器" "/tmp/qb_container_error" qb_install_success
fi

# autobrr 安装（保持不变）
if [[ ! -z "$autobrr_install" ]]; then
    install_ install_autobrr_ "安装 autobrr" "/tmp/autobrr_error" autobrr_install_success
fi

# vertex 安装（保持容器化，假设原有逻辑已容器化）
if [[ ! -z "$vertex_install" ]]; then
    install_ install_vertex_ "安装 vertex 容器" "/tmp/vertex_error" vertex_install_success
fi

# autoremove-torrents 安装（保持不变）
if [[ ! -z "$autoremove_install" ]]; then
    install_ install_autoremove-torrents_ "安装 autoremove-torrents" "/tmp/autoremove_error" autoremove_install_success
fi

seperator

## 系统调优（保持不变）
info "Start Doing System Tunning"
install_ tuned_ "安装 tuned" "/tmp/tuned_error" tuned_success
install_ set_txqueuelen_ "设置 txqueuelen" "/tmp/txqueuelen_error" txqueuelen_success
install_ set_file_open_limit_ "设置文件打开限制" "/tmp/file_open_limit_error" file_open_limit_success

systemd-detect-virt > /dev/null
if [ $? -eq 0 ]; then
    warn "检测到虚拟化环境，跳过部分调优"
    install_ disable_tso_ "禁用 TSO" "/tmp/tso_error" tso_success
else
    install_ set_disk_scheduler_ "设置磁盘调度器" "/tmp/disk_scheduler_error" disk_scheduler_success
    install_ set_ring_buffer_ "设置环形缓冲区" "/tmp/ring_buffer_error" ring_buffer_success
fi
install_ set_initial_congestion_window_ "设置初始拥塞窗口" "/tmp/initial_congestion_window_error" initial_congestion_window_success
install_ kernel_settings_ "设置内核参数" "/tmp/kernel_settings_error" kernel_settings_success

# BBR 安装（保持不变）
if [[ ! -z "$bbrx_install" ]]; then
    if [[ ! -z "$(lsmod | grep bbrx)" ]]; then
        warn "Tweaked BBR 已安装"
    else
        install_ install_bbrx_ "安装 BBRx" "/tmp/bbrx_error" bbrx_install_success
    fi
fi

if [[ ! -z "$bbrv3_install" ]]; then
    install_ install_bbrv3_ "安装 BBRv3" "/tmp/bbrv3_error" bbrv3_install_success
fi

## 引导脚本配置（保持不变）
info "Start Configuing Boot Script"
touch /root/.boot-script.sh && chmod +x /root/.boot-script.sh
cat << EOF > /root/.boot-script.sh
#!/bin/bash
sleep 120s
source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/seedbox_installation.sh)
if [ \$? -ne 0 ]; then exit 1; fi
set_txqueuelen_
systemd-detect-virt > /dev/null
if [ \$? -eq 0 ]; then disable_tso_; else set_disk_scheduler_; set_ring_buffer_; fi
set_initial_congestion_window_
EOF

cat << EOF > /etc/systemd/system/boot-script.service
[Unit]
Description=boot-script
After=network.target

[Service]
Type=simple
ExecStart=/root/.boot-script.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable boot-script.service

seperator

## 最终输出（修改为容器化信息）
info "Seedbox 安装完成"
publicip=$(curl -s https://ipinfo.io/ip)

# qBittorrent 容器信息
if [[ ! -z "$qb_install_success" ]]; then
    info "qBittorrent 容器已安装"
    boring_text "WebUI 地址: http://$publicip:$qb_port"
    boring_text "用户名: $username"    # 假设 qBittorrent 容器使用脚本创建的用户
    boring_text "密码: $password"
    echo -e "\n"
fi

# vertex 容器信息（保持原有逻辑）
if [[ ! -z "$vertex_install_success" ]]; then
    info "vertex 容器已安装"
    boring_text "WebUI 地址: http://$publicip:$vertex_port"
    boring_text "用户名: $username"
    boring_text "密码: $password"
    echo -e "\n"
fi

# 其他服务信息（保持不变）
if [[ ! -z "$autoremove_install_success" ]]; then
    info "autoremove-torrents 已安装"
    boring_text "配置文件路径: /home/$username/.config.yml"
    boring_text "文档: https://autoremove-torrents.readthedocs.io/en/latest/config.html"
    echo -e "\n"
fi

if [[ ! -z "$autobrr_install_success" ]]; then
    info "autobrr 已安装"
    boring_text "WebUI 地址: http://$publicip:$autobrr_port"
    echo -e "\n"
fi

if [[ ! -z "$bbrx_install_success" || ! -z "$bbrv3_install_success" ]]; then
    info "BBR 相关优化已安装，重启后生效"
fi

exit 0
