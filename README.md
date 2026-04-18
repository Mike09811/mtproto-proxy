# MTProto Proxy

基于 [alexbers/mtprotoproxy](https://github.com/alexbers/mtprotoproxy) 的 Telegram MTProto 代理，支持频道/群组推广（adtag）。

## 特性

- TLS 伪装模式，流量伪装为正常 HTTPS，不易被检测
- 支持 adtag 频道推广（通过 `@MTProxybot` 获取）
- 支持多用户、用户过期时间、流量配额
- 无法识别的连接自动转发到伪装域名
- 单核 1G 内存可承载约 4000 并发用户
- 纯 Python，零依赖即可运行

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mike09811/mtproto-proxy/main/install.sh)
```

按提示输入端口、密钥、TLS 域名和推广 TAG 即可，全程交互式。

卸载：

```bash
bash /opt/mtproto-proxy/install.sh uninstall
```

## 手动部署

### 方式一：Docker（推荐）

```bash
git clone https://github.com/Mike09811/mtproto-proxy.git
cd mtproto-proxy

# 1. 编辑配置
vi config.py

# 2. 启动
docker-compose up -d

# 3. 查看代理链接
docker-compose logs
```

### 方式二：直接运行

```bash
git clone https://github.com/Mike09811/mtproto-proxy.git
cd mtproto-proxy

# 安装加密库（可选，大幅提升性能）
pip install cryptography

# 编辑配置
vi config.py

# 启动
python3 mtprotoproxy.py
```

### 方式三：systemd 服务

```bash
# 复制文件
sudo cp mtprotoproxy.py /opt/mtprotoproxy.py
sudo cp config.py /opt/config.py
sudo cp -r pyaes /opt/pyaes

# 创建服务
sudo tee /etc/systemd/system/mtprotoproxy.service << 'EOF'
[Unit]
Description=MTProto Proxy
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/mtprotoproxy.py /opt/config.py
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mtprotoproxy
sudo systemctl start mtprotoproxy
```

## 配置说明

编辑 `config.py`：

```python
# 监听端口
PORT = 443

# 用户密钥（32位hex），生成方法：head -c 16 /dev/urandom | xxd -ps
USERS = {
    "tg": "替换为你生成的密钥",
}

# TLS 伪装域名
TLS_DOMAIN = "go.microsoft.com"

# 推广 tag，从 @MTProxybot 获取
AD_TAG = "你的tag"
```

## 设置推广频道

1. 在 Telegram 中打开 `@MTProxybot`
2. 发送 `/newproxy`，按提示输入你的代理 IP 和端口
3. 绑定你要推广的频道
4. 获取 `AD_TAG`，填入 `config.py`
5. 重启代理

用户连接代理后，会在聊天列表顶部看到你推广的频道。

## 获取代理链接

启动后终端会输出类似以下内容：

```
tg://proxy?server=你的IP&port=443&secret=...
https://t.me/proxy?server=你的IP&port=443&secret=...
```

将链接分享给用户，点击即可连接。

## 性能优化

- 安装 `cryptography` 模块：`pip install cryptography`（性能提升数倍）
- 安装 `uvloop` 模块：`pip install uvloop`（额外提速）
- 可运行多个实例，客户端会自动负载均衡

## 致谢

- 原项目：[alexbers/mtprotoproxy](https://github.com/alexbers/mtprotoproxy)
