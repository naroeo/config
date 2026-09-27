#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-09-27-QINGLONG-2.22.0-DEBIAN-BLITZ-DIAGNOSTIC-V11 🔥🔥🔥"
# 🔧 V11：
# 1. 全面检查 QingLong / PM2 / nginx / 端口
# 2. QingLong 固定内部端口 5600
# 3. 平台 PORT 只给 nginx
# 4. 检查谁占用 5600 / 5700
# 5. 检查 PM2 实际进程
# 6. 检查 QingLong 实际监听端口
# 7. 检查 nginx 最终配置
# 8. 防止 nginx 残留进程导致重复 bind
# 9. QingLong 健康检查失败时输出完整诊断
# 10. 不再静默吞掉关键启动错误


set -e


export PATH="$HOME/bin:$PATH"


################################################
# 基础变量
################################################

QL_DIR=${QL_DIR:-/ql}

dir_shell="$QL_DIR/shell"

# 🔧 V11：QingLong 内部固定端口
QL_INTERNAL_PORT=5600


echo
echo "=============================================="
echo "基础环境"
echo "=============================================="

echo "HOME=$HOME"
echo "USER=$(whoami)"
echo "QL_DIR=$QL_DIR"
echo "QL_INTERNAL_PORT=$QL_INTERNAL_PORT"
echo "PLATFORM_PORT=$PORT"




################################################
# 基础环境检查
################################################

echo
echo "=============================================="
echo "基础程序检查"
echo "=============================================="


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
echo "ss:"
ss --version 2>&1 | head -1 || true




################################################
# 加载青龙环境
################################################

echo
echo "=============================================="
echo "加载 QingLong 环境"
echo "=============================================="


if [ -f "$dir_shell/share.sh" ]; then

    echo "✔ share.sh 存在"

    . "$dir_shell/share.sh"

else

    echo "⚠️ share.sh 不存在"

fi



if [ -f "$dir_shell/env.sh" ]; then

    echo "✔ env.sh 存在"


    load_ql_envs || true


    export BACK_PORT="${ql_port}"
    export GRPC_PORT="${ql_grpc_port}"


    echo
    echo "QingLong 环境变量加载后："

    echo "ql_port=$ql_port"
    echo "ql_grpc_port=$ql_grpc_port"
    echo "BACK_PORT=$BACK_PORT"
    echo "GRPC_PORT=$GRPC_PORT"


    . "$dir_shell/env.sh"


    import_config "$@" || true


    fix_config || true


else

    echo "⚠️ env.sh 不存在"

fi




################################################
# 显示原始 QingLong 配置
################################################

echo
echo "=============================================="
echo "QingLong 配置诊断"
echo "=============================================="


if [ -f "$QL_DIR/.env" ]; then

    echo "===== $QL_DIR/.env ====="

    cat "$QL_DIR/.env" || true

    echo "========================"

else

    echo "⚠️ $QL_DIR/.env 不存在"

fi




################################################
# rclone配置
################################################

echo
echo "=============================================="
echo "写入 rclone 配置"
echo "=============================================="


if [ -n "$RCLONE_CONF" ]; then


    mkdir -p "$HOME/.config/rclone"


    printf '%s\n' "$RCLONE_CONF" \
    > "$HOME/.config/rclone/rclone.conf"


    chmod 600 "$HOME/.config/rclone/rclone.conf"


    echo "✔ rclone 配置完成"


else

    echo "没有检测到 RCLONE_CONF"

fi




################################################
# Platform PORT
################################################

echo
echo "=============================================="
echo "Platform PORT"
echo "=============================================="


echo "Platform PORT=$PORT"


if [ -z "$PORT" ]; then

    echo "❌ Platform PORT不存在"

    exit 1

fi




################################################
# 🔧 V11：固定 QingLong 内部端口
################################################

echo
echo "=============================================="
echo "设置 QingLong 内部端口"
echo "=============================================="


echo "目标 QingLong PORT=$QL_INTERNAL_PORT"


if [ -f "$QL_DIR/.env" ]; then


    if grep -q '^PORT=' "$QL_DIR/.env"; then

        sed -i \
        "s/^PORT=.*/PORT=$QL_INTERNAL_PORT/" \
        "$QL_DIR/.env"

    else

        echo "PORT=$QL_INTERNAL_PORT" >> "$QL_DIR/.env"

    fi


else

    echo "PORT=$QL_INTERNAL_PORT" > "$QL_DIR/.env"

fi


echo
echo "修改后的 QingLong .env："

grep -nE '^PORT=' "$QL_DIR/.env" || true


echo
echo "✔ QingLong 内部端口设置为 $QL_INTERNAL_PORT"




