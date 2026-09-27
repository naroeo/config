#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-09-27-QINGLONG-2.22.0-DEBIAN-BLITZ-V12 🔥🔥🔥"

set -Eeuo pipefail


################################################
# PATH
################################################

export PATH="$HOME/bin:$PATH"


################################################
# 基础变量
################################################

QL_DIR="${QL_DIR:-/ql}"

dir_shell="$QL_DIR/shell"

# =================================================
# 非常重要：
#
# beta.blitz / Render 的 PORT：
#   给 nginx
#
# QingLong：
#   永远使用 5600
#
# GRPC：
#   使用 5500
# =================================================

QL_INTERNAL_PORT=5600
QL_GRPC_PORT=5500

PLATFORM_PORT="${PORT:-}"


################################################
# 错误处理
################################################

trap '
echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "❌ ENTRYPOINT 异常退出"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "line=$LINENO"
echo "command=$BASH_COMMAND"
echo "exit_code=$?"
echo

echo "========== PM2 =========="
pm2 status 2>&1 || true

echo
echo "========== PM2 qinglong =========="
pm2 show qinglong 2>&1 || true

echo
echo "========== PM2 logs =========="
pm2 logs qinglong --lines 200 --nostream 2>&1 || true

echo
echo "========== processes =========="
ps aux 2>&1 || true

echo
echo "========== ports =========="
ss -ltnp 2>&1 || true

exit 1
' ERR


################################################
# 基础信息
################################################

echo
echo "=============================================="
echo "基础环境"
echo "=============================================="

echo "HOME=$HOME"
echo "USER=$(whoami)"
echo "QL_DIR=$QL_DIR"
echo "QingLong internal port=$QL_INTERNAL_PORT"
echo "QingLong gRPC port=$QL_GRPC_PORT"
echo "Platform PORT=$PLATFORM_PORT"


################################################
# Platform PORT 检查
################################################

if [ -z "$PLATFORM_PORT" ]; then

    echo
    echo "❌ PORT 不存在"
    echo "beta.blitz / Render 必须提供 PORT"

    exit 1

fi


################################################
# 基础程序
################################################

echo
echo "=============================================="
echo "基础程序检查"
echo "=============================================="

echo
echo "bash:"
bash --version | head -1 || true

echo
echo "node:"
node -v || true

echo
echo "npm:"
npm -v || true

echo
echo "pm2:"
pm2 -v || true

echo
echo "nginx:"
nginx -v 2>&1 || true

echo
echo "curl:"
curl --version | head -1 || true

echo
echo "rclone:"
rclone version 2>&1 | head -5 || true

echo
echo "ss:"
ss --version 2>&1 | head -1 || true


################################################
# QingLong shell
################################################

echo
echo "=============================================="
echo "检查 QingLong"
echo "=============================================="

if [ ! -d "$QL_DIR" ]; then

    echo "❌ QL_DIR 不存在：$QL_DIR"

    exit 1

fi

echo "✔ QL_DIR=$QL_DIR"


if [ -f "$dir_shell/share.sh" ]; then

    echo "✔ share.sh 存在"

else

    echo "⚠️ share.sh 不存在"

fi


if [ -f "$dir_shell/env.sh" ]; then

    echo "✔ env.sh 存在"

else

    echo "⚠️ env.sh 不存在"

fi


################################################
# 加载 QingLong 环境
################################################

echo
echo "=============================================="
echo "加载 QingLong 环境"
echo "=============================================="


if [ -f "$dir_shell/share.sh" ]; then

    . "$dir_shell/share.sh"

fi


if [ -f "$dir_shell/env.sh" ]; then

    # 尽量读取 QingLong 原始环境
    load_ql_envs || true

    echo
    echo "QingLong 原始环境："

    echo "ql_port=${ql_port:-}"
    echo "ql_grpc_port=${ql_grpc_port:-}"

    # 导入原始环境
    . "$dir_shell/env.sh"

    # 保留原有初始化机制
    import_config "$@" || true

    fix_config || true

fi


################################################
# 强制内部端口
################################################

echo
echo "=============================================="
echo "统一 QingLong 内部端口"
echo "=============================================="


# =================================================
# 这里是 V12 最重要的地方
#
# 不再：
#
# BACK_PORT=5700
#
# 而是：
#
# PORT=5600
# BACK_PORT=5600
# GRPC_PORT=5500
# =================================================

export PORT="$QL_INTERNAL_PORT"
export BACK_PORT="$QL_INTERNAL_PORT"
export GRPC_PORT="$QL_GRPC_PORT"


echo "PORT=$PORT"
echo "BACK_PORT=$BACK_PORT"
echo "GRPC_PORT=$GRPC_PORT"


################################################
# 修改 QingLong .env
################################################

echo
echo "=============================================="
echo "写入 QingLong .env"
echo "=============================================="


