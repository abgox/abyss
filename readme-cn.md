<p align="center">
    <h1 align="center">✨ abyss ✨</h1>
</p>

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
> 推荐使用 [PSCompletions 中的 scoop 和 scoop-install 命令补全](https://gitee.com/abgox/PSCompletions)

> [!Warning]
>
> - `abyss` 中的应用清单是基于 [bin/utils.ps1](./bin/utils.ps1) 编写的
> - 如果其他 bucket 想要合并它们，请谨慎检查可用性

### 特性

#### Bucket

- `abyss` 参考并使用了 [winget-pkgs](https://github.com/microsoft/winget-pkgs) 的命名格式: `Publisher.PackageIdentifier`

#### Manifest

- 无法使用 [persist](#persist) 的应用，会使用 [Link](#link) 实现
- 当卸载和更新应用时，会先尝试终止进程，详情参考 [Config](#config)
- 优化了在安装和卸载过程中的信息输出
  - 根据语言环境使用对应的输出(中文或英文)
  - 如果安装和卸载过程中会修改环境变量，将显示环境变量的具体变化

---

### 如果你正在使用 Scoop

1. 添加 `abyss` (使用 Github 或 Gitee 仓库)

   ```pwsh
   scoop bucket add abyss https://github.com/abgox/abyss
   ```

   ```pwsh
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 安装应用

   ```pwsh
   scoop install abyss/abgox.InputTip-zip
   ```

### 如果你没有使用 Scoop

- [什么是 Scoop?](https://scoop.sh/)
- [什么是 Scoop 中的 bucket?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [什么是 Scoop 中的应用清单(App-Manifests)?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [安装 Scoop](https://github.com/ScoopInstaller/Install)
- [Scoop 文档](https://github.com/ScoopInstaller/Scoop/wiki)

---

### 如果你无法访问 Github

> [!Tip]
>
> 如果因为网络问题无法访问 Github 资源，可以尝试以下方案

1. 使用 Gitee 仓库

   ```pwsh
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 安装 [scoop-install](https://gitee.com/abgox/scoop-install)

   ```pwsh
   scoop install abyss/abgox.scoop-install
   ```

3. 设置 url 替换配置

   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```

4. 使用 [scoop-install](https://gitee.com/abgox/scoop-install) 安装应用

   ```pwsh
   scoop-install abyss/abgox.InputTip-zip
   ```

5. 更多详情请查看 [scoop-install](https://gitee.com/abgox/scoop-install)

---

### Config

- `abyss` 中的应用会包含一些 [特性](#特性)，由配置项 `app-uninstall-action-level` 控制
- 你可以通过以下命令去设置

  ```pwsh
  scoop config app-uninstall-action-level 123
  ```

- 如果没有设置，则默认为 `1`

- 配置值的含义如下，你可以任意组合这些值，如 `12` 表示 `1` 和 `2` 都要执行

  | 可选的值 | 行为                                                |
  | :------: | --------------------------------------------------- |
  |   `0`    | 无额外操作                                          |
  |   `1`    | 卸载/更新时先尝试终止进程，然后进行卸载操作         |
  |   `2`    | 卸载时删除 Link 目录(通过 [Link](#link) 创建的目录) |
  |   `3`    | 卸载时删除临时数据                                  |

### Persist

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 在清单文件中提供了 `persist` 配置，可以持久化保存应用目录中的数据文件

  - 以 [abgox.PSCompletions](./bucket/abgox.PSCompletions.json) 为例, Scoop 会将其安装到 `D:\Scoop\apps\abgox.PSCompletions` 目录中
  - 然后会持久化(persist)数据目录和配置文件:

    - `D:\Scoop\apps\abgox.PSCompletions\completions` => `D:\Scoop\persist\abgox.PSCompletions\completions`
    - `D:\Scoop\apps\abgox.PSCompletions\data.json` => `D:\Scoop\persist\abgox.PSCompletions\data.json`

  - 当卸载 [abgox.PSCompletions](./bucket/abgox.PSCompletions.json) 时，Scoop 只会删除 `D:\Scoop\apps\abgox.PSCompletions` 目录，而不会删除 `D:\Scoop\persist\abgox.PSCompletions` 目录
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
- 以 [Microsoft.VisualStudioCode](./bucket/Microsoft.VisualStudioCode.json) 为例
  - [Microsoft.VisualStudioCode](./bucket/Microsoft.VisualStudioCode.json) 的数据目录是 `$env:AppData\Code` 和 `$env:UserProfile\.vscode`
  - `$env:AppData` = `$env:UserProfile\AppData\Roaming`
  - `$persist_dir` = `D:\Scoop\persist\Microsoft.VisualStudioCode`
  - 它会进行链接:
    - `$env:UserProfile\AppData\Roaming\Code` => `$persist_dir\AppData\Roaming\Code`
    - `$env:UserProfile\.vscode` => `$persist_dir\.vscode`

> [!Warning]
>
> - 部分应用的数据通过文件而不是目录进行存储，需要使用 SymbolicLink 进行链接
> - SymbolicLink 需要管理员权限，因此这些应用会被添加 `RequireAdmin` 标签

---

### 应用清单

[Gitee - abgox/abyss](https://gitee.com/abgox/abyss) 可能无法正常显示应用清单，请使用 [Github - abgox/abyss](https://github.com/abgox/abyss)

- [简体中文](./app-list-cn.md)
- [English](./app-list.md)
