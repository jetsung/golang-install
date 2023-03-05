# Go 语言安装

- 支持 **Linux / MacOS / FreeBSD** 等系统

[English](./README.md) | 简体中文

---

# Golang Version Manager `[gvm.sh]`

## 安装

```bash
curl -fsL https://jihulab.com/jetsung/golang-install/-/raw/main/gvm.sh | bash -s -- -i

# 或者
git clone https://jihulab.com/jetsung/golang-install.git
cd golang-install
./gvm.sh -i
```

## 帮助

```bash
# gvm -h

gvm 1.0.4
Golang Version Manager

USAGE:
    gvm [OPTIONS] <SUBCOMMANDS>

OPTIONS:
    -h, --help
                Print help information

    -i, --install
                Install Golang Version Manager

    -u, --update
                Update Golang Version Manager

    -v, --version
                Print Gvm version information

SUBCOMMANDS:
  current               Print the current go version
  install [version]     Install a new go version
  list                  List all locally installed go versions
  list-remote <more>    List all remote go versions
  uninstall             Uninstall a Go version
  use [version]         Change Go version
```

# Go 语言安装 `[install.sh]`

最新版 Go 语言一键安装脚本。

- 支持自定义**版本**
- 支持自定义**GOPATH**

**注意**

- GOROOT: `$HOME/.go`
- 默认安装最新版本的 **go version**, **GOPATH** 目录为 `$HOME/go`

## 安装

### 在线安装

#### 默认安装

```sh
curl -fsL https://jihulab.com/jetsung/golang-install/-/raw/main/install.sh | bash
```

#### 自定义安装

- **MY_DIY_GO_VERSION** 是自定义版本号, 例如： `1.12.8`
- **MY_DIY_GO_PATH** 是自定义版本号, 例如： `/home/myhome/go`

```sh
curl -fsL https://jihulab.com/jetsung/golang-install/-/raw/main/install.sh | bash -s -- -v MY_DIY_GO_VERSION -p MY_DIY_GO_PATH
```

### 离线执行

保存脚本并且命名为 **install.sh**

```sh
# 默认配置
bash install.sh

# 自定义
bash install.sh -v 1.12.8 -p /home/myhome/go
```

脚本可执行权限，那么同时可以自定义 Go 版本和 GOPATH。

```sh
# 添加可执行权限
chmod +x install.sh

# 默认配置
./install.sh

# 自定义
./install.sh -v 1.12.8 -p /home/myhome/go
```

**使用说明**

```
Go install

USAGE:
    install.sh [OPTIONS] <SUBCOMMANDS>

OPTIONS:
    -h, --help
                Print help information.

    -p, --path
                Set GOPATH. (default: $HOME/go)

    -r, --root
                Set GOROOT. (default: $HOME/.go)

    -v, --version
                Set golang version.

```

## License

This project is licensed under the [MIT license](./LICENSE).