touch "$QL_DIR/.env"


# 删除可能产生冲突的端口配置
sed -i '/^PORT=/d' "$QL_DIR/.env"
sed -i '/^BACK_PORT=/d' "$QL_DIR/.env"
sed -i '/^GRPC_PORT=/d' "$QL_DIR/.env"


# 写入唯一配置
cat >> "$QL_DIR/.env" <<EOF

# ==================================================
# beta.blitz internal configuration
# Generated by entrypoint V12
# ==================================================

PORT=$QL_INTERNAL_PORT
BACK_PORT=$QL_INTERNAL_PORT
GRPC_PORT=$QL_GRPC_PORT

EOF


echo
echo "最终 QingLong .env："

grep -nE '^(PORT|BACK_PORT|GRPC_PORT)=' \
"$QL_DIR/.env" || true


################################################
# 再次 export
################################################

export PORT="$QL_INTERNAL_PORT"
export BACK_PORT="$QL_INTERNAL_PORT"
export GRPC_PORT="$QL_GRPC_PORT"


################################################
# rclone 配置
################################################

echo
echo "=============================================="
echo "rclone 配置"
echo "=============================================="


if [ -n "${RCLONE_CONF:-}" ]; then

    mkdir -p "$HOME/.config/rclone"

    printf '%s\n' "$RCLONE_CONF" \
        > "$HOME/.config/rclone/rclone.conf"

    chmod 600 "$HOME/.config/rclone/rclone.conf"

    echo "✔ rclone 配置完成"

else

    echo "没有检测到 RCLONE_CONF"

fi


################################################
# 启动前环境确认
################################################

echo
echo "=============================================="
echo "QingLong 启动环境最终确认"
echo "=============================================="


echo
echo "Shell environment："

env | sort | grep -E \
'^(PORT|BACK_PORT|GRPC_PORT|QL_|QLPORT|QL_PORT)=' \
|| true


echo
echo "QingLong .env："

grep -nE \
'^(PORT|BACK_PORT|GRPC_PORT|QL_|QLPORT|QL_PORT)=' \
"$QL_DIR/.env" \
|| true


################################################
# 启动前端口检查
################################################

echo
echo "=============================================="
echo "启动 QingLong 前端口检查"
echo "=============================================="


echo
echo "5600："

ss -ltnp 2>/dev/null | grep ':5600' \
    || echo "5600 当前没有监听"


echo
echo "5500："

ss -ltnp 2>/dev/null | grep ':5500' \
    || echo "5500 当前没有监听"


echo
echo "Platform PORT=$PLATFORM_PORT："

ss -ltnp 2>/dev/null | grep ":$PLATFORM_PORT" \
    || echo "$PLATFORM_PORT 当前没有监听"


################################################
# PM2 启动前
################################################

echo
echo "=============================================="
echo "PM2 启动前状态"
echo "=============================================="


pm2 status || true


################################################
# PM2 启动 QingLong
################################################

echo
echo "=============================================="
echo "启动 QingLong"
echo "=============================================="


reload_pm2


echo
echo "✔ reload_pm2 执行完成"


sleep 5


################################################
# PM2 状态
################################################

echo
echo "=============================================="
echo "PM2 启动后"
echo "=============================================="


pm2 status || true


echo
echo "PM2 qinglong："

pm2 show qinglong || true


################################################
# PM2 环境
################################################

echo
echo "=============================================="
echo "PM2 实际环境"
echo "=============================================="


pm2 env 0 2>&1 | \
grep -E '^(PORT|BACK_PORT|GRPC_PORT|QL_|QLPORT|QL_PORT)=' \
|| true


################################################
# PM2 日志
################################################

echo
echo "=============================================="
echo "PM2 QingLong 最近日志"
echo "=============================================="


# V12：
# 不再 2>/dev/null
# 不吞真正的启动错误

pm2 logs qinglong --lines 200 --nostream || true


################################################
# 进程
################################################

echo
echo "=============================================="
echo "QingLong Node 进程"
echo "=============================================="


ps aux | grep -E \
'node|qinglong' | grep -v grep \
|| true


################################################
# 全部监听端口
################################################

echo
echo "=============================================="
echo "当前监听端口"
echo "=============================================="


ss -ltnp 2>/dev/null || true


################################################
# 5600 监听等待
################################################

echo
echo "=============================================="
echo "等待 QingLong 监听 5600"
echo "=============================================="


QL_PORT_READY=false


for i in $(seq 1 40)
do

    echo
    echo "[port] 第 $i/40 次检查"

    if ss -ltn 2>/dev/null | grep -q ':5600 '; then

        echo "✔ 5600 已经监听"

        QL_PORT_READY=true

        break

    fi


    echo "❌ 5600 尚未监听"

    sleep 2

done


