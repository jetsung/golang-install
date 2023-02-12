# Golang Install

- Support **Linux / MacOS / FreeBSD**

English | [简体中文](./README_CN.md)

---

# Golang Version Manager

## Install

```bash
curl -fsL https://github.com/jetsung/golang-install/raw/main/gvm.sh | bash -s -- -i
```

## Help

```bash
# ./gvm.sh -h

gvm 1.0.3
Golang Version Manager

USAGE:
    gvm.sh [OPTIONS] <SUBCOMMANDS>

OPTIONS:
    -h, --help
                Print help information

    -i, --install
                Install Golang Version Manager

    -u, --upgrade
                Upgrade Golang Version Manager

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

# Golang Install `[install.sh]`

The latest version of the golang is installed.

- Support custom **version**
- Support custom **GOPATH**

**Notice**

- GOROOT: `$HOME/.go`
- By default, the latest version of **go version** is installed, and the **GOPATH** directory is `$HOME/go`

## Installation

### Online

#### Default install

```sh
curl -fsL https://raw.githubusercontent.com/jetsung/golang-install/main/install.sh | bash
```

#### Custom version

- **MY_DIY_GO_VERSION** is a custom golang version, such as： `1.12.8`
- **MY_DIY_GO_PATH** is a custom gopath, such as： `/home/myhome/go`

```sh
curl -fsL https://raw.githubusercontent.com/jetsung/golang-install/main/install.sh | bash -s -- -v MY_DIY_GO_VERSION -d MY_DIY_GO_PATH
```

### Offline

Save the script as a file name **install.sh**

```sh
# default install
bash install.sh

# customize
bash install.sh -v 1.12.8 -d /home/myhome/go
```

When you add executable permissions, you can customize the version and gopath.

```sh
# add executable
chmod +x install.sh

# default install
./install.sh

# customize
./install.sh -v 1.12.8 -d /home/myhome/go
```

**Usage**  
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