################################################
# 🔧 V11：检查 5600 / 5700 当前占用情况
################################################

echo
echo "=============================================="
echo "启动 QingLong 前端口检查"
echo "=============================================="


echo
echo "监听端口："

ss -ltnp 2>/dev/null || true


echo
echo "5600 占用情况："

ss -ltnp 2>/dev/null | grep ':5600' || echo "5600 当前没有监听"


echo
echo "Platform PORT $PORT 占用情况："

ss -ltnp 2>/dev/null | grep ":$PORT" || echo "$PORT 当前没有监听"




################################################
# 🔧 V11：检查 PM2
################################################

echo
echo "=============================================="
echo "PM2 启动前状态"
echo "=============================================="


pm2 status || true


echo
echo "PM2 qinglong 详细信息："

pm2 show qinglong || true




################################################
# 启动 PM2
################################################

echo
echo "=============================================="
echo "启动 PM2"
echo "=============================================="


reload_pm2


echo
echo "✔ reload_pm2 执行完成"


sleep 3




################################################
# 🔧 V11：PM2 启动后完整诊断
################################################

echo
echo "=============================================="
echo "PM2 启动后诊断"
echo "=============================================="


pm2 status || true


echo
echo "PM2 qinglong："

pm2 show qinglong || true


echo
echo "PM2 logs 最近 30 行："

pm2 logs qinglong --lines 30 --nostream 2>/dev/null || true




################################################
# 🔧 V11：进程诊断
################################################

echo
echo "=============================================="
echo "进程诊断"
echo "=============================================="


echo
echo "Node / QingLong 进程："

ps aux | grep -E 'node|qinglong' | grep -v grep || true


echo
echo "全部进程："

ps aux || true




################################################
# 🔧 V11：实际端口诊断
################################################

echo
echo "=============================================="
echo "QingLong 实际监听端口"
echo "=============================================="


ss -ltnp 2>/dev/null || true


echo
echo "5600："

ss -ltnp 2>/dev/null | grep ':5600' || echo "❌ 5600 没有监听"


echo
echo "$PORT："

ss -ltnp 2>/dev/null | grep ":$PORT" || echo "✔ $PORT 当前没有监听"




################################################
# 等待 QingLong
################################################

echo
echo "=============================================="
echo "等待 QingLong 健康检查"
echo "=============================================="


QL_READY=false


for i in {1..40}
do

    echo "[health] 第 $i/40 次检查"


    if curl -fsS \
    --max-time 5 \
    "http://127.0.0.1:$QL_INTERNAL_PORT/api/health" \
    >/tmp/qinglong-health.txt 2>&1

    then

        echo "✔ QingLong 健康检查成功"

        cat /tmp/qinglong-health.txt || true

        QL_READY=true

        break

    else

        echo "❌ QingLong 尚未响应"

        cat /tmp/qinglong-health.txt || true

    fi


    sleep 2

done




################################################
# 🔧 V11：如果 QingLong 未启动，完整诊断
################################################

if [ "$QL_READY" != "true" ]; then


    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "❌ QingLong 在 80 秒内没有通过 5600 健康检查"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"


    echo
    echo "========== PM2 =========="

    pm2 status || true

    pm2 show qinglong || true


    echo
    echo "========== QingLong 进程 =========="

    ps aux | grep -E 'node|qinglong' | grep -v grep || true


    echo
    echo "========== 所有监听端口 =========="

    ss -ltnp 2>/dev/null || true


    echo
    echo "========== 5600 =========="

    ss -ltnp 2>/dev/null | grep ':5600' || true


    echo
    echo "========== 5700 =========="

    ss -ltnp 2>/dev/null | grep ':5700' || true


    echo
    echo "========== .env =========="

    cat "$QL_DIR/.env" 2>/dev/null || true


    echo
    echo "========== PM2 最近日志 =========="

    pm2 logs qinglong --lines 100 --nostream 2>/dev/null || true


    echo
    echo "=============================================="
    echo "❌ 停止启动流程"
    echo "=============================================="


    exit 1

fi




################################################
# nginx
################################################

echo
echo "=============================================="
echo "启动 nginx"
echo "=============================================="


echo "nginx Platform PORT=$PORT"
echo "QingLong internal PORT=$QL_INTERNAL_PORT"




################################################
# 🔧 V11：清理 nginx 残留
################################################

echo
echo "检查 nginx 旧进程："

ps aux | grep nginx | grep -v grep || echo "没有发现 nginx 进程"


echo
echo "停止旧 nginx："

nginx -s quit 2>/dev/null || true

sleep 1


pkill -TERM nginx 2>/dev/null || true

sleep 1