################################################
# 如果 5600 没启动
################################################

if [ "$QL_PORT_READY" != "true" ]; then

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "❌ QingLong 没有监听 5600"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"


    echo
    echo "========== PM2 =========="

    pm2 status || true


    echo
    echo "========== PM2 SHOW =========="

    pm2 show qinglong || true


    echo
    echo "========== PM2 ENV =========="

    pm2 env 0 2>&1 || true


    echo
    echo "========== PM2 LOG =========="

    pm2 logs qinglong --lines 300 --nostream || true


    echo
    echo "========== NODE =========="

    ps aux | grep -E \
    'node|qinglong' | grep -v grep || true


    echo
    echo "========== PORTS =========="

    ss -ltnp 2>/dev/null || true


    echo
    echo "========== .env =========="

    cat "$QL_DIR/.env" || true


    echo
    echo "❌ 不启动 nginx"

    exit 1

fi


################################################
# QingLong HTTP 测试
################################################

echo
echo "=============================================="
echo "QingLong HTTP 测试"
echo "=============================================="


QL_HTTP_READY=false


echo
echo "测试：/"

if curl -v \
    --max-time 5 \
    "http://127.0.0.1:$QL_INTERNAL_PORT/" \
    -o /tmp/qinglong-root.txt \
    2>/tmp/qinglong-root-curl.txt
then

    echo "✔ QingLong / 响应"

    head -c 500 \
        /tmp/qinglong-root.txt \
        || true

    echo

    QL_HTTP_READY=true

else

    echo "⚠️ QingLong / 没有正常响应"

    cat /tmp/qinglong-root-curl.txt \
        || true

fi


echo
echo "测试：/api/health"

if curl -v \
    --max-time 5 \
    "http://127.0.0.1:$QL_INTERNAL_PORT/api/health" \
    -o /tmp/qinglong-health.txt \
    2>/tmp/qinglong-health-curl.txt
then

    echo "✔ /api/health 响应"

    cat /tmp/qinglong-health.txt \
        || true

else

    echo "⚠️ /api/health 没有正常响应"

    cat /tmp/qinglong-health-curl.txt \
        || true

fi


################################################
# HTTP 未响应
################################################

if [ "$QL_HTTP_READY" != "true" ]; then

    echo
    echo "⚠️ 5600 已监听，但 HTTP 没有正常响应"

    echo
    echo "========== PM2 LOG =========="

    pm2 logs qinglong --lines 300 --nostream || true

    echo
    echo "========== PORTS =========="

    ss -ltnp 2>/dev/null || true

    exit 1

fi


################################################
# 到这里 QingLong 已经确认
################################################

echo
echo "=============================================="
echo "✔ QingLong 已确认启动"
echo "=============================================="


echo "Internal HTTP : 127.0.0.1:$QL_INTERNAL_PORT"
echo "Platform HTTP : $PLATFORM_PORT"


################################################
# nginx
################################################

echo
echo "=============================================="
echo "准备 nginx"
echo "=============================================="


# 清理旧 nginx
nginx -s quit 2>/dev/null || true

sleep 1

pkill -TERM nginx 2>/dev/null || true

sleep 1

pkill -KILL nginx 2>/dev/null || true


################################################
# nginx 配置
################################################

if [ ! -f /etc/nginx/conf.d/front.conf ]; then

    echo "❌ /etc/nginx/conf.d/front.conf 不存在"

    exit 1

fi


echo
echo "=============================================="
echo "生成 nginx 配置"
echo "=============================================="


envsubst '$PORT' \
    < /etc/nginx/conf.d/front.conf \
    > /tmp/front.conf


mv \
    /tmp/front.conf \
    /etc/nginx/conf.d/front.conf


echo
echo "最终 nginx 配置："

cat /etc/nginx/conf.d/front.conf


################################################
# nginx test
################################################

echo
echo "=============================================="
echo "nginx 配置测试"
echo "=============================================="


nginx -t


################################################
# nginx 启动前
################################################

echo
echo "=============================================="
echo "nginx 启动前端口"
echo "=============================================="


echo
echo "QingLong 5600："

ss -ltnp 2>/dev/null | grep ':5600' \
    || true


echo
echo "Platform $PLATFORM_PORT："

ss -ltnp 2>/dev/null | grep ":$PLATFORM_PORT" \
    || echo "$PLATFORM_PORT 当前空闲"


################################################
# nginx 启动
################################################

echo
echo "启动 nginx..."

nginx


sleep 3


################################################
# nginx 检查
################################################

echo
echo "=============================================="
echo "nginx 启动后"
echo "=============================================="


ps aux | grep nginx | grep -v grep \
    || true


echo
echo "监听端口："

ss -ltnp 2>/dev/null || true


################################################
# Platform HTTP
################################################

