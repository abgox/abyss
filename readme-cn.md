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
> - 如果其他 bucket 想要合并它们，请谨慎检查

### 如果你正在使用 Scoop

1. 添加 `abyss` (使用 Github 或 Gitee 仓库)

   ```pwsh
   scoop bucket add abyss https://github.com/abgox/abyss
   ```

   ```pwsh
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 安装应用(以 `InputTip-zip` 举例)

   ```pwsh
   scoop install abyss/InputTip-zip
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
   scoop install abyss/scoop-install
   ```

3. 设置 url 替换配置

   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```

4. 使用 [scoop-install](https://gitee.com/abgox/scoop-install) 安装应用

   ```pwsh
   scoop-install abyss/InputTip-zip
   ```

5. 更多详情请查看 [scoop-install](https://gitee.com/abgox/scoop-install)

---

### Config

- `abyss` 中的应用会有一些特性，由配置项 `app-uninstall-action-level` 控制
- 你可以通过以下命令去设置

  ```pwsh
  scoop config app-uninstall-action-level 123
  ```

- 如果没有设置，则默认为 `1`

- 配置值的含义如下，你可以任意组合这些值，如 `12` 表示 `1` 和 `2` 都要执行

  | 可选的值 | 行为                                                |
  | :------: | --------------------------------------------------- |
  |   `0`    | 无额外操作                                          |
  |   `1`    | 卸载时先尝试终止进程，然后进行卸载操作              |
  |   `2`    | 卸载时删除 Link 目录(通过 [Link](#link) 创建的目录) |
  |   `3`    | 卸载时删除临时数据                                  |

### Persist

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 在清单文件中提供了 `persist` 配置，可以持久化保存应用目录中的数据文件

  - 以 [PSCompletions](./bucket/PSCompletions.json) 为例, Scoop 会将其安装到 `D:\Scoop\apps\PSCompletions` 目录中
  - 然后会持久化(persist)数据目录和配置文件:

    - `D:\Scoop\apps\PSCompletions\completions` => `D:\Scoop\persist\PSCompletions\completions`
    - `D:\Scoop\apps\PSCompletions\data.json` => `D:\Scoop\persist\PSCompletions\data.json`

  - 当卸载 [PSCompletions](./bucket/PSCompletions.json) 时，Scoop 只会删除 `D:\Scoop\apps\PSCompletions` 目录，而不会删除 `D:\Scoop\persist\PSCompletions` 目录
    - 因此，它的设置、补全数据仍然会保存在 `D:\Scoop\persist\PSCompletions` 目录中
    - 重新安装后，又会继续使用这些数据
  - 如果卸载时使用了 `-p/--purge` 参数，`D:\Scoop\persist\PSCompletions` 目录才会被删除

- 这是 Scoop 最强大的特性，可以快速的恢复自己的应用环境
  - 一些应用使用了 [Link](#link)，无法通过 `scoop reset` 正确重置
  - 建议通过 `scoop uninstall` 卸载应用，然后再重新安装

### Link

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 的 persist 功能很强大，遗憾的是它有局限性: 只有应用数据在应用安装目录中，才可以使用它
- 但是有些应用的数据是存储在安装目录之外的，常见的是在 `$env:AppData` 目录中
- 像这样的应用，`abyss` 选择使用 `New-Item -ItemType Junction` 进行链接
- 以 [Helix](./bucket/Helix.json) 为例
  - [Helix](./bucket/Helix.json) 的数据目录是 `$env:AppData\helix`
  - 它会进行链接: `$env:AppData\helix` => `D:\Scoop\persist\Helix\helix`

> [!Warning]
>
> - 部分应用的数据通过文件而不是目录进行存储，需要使用 SymbolicLink 进行链接
> - SymbolicLink 需要管理员权限，因此这些应用会被添加 `Admin` 标签

---

### 应用清单

[English](readme.md#app-manifests) | [简体中文](./readme-cn.md#应用清单)

- 说明

  - **`App`**：应用包的名称
    - 点击查看官网或仓库
    - 按照数字字母排序(0-9,a-z)
  - **`Version`**：应用版本
    - 点击查看应用清单 json 文件
  - **`Persist`**：持久化应用数据, 详情参考 [Persist](#persist)
    - **`✔️`**：已实现
    - **`➖`**：没有必要或者没有数据文件
    - **`Link`** : 使用 `New-Item -ItemType Junction` 实现, 详情参考 [Link](#link)
  - **`Tag`**：应用标签

    - `Font`：一种字体
    - `PSModule`：一个 [PowerShell 模块](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules)
    - `NoUpdate`：没有配置 `json.autoupdate`，Scoop 无法自动检测更新
    - `Msix`: 通过 [Msix](https://learn.microsoft.com/windows/msix/overview) 打包的应用
      - 它的安装目录不在 Scoop 中
      - Scoop 只管理 [persist](#persist)，应用的安装、更新以及卸载操作。
    - `AdminToInstall`: 需要使用管理员权限才能安装的应用
      - 因为应用的数据通过文件而不是目录进行存储，需要使用 SymbolicLink 进行链接，而 SymbolicLink 需要管理员权限

  - **`Description`**：应用描述

---

<!-- prettier-ignore-start -->
|App (105)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[Apifox](https://apifox.com "点击查看 Apifox 的主页或仓库")|<a href="./bucket/Apifox.json" title="点击查看 Apifox 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FApifox.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Apifox 使用 Link 进行数据持久化">`Link`</code>||API 设计、开发、测试一体化协作平台。|
|[AppFlowy](https://www.appflowy.io/ "点击查看 AppFlowy 的主页或仓库")|<a href="./bucket/AppFlowy.json" title="点击查看 AppFlowy 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FAppFlowy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="AppFlowy 使用 Link 进行数据持久化">`Link`</code>||一个开源的 Notion 替代品，数据和定制由你掌控。|
|[Beekeeper-Studio](https://www.beekeeperstudio.io "点击查看 Beekeeper-Studio 的主页或仓库")|<a href="./bucket/Beekeeper-Studio.json" title="点击查看 Beekeeper-Studio 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBeekeeper-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Beekeeper-Studio 使用 Link 进行数据持久化">`Link`</code>||一款跨平台的 SQL 编辑器和数据库管理器。|
|[Bilibili](https://app.bilibili.com/ "点击查看 Bilibili 的主页或仓库")|<a href="./bucket/Bilibili.json" title="点击查看 Bilibili 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBilibili.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Bilibili 使用 Link 进行数据持久化">`Link`</code>||哔哩哔哩(Bilibili) 的 Windows 桌面程序。|
|[BongoCat](https://github.com/ayangweb/BongoCat "点击查看 BongoCat 的主页或仓库")|<a href="./bucket/BongoCat.json" title="点击查看 BongoCat 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBongoCat.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="BongoCat 使用 Link 进行数据持久化">`Link`</code>||一个跨平台桌宠。|
|[Bruno](https://www.usebruno.com/ "点击查看 Bruno 的主页或仓库")|<a href="./bucket/Bruno.json" title="点击查看 Bruno 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBruno.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Bruno 使用 Link 进行数据持久化">`Link`</code>||用于探索和测试 API 的开源集成开发环境 (Postman/Insomnia 的轻量级替代品)。|
|[Carnac](http://carnackeys.com/ "点击查看 Carnac 的主页或仓库")|<a href="./bucket/Carnac.json" title="点击查看 Carnac 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCarnac.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Carnac 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个键盘按键记录和演示实用程序。|
|[Cherry-Studio](https://cherry-ai.com "点击查看 Cherry-Studio 的主页或仓库")|<a href="./bucket/Cherry-Studio.json" title="点击查看 Cherry-Studio 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCherry-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Cherry-Studio 使用 Link 进行数据持久化">`Link`</code>||一款支持多个大语言模型 (LLM) 供应商的桌面客户端。|
|[clash-verge-rev](https://github.com/clash-verge-rev/clash-verge-rev "点击查看 clash-verge-rev 的主页或仓库")|<a href="./bucket/clash-verge-rev.json" title="点击查看 clash-verge-rev 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fclash-verge-rev.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="clash-verge-rev 使用 Link 进行数据持久化">`Link`</code>||一款基于 Tauri 的现代图形用户界面客户端，提供定制化的代理体验。|
|[Clink](https://chrisant996.github.io/clink/ "点击查看 Clink 的主页或仓库")|<a href="./bucket/Clink.json" title="点击查看 Clink 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FClink.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Clink 使用 Link 进行数据持久化">`Link`</code>||Bash 在 cmd.exe 中强大的命令行编辑功能。|
|[ContextMenuManager](https://github.com/BluePointLilac/ContextMenuManager "点击查看 ContextMenuManager 的主页或仓库")|<a href="./bucket/ContextMenuManager.json" title="点击查看 ContextMenuManager 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FContextMenuManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="ContextMenuManager 使用 Link 进行数据持久化">`Link`</code>||一个纯粹的 Windows 右键菜单管理程序。|
|[Coriander-Player](https://github.com/Ferry-200/coriander_player "点击查看 Coriander-Player 的主页或仓库")|<a href="./bucket/Coriander-Player.json" title="点击查看 Coriander-Player 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCoriander-Player.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Coriander-Player 使用 Link 进行数据持久化">`Link`</code>||一个 Windows 上的本地音乐播放器。|
|[DevToys](https://devtoys.app/ "点击查看 DevToys 的主页或仓库")|<a href="./bucket/DevToys.json" title="点击查看 DevToys 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FDevToys.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="DevToys 使用 Link 进行数据持久化">`Link`</code>|<code title="DevToys 通过 Msix 安装，安装目录不在 Scoop 中，Scoop 只管理数据、安装、卸载、更新">`Msix`</code>|开发人员的瑞士军刀。|
|[DownKyi](https://github.com/leiurayer/downkyi "点击查看 DownKyi 的主页或仓库")|<a href="./bucket/DownKyi.json" title="点击查看 DownKyi 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FDownKyi.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="DownKyi 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个B站(bilibili)视频下载工具。|
|[draw.io](https://www.diagrams.net "点击查看 draw.io 的主页或仓库")|<a href="./bucket/draw.io.json" title="点击查看 draw.io 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fdraw.io.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="draw.io 使用 Link 进行数据持久化">`Link`</code>||一款基于 Electron 的桌面绘图应用程序，它封装了 draw.io 核心编辑器。|
|[Drawpile](https://drawpile.net/ "点击查看 Drawpile 的主页或仓库")|<a href="./bucket/Drawpile.json" title="点击查看 Drawpile 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FDrawpile.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Drawpile 使用 Link 进行数据持久化">`Link`</code>||一款绘图程序，能让你与他人在同一画布上共同进行绘制、涂色和制作动画。|
|[Escrcpy](https://github.com/viarotel-org/escrcpy "点击查看 Escrcpy 的主页或仓库")|<a href="./bucket/Escrcpy.json" title="点击查看 Escrcpy 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEscrcpy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Escrcpy 使用 Link 进行数据持久化">`Link`</code>||使用图形化的 Scrcpy 显示和控制您的 Android 设备，由 Electron 驱动。|
|[eSearch](https://esearch-app.netlify.app/ "点击查看 eSearch 的主页或仓库")|<a href="./bucket/eSearch.json" title="点击查看 eSearch 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FeSearch.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="eSearch 使用 Link 进行数据持久化">`Link`</code>||截屏 离线OCR 搜索翻译 以图搜图 贴图 录屏 万向滚动截屏 屏幕翻译。|
|[Everything-Lite](https://www.voidtools.com "点击查看 Everything-Lite 的主页或仓库")|<a href="./bucket/Everything-Lite.json" title="点击查看 Everything-Lite 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEverything-Lite.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Everything-Lite 使用 Link 进行数据持久化">`Link`</code>||(Lite 版本，不包含 IPC 和 ETP/FTP/HTTP 服务器) 文件搜索工具，基于名称快速定位文件和文件夹。|
|[Everything](https://www.voidtools.com "点击查看 Everything 的主页或仓库")|<a href="./bucket/Everything.json" title="点击查看 Everything 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEverything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Everything 使用 Link 进行数据持久化">`Link`</code>||文件搜索工具，基于名称快速定位文件和文件夹。|
|[ExplorerTabUtility](https://github.com/w4po/ExplorerTabUtility "点击查看 ExplorerTabUtility 的主页或仓库")|<a href="./bucket/ExplorerTabUtility.json" title="点击查看 ExplorerTabUtility 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FExplorerTabUtility.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="ExplorerTabUtility 使用 Link 进行数据持久化">`Link`</code>||提升 Windows 11 文件资源管理器的功能：自动将窗口转换为标签页、复制标签页、重新打开已关闭的标签页等等。|
|[Fishing-Funds](https://ff.1zilc.top/ "点击查看 Fishing-Funds 的主页或仓库")|<a href="./bucket/Fishing-Funds.json" title="点击查看 Fishing-Funds 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFishing-Funds.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Fishing-Funds 使用 Link 进行数据持久化">`Link`</code>||一款跨平台的基金股票行情监控工具。|
|[Flow-Launcher](https://www.flowlauncher.com "点击查看 Flow-Launcher 的主页或仓库")|<a href="./bucket/Flow-Launcher.json" title="点击查看 Flow-Launcher 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFlow-Launcher.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Flow-Launcher 使用 Scoop 官方的 persist 实现">`✔️`</code>||适用于 Windows 的快速文件搜索和应用程序启动器。|
|[Fluent-Search](https://github.com/adirh3/Fluent-Search "点击查看 Fluent-Search 的主页或仓库")|<a href="./bucket/Fluent-Search.json" title="点击查看 Fluent-Search 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFluent-Search.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Fluent-Search 使用 Scoop 官方的 persist 实现">`✔️`</code>||使用它，你可以搜索正在运行的应用程序、浏览器标签、应用程序内内容、文件等。|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts "点击查看 Font-Hack-NF 的主页或仓库")|<a href="./bucket/Font-Hack-NF.json" title="点击查看 Font-Hack-NF 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Hack-NF.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Font-Hack-NF 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>|<code title="Font-Hack-NF 是一个字体">`Font`</code>|Hack 字体，Nerd Font 系列。|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font "点击查看 Font-Maple-Mono-Normal-NL-NF-CN-Unhinted 的主页或仓库")|<a href="./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json" title="点击查看 Font-Maple-Mono-Normal-NL-NF-CN-Unhinted 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Maple-Mono-Normal-NL-NF-CN-Unhinted.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Font-Maple-Mono-Normal-NL-NF-CN-Unhinted 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>|<code title="Font-Maple-Mono-Normal-NL-NF-CN-Unhinted 是一个字体">`Font`</code>|(版本: Normal-NL-NF-CN-Unhinted，无连字) 一款带连字和控制台图标的圆角等宽字体，中英文宽度完美 2:1。|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic "点击查看 Font-Sarasa-Fixed-SC 的主页或仓库")|<a href="./bucket/Font-Sarasa-Fixed-SC.json" title="点击查看 Font-Sarasa-Fixed-SC 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Sarasa-Fixed-SC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Font-Sarasa-Fixed-SC 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>|<code title="Font-Sarasa-Fixed-SC 是一个字体">`Font`</code>|(版本: Fixed-SC，无连字) 一款中英文宽度完美 2:1 的等宽字体。|
|[FSViewer](https://www.faststone.org/FSViewerDetail.htm "点击查看 FSViewer 的主页或仓库")|<a href="./bucket/FSViewer.json" title="点击查看 FSViewer 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFSViewer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="FSViewer 使用 Scoop 官方的 persist 实现">`✔️`</code>||Faststone Image Viewer 是一个快速，稳定，用户友好的图像浏览器，转换器和编辑器。|
|[GeekUninstaller](https://geekuninstaller.com/ "点击查看 GeekUninstaller 的主页或仓库")|<a href="./bucket/GeekUninstaller.json" title="点击查看 GeekUninstaller 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGeekUninstaller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="GeekUninstaller 使用 Link 进行数据持久化">`Link`</code>||简单便捷的免费卸载程序。|
|[GitExtensions](https://gitextensions.github.io/ "点击查看 GitExtensions 的主页或仓库")|<a href="./bucket/GitExtensions.json" title="点击查看 GitExtensions 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGitExtensions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="GitExtensions 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个用于管理 Git 仓库的独立用户界面工具。|
|[Gopeed](https://gopeed.com "点击查看 Gopeed 的主页或仓库")|<a href="./bucket/Gopeed.json" title="点击查看 Gopeed 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGopeed.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Gopeed 使用 Scoop 官方的 persist 实现">`✔️`</code>||一款现代下载管理器，使用 Golang 和 Flutter 构建。|
|[HashCalculator](https://github.com/hrpzcf/HashCalculator "点击查看 HashCalculator 的主页或仓库")|<a href="./bucket/HashCalculator.json" title="点击查看 HashCalculator 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHashCalculator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="HashCalculator 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个文件哈希值计算工具，批量计算/批量校验/查找重复文件/改变哈希值等。|
|[HBuilderX](https://www.dcloud.io/hbuilderx.html "点击查看 HBuilderX 的主页或仓库")|<a href="./bucket/HBuilderX.json" title="点击查看 HBuilderX 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHBuilderX.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="HBuilderX 使用 Link 进行数据持久化">`Link`</code>||DCloud 旗下的代码编辑器。|
|[Helix](https://helix-editor.com "点击查看 Helix 的主页或仓库")|<a href="./bucket/Helix.json" title="点击查看 Helix 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHelix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Helix 使用 Link 进行数据持久化">`Link`</code>||后现代文本编辑器。|
|[Heynote](https://heynote.com/ "点击查看 Heynote 的主页或仓库")|<a href="./bucket/Heynote.json" title="点击查看 Heynote 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHeynote.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Heynote 使用 Link 进行数据持久化">`Link`</code>||为开发人员提供的专用便签本。|
|[ImageGlass](https://imageglass.org "点击查看 ImageGlass 的主页或仓库")|<a href="./bucket/ImageGlass.json" title="点击查看 ImageGlass 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FImageGlass.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="ImageGlass 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个轻量级的、多功能的图像查看器。|
|[InputTip-zip](https://inputtip.abgox.com "点击查看 InputTip-zip 的主页或仓库")|<a href="./bucket/InputTip-zip.json" title="点击查看 InputTip-zip 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip-zip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="InputTip-zip 使用 Scoop 官方的 persist 实现">`✔️`</code>||(zip 版本) 一个输入法状态实时提示工具。|
|[InputTip](https://inputtip.abgox.com/ "点击查看 InputTip 的主页或仓库")|<a href="./bucket/InputTip.json" title="点击查看 InputTip 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="InputTip 使用 Scoop 官方的 persist 实现">`✔️`</code>||(exe 版本) 一个输入法状态实时提示工具。|
|[Insomnia](https://insomnia.rest "点击查看 Insomnia 的主页或仓库")|<a href="./bucket/Insomnia.json" title="点击查看 Insomnia 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInsomnia.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Insomnia 使用 Link 进行数据持久化">`Link`</code>||一个开源的跨平台 API 客户端，适用于 GraphQL、REST、WebSockets、SSE 和 gRPC。具有 Cloud、Local 和 Git 存储。|
|[IPTVnator](https://github.com/4gray/iptvnator "点击查看 IPTVnator 的主页或仓库")|<a href="./bucket/IPTVnator.json" title="点击查看 IPTVnator 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FIPTVnator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="IPTVnator 使用 Link 进行数据持久化">`Link`</code>||一个支持 IPTV 播放列表播放 (m3u、m3u8) 的视频播放器应用程序。|
|[Keyviz](https://mularahul.github.io/keyviz "点击查看 Keyviz 的主页或仓库")|<a href="./bucket/Keyviz.json" title="点击查看 Keyviz 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FKeyviz.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Keyviz 使用 Link 进行数据持久化">`Link`</code>||一个免费的开源工具来可视化你的击键和鼠标实时动作。|
|[Koodo-Reader](https://koodo.960960.xyz "点击查看 Koodo-Reader 的主页或仓库")|<a href="./bucket/Koodo-Reader.json" title="点击查看 Koodo-Reader 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FKoodo-Reader.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Koodo-Reader 使用 Link 进行数据持久化">`Link`</code>||一个跨平台的电子书阅读器。|
|[Lapce](http://lapce.dev/ "点击查看 Lapce 的主页或仓库")|<a href="./bucket/Lapce.json" title="点击查看 Lapce 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLapce.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Lapce 使用 Scoop 官方的 persist 实现">`✔️`</code>||用 Rust 编写的快速且强大的代码编辑器。|
|[Listary](https://www.listary.com "点击查看 Listary 的主页或仓库")|<a href="./bucket/Listary.json" title="点击查看 Listary 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FListary.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Listary 使用 Link 进行数据持久化">`Link`</code>||一个革命性的 Windows 搜索工具。|
|[LocalSend](https://localsend.org/ "点击查看 LocalSend 的主页或仓库")|<a href="./bucket/LocalSend.json" title="点击查看 LocalSend 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLocalSend.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="LocalSend 使用 Scoop 官方的 persist 实现">`✔️`</code>||一款免费的开源应用程序，它允许你在无需互联网连接的情况下，通过本地网络安全地与附近设备共享文件和消息。|
|[LX-Music](https://github.com/lyswhut/lx-music-desktop "点击查看 LX-Music 的主页或仓库")|<a href="./bucket/LX-Music.json" title="点击查看 LX-Music 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLX-Music.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="LX-Music 使用 Link 进行数据持久化">`Link`</code>||一个基于 electron 的音乐软件。|
|[MarkText](https://www.marktext.cc "点击查看 MarkText 的主页或仓库")|<a href="./bucket/MarkText.json" title="点击查看 MarkText 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMarkText.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="MarkText 使用 Link 进行数据持久化">`Link`</code>||一个简单优雅的 MarkDown 编辑器。|
|[Motrix](https://motrix.app "点击查看 Motrix 的主页或仓库")|<a href="./bucket/Motrix.json" title="点击查看 Motrix 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMotrix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Motrix 使用 Link 进行数据持久化">`Link`</code>||一个全功能的下载器。|
|[MusicPlayer2](https://github.com/zhongyang219/MusicPlayer2 "点击查看 MusicPlayer2 的主页或仓库")|<a href="./bucket/MusicPlayer2.json" title="点击查看 MusicPlayer2 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMusicPlayer2.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="MusicPlayer2 使用 Link 进行数据持久化">`Link`</code>||一款集音乐播放、歌词显示、格式转换等众多功能于一身的音频播放软件。|
|[Neovide](https://neovide.dev "点击查看 Neovide 的主页或仓库")|<a href="./bucket/Neovide.json" title="点击查看 Neovide 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNeovide.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Neovide 使用 Link 进行数据持久化">`Link`</code>||一个 Neovim 的简单图形用户界面。|
|[Neovim](https://neovim.io/ "点击查看 Neovim 的主页或仓库")|<a href="./bucket/Neovim.json" title="点击查看 Neovim 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNeovim.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Neovim 使用 Link 进行数据持久化">`Link`</code>||一个旨在重构 Vim 的文本编辑器项目。|
|[Notepad--](https://github.com/cxasm/notepad-- "点击查看 Notepad-- 的主页或仓库")|<a href="./bucket/Notepad--.json" title="点击查看 Notepad-- 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepad--.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Notepad-- 使用 Link 进行数据持久化">`Link`</code>||一个文本编辑器。|
|[Notepad3](https://github.com/rizonesoft/Notepad3 "点击查看 Notepad3 的主页或仓库")|<a href="./bucket/Notepad3.json" title="点击查看 Notepad3 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepad3.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Notepad3 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个快速、轻量级的基于 Scintilla 的文本编辑器。|
|[Notepad4](https://github.com/zufuliu/notepad4 "点击查看 Notepad4 的主页或仓库")|<a href="./bucket/Notepad4.json" title="点击查看 Notepad4 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepad4.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Notepad4 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个轻量级的基于 Scintilla 的文本编辑器。|
|[NotepadNext](https://github.com/dail8859/NotepadNext "点击查看 NotepadNext 的主页或仓库")|<a href="./bucket/NotepadNext.json" title="点击查看 NotepadNext 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepadNext.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="NotepadNext 使用 Link 进行数据持久化">`Link`</code>||Notepad++ 的跨平台重新实现。|
|[Notepads](https://www.notepadsapp.com/ "点击查看 Notepads 的主页或仓库")|<a href="./bucket/Notepads.json" title="点击查看 Notepads 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepads.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Notepads 使用 Link 进行数据持久化">`Link`</code>|<code title="Notepads 通过 Msix 安装，安装目录不在 Scoop 中，Scoop 只管理数据、安装、卸载、更新">`Msix`</code>|一款设计简约的现代轻量级文本编辑器。|
|[Nushell](https://www.nushell.sh "点击查看 Nushell 的主页或仓库")|<a href="./bucket/Nushell.json" title="点击查看 Nushell 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNushell.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Nushell 使用 Link 进行数据持久化">`Link`</code>||一种用 Rust 编写的新型 shell。|
|[OBS-Studio](https://obsproject.com "点击查看 OBS-Studio 的主页或仓库")|<a href="./bucket/OBS-Studio.json" title="点击查看 OBS-Studio 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FOBS-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="OBS-Studio 使用 Link 进行数据持久化">`Link`</code>||用于视频录制和直播的免费开源软件。|
|[Obsidian](https://obsidian.md "点击查看 Obsidian 的主页或仓库")|<a href="./bucket/Obsidian.json" title="点击查看 Obsidian 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FObsidian.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Obsidian 使用 Link 进行数据持久化">`Link`</code>||强大的知识库，基于 Markdown 文件。|
|[PixPin](https://pixpin.cn/ "点击查看 PixPin 的主页或仓库")|<a href="./bucket/PixPin.json" title="点击查看 PixPin 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPixPin.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PixPin 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个功能强大使用简单的截图/贴图/录屏工具。|
|[pot](https://pot-app.com/ "点击查看 pot 的主页或仓库")|<a href="./bucket/pot.json" title="点击查看 pot 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fpot.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="pot 使用 Link 进行数据持久化">`Link`</code>||一个跨平台的划词翻译和 OCR 软件。|
|[PotPlayer](https://potplayer.daum.net "点击查看 PotPlayer 的主页或仓库")|<a href="./bucket/PotPlayer.json" title="点击查看 PotPlayer 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPotPlayer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PotPlayer 使用 Scoop 官方的 persist 实现">`✔️`</code>||高度可定制的媒体播放器。|
|[powershell-yaml](https://github.com/cloudbase/powershell-yaml "点击查看 powershell-yaml 的主页或仓库")|<a href="./bucket/powershell-yaml.json" title="点击查看 powershell-yaml 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fpowershell-yaml.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="powershell-yaml 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>|<code title="powershell-yaml 是一个 Powershell 模块">`PSModule`</code>|一个用于解析 YAML 的 PowerShell 模块。|
|[PowerToysRun-ClipboardManager](https://github.com/CoreyHayward/PowerToys-Run-ClipboardManager "点击查看 PowerToysRun-ClipboardManager 的主页或仓库")|<a href="./bucket/PowerToysRun-ClipboardManager.json" title="点击查看 PowerToysRun-ClipboardManager 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ClipboardManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-ClipboardManager 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于轻松搜索和粘贴剪贴板历史记录。|
|[PowerToysRun-Everything](https://github.com/lin-ycv/EverythingPowerToys "点击查看 PowerToysRun-Everything 的主页或仓库")|<a href="./bucket/PowerToysRun-Everything.json" title="点击查看 PowerToysRun-Everything 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Everything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-Everything 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||PowerToys Run 中的 Everything 插件。|
|[PowerToysRun-GitHubRepo](https://github.com/8LWXpg/PowerToysRun-GitHubRepo "点击查看 PowerToysRun-GitHubRepo 的主页或仓库")|<a href="./bucket/PowerToysRun-GitHubRepo.json" title="点击查看 PowerToysRun-GitHubRepo 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-GitHubRepo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-GitHubRepo 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于搜索 GitHub 存储库，然后在默认浏览器中打开。|
|[PowerToysRun-HttpStatusCodes](https://github.com/grzhan/HttpStatusCodePowerToys "点击查看 PowerToysRun-HttpStatusCodes 的主页或仓库")|<a href="./bucket/PowerToysRun-HttpStatusCodes.json" title="点击查看 PowerToysRun-HttpStatusCodes 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-HttpStatusCodes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-HttpStatusCodes 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于搜索 HTTP 状态代码。|
|[PowerToysRun-Pomodoro](https://github.com/ruslanlap/PowerToysRun-Pomodoro "点击查看 PowerToysRun-Pomodoro 的主页或仓库")|<a href="./bucket/PowerToysRun-Pomodoro.json" title="点击查看 PowerToysRun-Pomodoro 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Pomodoro.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-Pomodoro 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于管理你的生产力会话。|
|[PowerToysRun-ProcessKiller](https://github.com/8LWXpg/PowerToysRun-ProcessKiller "点击查看 PowerToysRun-ProcessKiller 的主页或仓库")|<a href="./bucket/PowerToysRun-ProcessKiller.json" title="点击查看 PowerToysRun-ProcessKiller 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ProcessKiller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-ProcessKiller 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于杀死进程。|
|[PowerToysRun-Scoop](https://github.com/Quriz/PowerToysRunScoop "点击查看 PowerToysRun-Scoop 的主页或仓库")|<a href="./bucket/PowerToysRun-Scoop.json" title="点击查看 PowerToysRun-Scoop 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Scoop.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-Scoop 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于从 Scoop 包管理器中搜索、安装、更新和卸载软件包。|
|[PowerToysRun-Translator](https://github.com/N0I0C0K/PowerTranslator "点击查看 PowerToysRun-Translator 的主页或仓库")|<a href="./bucket/PowerToysRun-Translator.json" title="点击查看 PowerToysRun-Translator 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Translator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-Translator 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 的翻译插件。|
|[PowerToysRun-Winget](https://github.com/bostrot/PowerToysRunPluginWinget "点击查看 PowerToysRun-Winget 的主页或仓库")|<a href="./bucket/PowerToysRun-Winget.json" title="点击查看 PowerToysRun-Winget 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Winget.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PowerToysRun-Winget 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerToys Run 插件，用于从 Winget 包管理器中搜索和安装包。|
|[PSCompletions](https://pscompletions.abgox.com/ "点击查看 PSCompletions 的主页或仓库")|<a href="./bucket/PSCompletions.json" title="点击查看 PSCompletions 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPSCompletions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="PSCompletions 使用 Scoop 官方的 persist 实现">`✔️`</code>|<code title="PSCompletions 是一个 Powershell 模块">`PSModule`</code>|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。|
|[QtScrcpy](https://github.com/barry-ran/QtScrcpy "点击查看 QtScrcpy 的主页或仓库")|<a href="./bucket/QtScrcpy.json" title="点击查看 QtScrcpy 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FQtScrcpy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="QtScrcpy 使用 Scoop 官方的 persist 实现">`✔️`</code>||通过 TCP/IP 或 USB 显示和控制 Android 设备。|
|[Readest](https://readest.com/ "点击查看 Readest 的主页或仓库")|<a href="./bucket/Readest.json" title="点击查看 Readest 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FReadest.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Readest 使用 Link 进行数据持久化">`Link`</code>||一款专为沉浸式深度阅读体验而设计的开源电子书阅读器。|
|[Rubick](https://github.com/rubickCenter/rubick "点击查看 Rubick 的主页或仓库")|<a href="./bucket/Rubick.json" title="点击查看 Rubick 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FRubick.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Rubick 使用 Link 进行数据持久化">`Link`</code>||基于 electron 的开源工具箱，自由集成丰富插件。|
|[RustDesk](https://github.com/rustdesk/rustdesk "点击查看 RustDesk 的主页或仓库")|<a href="./bucket/RustDesk.json" title="点击查看 RustDesk 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FRustDesk.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="RustDesk 使用 Link 进行数据持久化">`Link`</code>||一个安全的远程桌面访问工具，用 Rust 语言编写。|
|[scoop-install](https://gitee.com/abgox/scoop-install "点击查看 scoop-install 的主页或仓库")|<a href="./bucket/scoop-install.json" title="点击查看 scoop-install 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fscoop-install.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="scoop-install 未实现 persist，因为不存在数据或者没有实现的必要">`➖`</code>||一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url。|
|[ScreenToGif](https://www.screentogif.com/ "点击查看 ScreenToGif 的主页或仓库")|<a href="./bucket/ScreenToGif.json" title="点击查看 ScreenToGif 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FScreenToGif.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="ScreenToGif 使用 Link 进行数据持久化">`Link`</code>||屏幕、摄像头和画板录像，并有内置编辑器。|
|[Seanime](https://seanime.rahim.app/ "点击查看 Seanime 的主页或仓库")|<a href="./bucket/Seanime.json" title="点击查看 Seanime 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSeanime.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Seanime 使用 Link 进行数据持久化">`Link`</code>||免费开源的媒体服务器，为动漫爱好者提供丰富功能。|
|[SmartContextMenu](https://github.com/AlexanderPro/SmartContextMenu "点击查看 SmartContextMenu 的主页或仓库")|<a href="./bucket/SmartContextMenu.json" title="点击查看 SmartContextMenu 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSmartContextMenu.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="SmartContextMenu 使用 Link 进行数据持久化">`Link`</code>||系统中所有窗口的智能上下文菜单。|
|[Spacedrive](https://www.spacedrive.com "点击查看 Spacedrive 的主页或仓库")|<a href="./bucket/Spacedrive.json" title="点击查看 Spacedrive 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSpacedrive.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Spacedrive 使用 Link 进行数据持久化">`Link`</code>||一个开源的跨平台文件浏览器，由一个用 Rust 编写的虚拟分布式文件系统提供支持。|
|[SQLynx](https://www.sqlynx.com/ "点击查看 SQLynx 的主页或仓库")|<a href="./bucket/SQLynx.json" title="点击查看 SQLynx 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSQLynx.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="SQLynx 使用 Link 进行数据持久化">`Link`</code>||本地基于 Web 的 SQL IDE，支持企业桌面和网络管理。它是一款跨平台数据库工具，适用于所有数据处理人员。|
|[Starship](https://starship.rs/ "点击查看 Starship 的主页或仓库")|<a href="./bucket/Starship.json" title="点击查看 Starship 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FStarship.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Starship 使用 Link 进行数据持久化">`Link`</code>|<code title=" Starship 需要管理员权限才能安装">`AdminToInstall`</code>|适用于任何 shell 的极简、极快且可无限定制的提示符。|
|[Steampp](https://steampp.net/ "点击查看 Steampp 的主页或仓库")|<a href="./bucket/Steampp.json" title="点击查看 Steampp 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSteampp.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Steampp 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个开源跨平台的多功能 Steam 工具箱，包含 Github 网络加速等功能，它也被叫做: Watt Toolkit。|
|[STranslate](https://stranslate.zggsong.com "点击查看 STranslate 的主页或仓库")|<a href="./bucket/STranslate.json" title="点击查看 STranslate 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSTranslate.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="STranslate 使用 Scoop 官方的 persist 实现">`✔️`</code>||一款即用即走的翻译、OCR工具。|
|[SuperProductivity](https://super-productivity.com "点击查看 SuperProductivity 的主页或仓库")|<a href="./bucket/SuperProductivity.json" title="点击查看 SuperProductivity 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSuperProductivity.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="SuperProductivity 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个先进的待办事项列表应用程序，集成了时间盒和时间跟踪功能。它还集成了 Jira、Gitlab、GitHub 和 Open Project。|
|[SwitchHosts](https://switchhosts.vercel.app "点击查看 SwitchHosts 的主页或仓库")|<a href="./bucket/SwitchHosts.json" title="点击查看 SwitchHosts 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSwitchHosts.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="SwitchHosts 使用 Link 进行数据持久化">`Link`</code>||一个管理、切换多个 hosts 方案的工具，快速切换 hosts。|
|[Tabby](https://tabby.sh "点击查看 Tabby 的主页或仓库")|<a href="./bucket/Tabby.json" title="点击查看 Tabby 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTabby.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Tabby 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个现代终端。|
|[TinyRDM](https://redis.tinycraft.cc/ "点击查看 TinyRDM 的主页或仓库")|<a href="./bucket/TinyRDM.json" title="点击查看 TinyRDM 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTinyRDM.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="TinyRDM 使用 Link 进行数据持久化">`Link`</code>||一款现代轻量级跨平台 Redis 桌面管理器。|
|[TrafficMonitor](https://github.com/zhongyang219/TrafficMonitor "点击查看 TrafficMonitor 的主页或仓库")|<a href="./bucket/TrafficMonitor.json" title="点击查看 TrafficMonitor 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTrafficMonitor.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="TrafficMonitor 使用 Link 进行数据持久化">`Link`</code>||一个用于显示当前网速、CPU及内存利用率的桌面悬浮窗软件，并支持任务栏显示，支持更换皮肤。|
|[TranslucentTB](https://github.com/TranslucentTB/TranslucentTB "点击查看 TranslucentTB 的主页或仓库")|<a href="./bucket/TranslucentTB.json" title="点击查看 TranslucentTB 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTranslucentTB.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="TranslucentTB 使用 Link 进行数据持久化">`Link`</code>|<code title="TranslucentTB 通过 Msix 安装，安装目录不在 Scoop 中，Scoop 只管理数据、安装、卸载、更新">`Msix`</code>|一个轻量级的实用程序，使 Windows 任务栏半透明/透明。|
|[TTime](https://ttime.timerecord.cn/ "点击查看 TTime 的主页或仓库")|<a href="./bucket/TTime.json" title="点击查看 TTime 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTTime.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="TTime 使用 Link 进行数据持久化">`Link`</code>||一款简洁、高效、高颜值的输入、截图、划词翻译软件。|
|[Typora](https://typora.io "点击查看 Typora 的主页或仓库")|<a href="./bucket/Typora.json" title="点击查看 Typora 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTypora.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Typora 使用 Link 进行数据持久化">`Link`</code>||一个 Markdown 编辑器和阅读器，所见即所得。|
|[Upscayl](https://upscayl.org/ "点击查看 Upscayl 的主页或仓库")|<a href="./bucket/Upscayl.json" title="点击查看 Upscayl 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FUpscayl.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Upscayl 使用 Link 进行数据持久化">`Link`</code>||免费开源的 AI 图像质量增强器。|
|[v2rayN](https://github.com/2dust/v2rayN "点击查看 v2rayN 的主页或仓库")|<a href="./bucket/v2rayN.json" title="点击查看 v2rayN 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fv2rayN.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="v2rayN 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个适用于 Windows 的 V2Ray 客户端，支持 Xray & v2fly 核心。|
|[VLC](https://www.videolan.org/vlc "点击查看 VLC 的主页或仓库")|<a href="./bucket/VLC.json" title="点击查看 VLC 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVLC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="VLC 使用 Link 进行数据持久化">`Link`</code>||一款免费、开源的跨平台多媒体播放器及框架，可播放大多数多媒体文件，以及 DVD、音频 CD、VCD 及各类流媒体协议。|
|[Vov-Sticky-Notes](https://vovsoft.com/software/vov-sticky-notes/ "点击查看 Vov-Sticky-Notes 的主页或仓库")|<a href="./bucket/Vov-Sticky-Notes.json" title="点击查看 Vov-Sticky-Notes 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVov-Sticky-Notes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Vov-Sticky-Notes 使用 Scoop 官方的 persist 实现">`✔️`</code>||创建数字贴纸和提醒事项。|
|[VSCode](https://code.visualstudio.com/ "点击查看 VSCode 的主页或仓库")|<a href="./bucket/VSCode.json" title="点击查看 VSCode 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVSCode.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="VSCode 使用 Link 进行数据持久化">`Link`</code>||一个轻量级、功能强大，插件生态丰富的文件编辑器。|
|[WeekToDo](https://weektodo.me/ "点击查看 WeekToDo 的主页或仓库")|<a href="./bucket/WeekToDo.json" title="点击查看 WeekToDo 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FWeekToDo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="WeekToDo 使用 Link 进行数据持久化">`Link`</code>||一个免费和开源的极简每周计划和待办事项应用程序，专注于隐私。|
|[WonderPen](https://www.tominlab.com/wonderpen "点击查看 WonderPen 的主页或仓库")|<a href="./bucket/WonderPen.json" title="点击查看 WonderPen 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FWonderPen.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="WonderPen 使用 Link 进行数据持久化">`Link`</code>||一款专业的写作软件，致力于为作者提供专注且流畅的写作体验。|
|[XYplorer](https://www.xyplorer.com/index.php "点击查看 XYplorer 的主页或仓库")|<a href="./bucket/XYplorer.json" title="点击查看 XYplorer 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FXYplorer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="XYplorer 使用 Scoop 官方的 persist 实现">`✔️`</code>||一个 Windows 上的第三方文件管理器。|
|[XYplorerFree](https://www.xyplorer.com/free.php "点击查看 XYplorerFree 的主页或仓库")|<a href="./bucket/XYplorerFree.json" title="点击查看 XYplorerFree 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FXYplorerFree.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="XYplorerFree 使用 Scoop 官方的 persist 实现">`✔️`</code>|<code title="Scoop 不会检查它的版本更新，因为 XYplorerFree 没有配置 autoupdate">`NoUpdate`</code>|(Free 版本) 一个 Windows 上的第三方文件管理器。|
|[Z-Library](https://go-to-library.sk/ "点击查看 Z-Library 的主页或仓库")|<a href="./bucket/Z-Library.json" title="点击查看 Z-Library 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FZ-Library.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Z-Library 使用 Link 进行数据持久化">`Link`</code>||Z-Library —— 世界上最大的电子书图书馆。|
|[Zotero](https://www.zotero.org/ "点击查看 Zotero 的主页或仓库")|<a href="./bucket/Zotero.json" title="点击查看 Zotero 的 manifest json 文件"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FZotero.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|<code title="Zotero 使用 Link 进行数据持久化">`Link`</code>||一个免费，易于使用的工具，可帮助您收集，组织，注释，引用和共享研究。|
<!-- prettier-ignore-end -->
