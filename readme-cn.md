<h1 align="center">✨ abyss ✨</h1>

<p align="center">
    <a href="readme.md">English</a> |
    <a href="readme-cn.md">简体中文</a> |
    <a href="https://github.com/abgox/abyss">Github</a> |
    <a href="https://gitee.com/abgox/abyss">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/abyss/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/abyss" alt="license" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/abyss.svg">
        <img src="https://img.shields.io/github/languages/code-size/abgox/abyss.svg" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/abyss.svg">
        <img src="https://img.shields.io/github/repo-size/abgox/abyss.svg" alt="code size" />
    </a>
    <a href="https://github.com/abgox/abyss">
        <img src="https://img.shields.io/github/created-at/abgox/abyss" alt="created" />
    </a>
</p>

> [!Tip]
>
> 推荐使用 [PSCompletions 中的 scoop/scoop-install/scoop-update 命令补全](https://gitee.com/abgox/PSCompletions)

> [!Warning]
>
> - `abyss` 中的应用清单是基于 [bin/utils.ps1](./bin/utils.ps1) 编写的
> - 它们包含 Scoop 官方规范之外的 [风格特性](#特性)，其他 bucket 不应该合并它们

> Just like the abyss — limitless, mysterious, and filled with treasures.

### 特性

#### Bucket

- `abyss` 参考了 [winget-pkgs](https://github.com/microsoft/winget-pkgs)
  - 清单命名格式: `Publisher.PackageIdentifier`
  - 目录结构: `bucket/a/abgox/abgox.PSCompletions.json`

#### Manifest

- 无法使用 [persist](#persist) 的应用，会使用 [Link](#link) 实现
- 当卸载和更新应用时，会先尝试终止进程，详情参考 [Config](#config)
- 优化了在安装和卸载过程中的信息输出
  - 根据语言环境使用对应的输出
    - `zh-CN`: 简体中文
    - `en-US`: 英文
  - 如果安装和卸载过程中会修改环境变量，将显示环境变量的具体变化

---

### 如果你没有使用 Scoop

- [Scoop](https://scoop.sh/)
- [Scoop 文档](https://github.com/ScoopInstaller/Scoop/wiki)
- [什么是 Scoop 中的 bucket?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [什么是 Scoop 中的应用清单(App Manifests)?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)

### 如果你正在使用 Scoop

> [!Warning]
>
> 请确保使用 `abyss` 作为 bucket 的名称，避免部分清单在解析 depends 时找不到 bucket

1. 添加 `abyss` (使用 Github 或 Gitee 仓库)

   ```powershell
   scoop bucket add abyss https://github.com/abgox/abyss
   ```

   ```powershell
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 使用 [PSCompletions](https://gitee.com/abgox/PSCompletions) 添加 `scoop` 命令补全

   ```powershell
   scoop install abyss/abgox.PSCompletions
   ```

   ```powershell
   Import-Module PSCompletions
   ```

   ```powershell
   psc add scoop
   ```

3. 安装应用

   ```powershell
   scoop install abyss/Microsoft.PowerShell
   ```

### 演示

![演示](https://abyss.abgox.com/demo-cn.gif)

---

### 如果你访问 Github 存在问题

> [!Tip]
>
> 如果因为网络问题无法快速访问 Github 资源，可以尝试以下方案

1. 使用 Gitee 仓库

   ```powershell
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 安装 [scoop-install](https://gitee.com/abgox/scoop-tools) 和 [scoop-update](https://gitee.com/abgox/scoop-tools)

   ```powershell
   scoop install abyss/abgox.scoop-install
   ```

   ```powershell
   scoop install abyss/abgox.scoop-update
   ```

3. 设置 url 替换

   ```powershell
   scoop config scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"
   ```

4. 使用 [PSCompletions](https://github.com/abgox/PSCompletions) 添加命令补全

   ```powershell
   psc add scoop-install scoop-update
   ```

5. 使用 [scoop-install](https://gitee.com/abgox/scoop-tools) 安装应用

   ```powershell
   scoop-install abyss/Microsoft.PowerShell
   ```

6. 使用 [scoop-update](https://gitee.com/abgox/scoop-tools) 更新应用

   ```powershell
   scoop-update abyss/Microsoft.PowerShell
   ```

7. 更多详情请查看:

   - https://github.com/abgox/scoop-tools
   - https://gitee.com/abgox/scoop-tools

---

### Config

#### abgox-abyss-app-uninstall-action

- 使用此配置项控制应用卸载时的额外操作
- 你可以通过以下命令去设置

  ```powershell
  scoop config abgox-abyss-app-uninstall-action 123
  ```

- 如果没有设置，则默认为 `1`

- 配置值的含义如下，你可以任意组合这些值，如 `12` 表示 `1` 和 `2` 都要执行
- 如果不希望有这些额外行为，设置为不包含它们的任意值即可

  | 配置值 | 行为                                                |
  | :----: | --------------------------------------------------- |
  |  `1`   | 卸载/更新时先尝试终止进程，然后进行卸载操作         |
  |  `2`   | 卸载时删除 Link 目录(通过 [Link](#link) 创建的目录) |
  |  `3`   | 卸载时删除临时数据                                  |

#### abgox-abyss-app-shortcuts-action

- 由于 `abyss` 中的一些应用直接使用安装程序安装，安装程序会自动创建快捷方式
- Scoop 也会创建清单中定义的快捷方式，这会导致存在多个重复的快捷方式
- 因此，你可以使用此配置项控制是否创建清单中定义的快捷方式

  ```powershell
  scoop config abgox-abyss-app-shortcuts-action 2
  ```

- 如果没有设置，则默认为 `1`
- 配置值的含义如下

  | 配置值 | 行为                                                                       |
  | :----: | -------------------------------------------------------------------------- |
  |  `0`   | **不创建** 清单中定义的快捷方式                                            |
  |  `1`   | **创建** 清单中定义的快捷方式                                              |
  |  `2`   | 如果应用使用安装程序， 就 **不创建** 清单中定义的快捷方式，否则就 **创建** |

#### abgox-abyss-bucket-name

- 此配置项用于记录添加到本地的 `abyss` 的名称，然后在部分特殊情况中使用
- 它不需要手动修改，当安装/更新/卸载 `abyss` 中的应用时，会自动更新此配置项
- 举个例子：
  - 如果你使用了 `scoop install abyss/JetBrains.WebStorm@2025.1.2` 指定 `2025.1.2` 版本
  - 安装时会用到这个配置项的值，避免安装错误
- 参考: https://github.com/abgox/abyss/issues/10

### Persist

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 在清单文件中提供了 `persist` 配置，可以持久化保存应用目录中的数据文件

  - 以 [abgox.PSCompletions](./bucket/a/abgox/abgox.PSCompletions.json) 为例, Scoop 会将其安装到 `D:\Scoop\apps\abgox.PSCompletions` 目录中
  - 然后会持久化(persist)数据目录和配置文件:

    - `D:\Scoop\apps\abgox.PSCompletions\completions` => `D:\Scoop\persist\abgox.PSCompletions\completions`
    - `D:\Scoop\apps\abgox.PSCompletions\data.json` => `D:\Scoop\persist\abgox.PSCompletions\data.json`

  - 当卸载 [abgox.PSCompletions](./bucket/a/abgox/abgox.PSCompletions.json) 时，Scoop 只会删除 `D:\Scoop\apps\abgox.PSCompletions` 目录，而不会删除 `D:\Scoop\persist\abgox.PSCompletions` 目录
    - 因此，它的设置、补全数据仍然会保存在 `D:\Scoop\persist\abgox.PSCompletions` 目录中
    - 重新安装后，又会继续使用这些数据
  - 如果卸载时使用了 `-p/--purge` 参数，`D:\Scoop\persist\abgox.PSCompletions` 目录才会被删除

- 这是 Scoop 最强大的特性，可以快速的恢复自己的应用环境
  - `abyss` 中的一些应用使用了 [Link](#link)，无法通过 `scoop reset` 正确重置
  - 建议通过 `scoop update --force <app>` 强制更新应用

### Link

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 的 persist 功能很强大，遗憾的是它有局限性: 只有应用数据在应用安装目录中，才可以使用它
- 但是有些应用的数据是存储在安装目录之外的，常见的是在 `$env:AppData` 目录中
- 像这样的应用，`abyss` 选择使用 `New-Item -ItemType Junction` 进行链接
- 以 [Microsoft.VisualStudioCode](./bucket/m/Microsoft/Microsoft.VisualStudioCode.json) 为例
  - [Microsoft.VisualStudioCode](./bucket/m/Microsoft/Microsoft.VisualStudioCode.json) 的数据目录是 `$env:AppData\Code` 和 `$env:UserProfile\.vscode`
  - `$env:AppData` = `$env:UserProfile\AppData\Roaming`
  - `$persist_dir` = `D:\Scoop\persist\Microsoft.VisualStudioCode`
  - 它会进行链接:
    - `$env:UserProfile\AppData\Roaming\Code` => `$persist_dir\AppData\Roaming\Code`
    - `$env:UserProfile\.vscode` => `$persist_dir\.vscode`

> [!Warning]
>
> - 部分应用的数据通过文件而不是目录进行存储，需要使用 SymbolicLink 进行链接
> - SymbolicLink 需要管理员权限，因此在 [应用清单](#应用清单) 中这些应用会被添加 `RequireAdmin` 标签

---

### 应用清单

[Gitee - abgox/abyss](https://gitee.com/abgox/abyss) 可能无法正常显示应用清单，请使用 [Github - abgox/abyss](https://github.com/abgox/abyss)

- [简体中文](./app-list-cn.md)
- [English](./app-list.md)
