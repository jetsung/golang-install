# Go 语言安装
---

最新版 Go 语言一键安装脚本。 
- 支持 **Linux / MacOS / FreeBSD** 等系统
- 支持自定义**版本**
- 支持自定义**GOPATH**

[English](./README.md) | 简体中文

#### 注意
- GOROOT: `$HOME/.go`
- 默认安装最新版本的 **go version**, **GOPATH** 目录为 ```$HOME/go```

## 安装
### 在线安装
#### 默认安装
```sh
curl -fsL https://jihulab.com/jetsung/golang-install/-/raw/main/install.sh | bash
```

#### 自定义安装
- **MY_DIY_GO_VERSION** 是自定义版本号, 例如： ```1.12.8```
- **MY_DIY_GO_PATH** 是自定义版本号, 例如： ```/home/myhome/go```

```sh
curl -fsL https://jihulab.com/jetsung/golang-install/-/raw/main/install.sh | bash -s -- -v MY_DIY_GO_VERSION -d MY_DIY_GO_PATH
```

### 离线执行
保存脚本并且命名为 **install.sh**    

```sh
# 默认配置
bash install.sh

# 自定义    
bash install.sh -v 1.12.8 -d /home/myhome/go 
```
  
脚本可执行权限，那么同时可以自定义 Go 版本和 GOPATH。  
```sh
# 添加可执行权限
chmod +x install.sh   

# 默认配置
./install.sh

# 自定义
./install.sh -v 1.12.8 -d /home/myhome/go
```

**使用说明**    
./install.sh -h
```
Go install

Usage: ./install.sh [-h] [-v version] [-d gopath]

Options:
  -h            : this help
  -v            : set go version (default: latest version)
  -d            : set go path (default: $HOME/go)
```

## License

This project is licensed under the [MIT license](./LICENSE).