echo
echo "nginx 清理后："

ps aux | grep nginx | grep -v grep || echo "✔ nginx 已清理"




################################################
# nginx 配置
################################################

if [ -f /etc/nginx/conf.d/front.conf ]; then


    envsubst '$PORT' \
    < /etc/nginx/conf.d/front.conf \
    > /tmp/front.conf


    mv \
    /tmp/front.conf \
    /etc/nginx/conf.d/front.conf


    echo "✔ nginx Platform PORT替换完成"


else

    echo "❌ /etc/nginx/conf.d/front.conf 不存在"

    exit 1

fi




################################################
# 🔧 V11：显示最终 nginx 配置
################################################

echo
echo "=============================================="
echo "最终 nginx front.conf"
echo "=============================================="


cat /etc/nginx/conf.d/front.conf


echo
echo "=============================================="
echo "nginx 配置测试"
echo "=============================================="


nginx -t




################################################
# 🔧 V11：启动 nginx 前再次检查 PORT
################################################

echo
echo "=============================================="
echo "nginx 启动前端口检查"
echo "=============================================="


echo
echo "5600："

ss -ltnp 2>/dev/null | grep ':5600' || echo "⚠️ 5600 未监听"


echo
echo "Platform PORT=$PORT："

ss -ltnp 2>/dev/null | grep ":$PORT" || echo "✔ $PORT 当前空闲"


echo
echo "全部监听端口："

ss -ltnp 2>/dev/null || true




################################################
# nginx 启动
################################################

echo
echo "启动 nginx..."

nginx


sleep 2




################################################
# nginx 启动后检查
################################################

echo
echo "=============================================="
echo "nginx 启动后诊断"
echo "=============================================="


ps aux | grep nginx | grep -v grep || true


echo
echo "监听端口："

ss -ltnp 2>/dev/null || true


echo
echo "Platform PORT=$PORT："

ss -ltnp 2>/dev/null | grep ":$PORT" || true


echo
echo "测试 nginx："

curl -fsS \
--max-time 10 \
"http://127.0.0.1:$PORT/" \
-o /tmp/nginx-test.html \
|| true


if [ -f /tmp/nginx-test.html ]; then

    echo "✔ nginx HTTP 测试完成"

    head -c 500 /tmp/nginx-test.html || true

    echo

else

    echo "⚠️ nginx HTTP 测试失败"

fi




################################################
# 管理员初始化
################################################

sleep 5


if [ -n "$ADMIN_USERNAME" ] && \
   [ -n "$ADMIN_PASSWORD" ]

then


echo
echo "########## 初始化管理员 ##########"


curl -sS \
"http://127.0.0.1:$QL_INTERNAL_PORT/api/user/init?t=$(date +%s)" \
-X PUT \
-H "Content-Type: application/json;charset=UTF-8" \
--data \
"{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" \
| jq || true


fi




################################################
# rclone恢复
################################################

if [ -n "$RCLONE_CONF" ]; then


echo
echo "########## rclone恢复 ##########"


if rclone ls "$REMOTE_FOLDER" >/dev/null 2>&1

then


mkdir -p "$QL_DIR/.tmp/data"


COUNT=$(rclone ls "$REMOTE_FOLDER" | wc -l)


if [ "$COUNT" -gt 0 ]

then


rclone sync \
"$REMOTE_FOLDER" \
"$QL_DIR/.tmp/data"


real_time=true ql reload data


echo "✔ 数据恢复完成"


else

echo "首次安装，没有备份"

fi


else

echo "⚠️ rclone连接失败"

fi


fi




################################################
# notify
################################################

if [ -n "$NOTIFY_CONFIG" ]; then


echo
echo "########## 通知 ##########"


python /notify.py || true


sleep 10


source "$QL_DIR/shell/api.sh"


notify_api \
"青龙服务启动通知" \
"青龙面板成功启动"


else

echo "没有通知配置"

fi




################################################
# 最终状态
################################################

echo
echo "=============================================="
echo "最终端口状态"
echo "=============================================="


echo
echo "5600 = QingLong 内部："

ss -ltnp 2>/dev/null | grep ':5600' || echo "❌ 5600 未监听"


echo
echo "$PORT = nginx 平台端口："

ss -ltnp 2>/dev/null | grep ":$PORT" || echo "❌ $PORT 未监听"


echo
echo "全部监听端口："

ss -ltnp 2>/dev/null || true


echo
echo "=============================================="
echo "最终 PM2 状态"
echo "=============================================="


pm2 status || true


echo
echo "=============================================="
echo "QingLong + nginx 启动完成"
echo "=============================================="


# 保持容器运行

tail -f /dev/null