echo
echo "=============================================="
echo "Platform HTTP 测试"
echo "=============================================="


if curl -fsS \
    --max-time 10 \
    "http://127.0.0.1:$PLATFORM_PORT/" \
    -o /tmp/nginx-test.html
then

    echo "✔ nginx Platform HTTP 测试成功"

    head -c 500 \
        /tmp/nginx-test.html \
        || true

    echo

else

    echo "❌ nginx Platform HTTP 测试失败"

    echo
    echo "========== nginx error.log =========="

    tail -100 /var/log/nginx/error.log \
        2>/dev/null || true

    exit 1

fi


################################################
# 管理员初始化
################################################

if [ -n "${ADMIN_USERNAME:-}" ] && \
   [ -n "${ADMIN_PASSWORD:-}" ]
then

    echo
    echo "=============================================="
    echo "管理员初始化"
    echo "=============================================="


    curl -sS \
        --max-time 20 \
        "http://127.0.0.1:$QL_INTERNAL_PORT/api/user/init?t=$(date +%s)" \
        -X PUT \
        -H "Content-Type: application/json;charset=UTF-8" \
        --data \
        "{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" \
        | jq || true

else

    echo
    echo "没有设置 ADMIN_USERNAME / ADMIN_PASSWORD"

fi


################################################
# rclone 数据恢复
################################################

if [ -n "${RCLONE_CONF:-}" ]; then

    echo
    echo "=============================================="
    echo "rclone 数据恢复"
    echo "=============================================="


    if [ -n "${REMOTE_FOLDER:-}" ]; then

        echo "REMOTE_FOLDER=$REMOTE_FOLDER"


        if rclone ls "$REMOTE_FOLDER" \
            >/dev/null 2>&1
        then

            mkdir -p "$QL_DIR/.tmp/data"


            COUNT=$(
                rclone ls "$REMOTE_FOLDER" 2>/dev/null \
                | wc -l
            )


            if [ "$COUNT" -gt 0 ]; then

                echo "发现 $COUNT 个远程文件"

                rclone sync \
                    "$REMOTE_FOLDER" \
                    "$QL_DIR/.tmp/data"


                real_time=true ql reload data


                echo "✔ 数据恢复完成"

            else

                echo "远程备份为空"

            fi

        else

            echo "⚠️ rclone 连接失败"

        fi

    else

        echo "⚠️ REMOTE_FOLDER 未设置"

    fi

else

    echo "没有 RCLONE_CONF"

fi


################################################
# 通知
################################################

if [ -n "${NOTIFY_CONFIG:-}" ]; then

    echo
    echo "=============================================="
    echo "通知配置"
    echo "=============================================="


    python /notify.py || true


    sleep 10


    if [ -f "$QL_DIR/shell/api.sh" ]; then

        source "$QL_DIR/shell/api.sh"

        notify_api \
            "青龙服务启动通知" \
            "青龙面板成功启动" \
            || true

    fi

else

    echo "没有通知配置"

fi


################################################
# 最终检查
################################################

echo
echo "=============================================="
echo "最终端口状态"
echo "=============================================="


echo
echo "QingLong 5600："

ss -ltnp 2>/dev/null | grep ':5600' \
    || echo "❌ 5600 未监听"


echo
echo "Platform $PLATFORM_PORT："

ss -ltnp 2>/dev/null | grep ":$PLATFORM_PORT" \
    || echo "❌ $PLATFORM_PORT 未监听"


echo
echo "全部监听："

ss -ltnp 2>/dev/null || true


################################################
# PM2 最终
################################################

echo
echo "=============================================="
echo "最终 PM2"
echo "=============================================="


pm2 status || true


################################################
# 最终健康检查
################################################

echo
echo "=============================================="
echo "最终健康检查"
echo "=============================================="


if curl -fsS \
    --max-time 10 \
    "http://127.0.0.1:$QL_INTERNAL_PORT/" \
    >/dev/null
then

    echo "✔ QingLong 内部 HTTP 正常"

else

    echo "❌ QingLong 内部 HTTP 异常"

fi


if curl -fsS \
    --max-time 10 \
    "http://127.0.0.1:$PLATFORM_PORT/" \
    >/dev/null
then

    echo "✔ Platform nginx HTTP 正常"

else

    echo "❌ Platform nginx HTTP 异常"

fi


################################################
# 完成
################################################

echo
echo "=============================================="
echo "🔥 QingLong + nginx V12 启动完成"
echo "=============================================="

echo
echo "架构："
echo
echo "beta.blitz PORT=$PLATFORM_PORT"
echo "        ↓"
echo "      nginx"
echo "        ↓"
echo "127.0.0.1:$QL_INTERNAL_PORT"
echo "        ↓"
echo "    QingLong"
echo
echo "=============================================="


################################################
# 保持容器运行
################################################

tail -f /dev/null
