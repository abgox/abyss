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
> - 此仓库中的应用清单高度依赖 [bin/utils.ps1](./bin/utils.ps1)
>
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

- 本仓库中的应用会有一些特性，由配置项 `app-uninstall-action-level` 控制
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

  - 以 [VSCode.json](./bucket/VSCode.json) 为例, Scoop 会将其安装到 `D:\Scoop\apps\VSCode` 目录中
  - 然后会持久化数据目录: `D:\Scoop\apps\VSCode\data` => `D:\Scoop\persist\VSCode\data`
  - 卸载后，它的设置、插件、快捷键等数据仍然会保存在 `D:\Scoop\persist\VSCode\data` 目录中
    - 如果卸载时使用 `-p/--purge` 参数，`D:\Scoop\persist\VSCode` 目录会被删除
  - 重新安装后，又会继续使用这些数据

- 这是 Scoop 最强大的特性，可以快速的恢复自己的应用环境
  - 一些应用使用了 [Link](#link)，无法通过 `scoop reset` 正确重置
  - 建议通过 `scoop uninstall` 卸载应用，然后再重新安装

### Link

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 的 persist 功能很强大，遗憾的是它有局限性: 只有应用数据在应用安装目录中，才可以使用它
- 但是有些应用的数据是存储在安装目录之外的，常见的是在 `$env:AppData` 目录中
- 像这样的应用，本仓库中使用 `New-Item -ItemType Junction` 进行链接
- 以 [Helix](./bucket/Helix.json) 为例
  - [Helix](./bucket/Helix.json) 的数据目录是 `$env:AppData\helix`
  - 它会进行链接: `$env:AppData\helix` => `D:\Scoop\persist\Helix\helix`

---

### 应用清单

[English](readme.md#app-manifests) | [简体中文](./readme-cn.md#应用清单)

- 说明

  - **`App`**：应用包名
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

  - **`Description`**：应用描述

---

<!-- prettier-ignore-start -->
|App (93)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[AppFlowy](https://www.appflowy.io/)|<a href="./bucket/AppFlowy.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FAppFlowy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个开源的 Notion 替代品，数据和定制由你掌控。|
|[Beekeeper-Studio](https://www.beekeeperstudio.io)|<a href="./bucket/Beekeeper-Studio.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBeekeeper-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款跨平台的 SQL 编辑器和数据库管理器。|
|[BongoCat](https://github.com/ayangweb/BongoCat)|<a href="./bucket/BongoCat.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBongoCat.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个跨平台桌宠。|
|[Bruno](https://www.usebruno.com/)|<a href="./bucket/Bruno.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBruno.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||用于探索和测试 API 的开源集成开发环境 (Postman/Insomnia 的轻量级替代品)。|
|[Carnac](http://carnackeys.com/)|<a href="./bucket/Carnac.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCarnac.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个键盘按键记录和演示实用程序。|
|[Cherry-Studio](https://cherry-ai.com)|<a href="./bucket/Cherry-Studio.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCherry-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款支持多个大语言模型 (LLM) 供应商的桌面客户端。|
|[clash-verge-rev](https://github.com/clash-verge-rev/clash-verge-rev)|<a href="./bucket/clash-verge-rev.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fclash-verge-rev.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款基于 Tauri 的现代图形用户界面客户端，提供定制化的代理体验。|
|[ContextMenuManager](https://github.com/BluePointLilac/ContextMenuManager)|<a href="./bucket/ContextMenuManager.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FContextMenuManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个纯粹的 Windows 右键菜单管理程序。|
|[Coriander-Player](https://github.com/Ferry-200/coriander_player)|<a href="./bucket/Coriander-Player.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCoriander-Player.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个 Windows 上的本地音乐播放器。|
|[DownKyi](https://github.com/leiurayer/downkyi)|<a href="./bucket/DownKyi.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FDownKyi.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个B站(bilibili)视频下载工具。|
|[draw.io](https://www.diagrams.net)|<a href="./bucket/draw.io.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fdraw.io.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款基于 Electron 的桌面绘图应用程序，它封装了 draw.io 核心编辑器。|
|[Escrcpy](https://github.com/viarotel-org/escrcpy)|<a href="./bucket/Escrcpy.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEscrcpy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||使用图形化的 Scrcpy 显示和控制您的 Android 设备，由 Electron 驱动。|
|[eSearch](https://esearch-app.netlify.app/)|<a href="./bucket/eSearch.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FeSearch.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||截屏 离线OCR 搜索翻译 以图搜图 贴图 录屏 万向滚动截屏 屏幕翻译。|
|[Everything-Lite](https://www.voidtools.com)|<a href="./bucket/Everything-Lite.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEverything-Lite.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||(Lite 版本，不包含 IPC 和 ETP/FTP/HTTP 服务器) 文件搜索工具，基于名称快速定位文件和文件夹。|
|[Everything](https://www.voidtools.com)|<a href="./bucket/Everything.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEverything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||文件搜索工具，基于名称快速定位文件和文件夹。|
|[ExplorerTabUtility](https://github.com/w4po/ExplorerTabUtility)|<a href="./bucket/ExplorerTabUtility.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FExplorerTabUtility.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||提升 Windows 11 文件资源管理器的功能：自动将窗口转换为标签页、复制标签页、重新打开已关闭的标签页等等。|
|[Flow-Launcher](https://www.flowlauncher.com)|<a href="./bucket/Flow-Launcher.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFlow-Launcher.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||适用于 Windows 的快速文件搜索和应用程序启动器。|
|[Fluent-Search](https://github.com/adirh3/Fluent-Search)|<a href="./bucket/Fluent-Search.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFluent-Search.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||使用它，你可以搜索正在运行的应用程序、浏览器标签、应用程序内内容、文件等。|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|<a href="./bucket/Font-Hack-NF.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Hack-NF.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|Hack 字体，Nerd Font 系列。|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|<a href="./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Maple-Mono-Normal-NL-NF-CN-Unhinted.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|(版本: Normal-NL-NF-CN-Unhinted，无连字) 一款带连字和控制台图标的圆角等宽字体，中英文宽度完美 2:1。|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|<a href="./bucket/Font-Sarasa-Fixed-SC.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Sarasa-Fixed-SC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|(版本: Fixed-SC，无连字) 一款中英文宽度完美 2:1 的等宽字体。|
|[FSViewer](https://www.faststone.org/FSViewerDetail.htm)|<a href="./bucket/FSViewer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFSViewer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Faststone Image Viewer 是一个快速，稳定，用户友好的图像浏览器，转换器和编辑器。|
|[GeekUninstaller](https://geekuninstaller.com/)|<a href="./bucket/GeekUninstaller.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGeekUninstaller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||简单便捷的免费卸载程序。|
|[GitExtensions](https://gitextensions.github.io/)|<a href="./bucket/GitExtensions.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGitExtensions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个用于管理 Git 仓库的独立用户界面工具。|
|[Gopeed](https://gopeed.com)|<a href="./bucket/Gopeed.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGopeed.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一款现代下载管理器，使用 Golang 和 Flutter 构建。|
|[HashCalculator](https://github.com/hrpzcf/HashCalculator)|<a href="./bucket/HashCalculator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHashCalculator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个文件哈希值计算工具，批量计算/批量校验/查找重复文件/改变哈希值等。|
|[HBuilderX](https://www.dcloud.io/hbuilderx.html)|<a href="./bucket/HBuilderX.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHBuilderX.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||DCloud 旗下的代码编辑器。|
|[Helix](https://helix-editor.com)|<a href="./bucket/Helix.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHelix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||后现代文本编辑器。|
|[Heynote](https://heynote.com/)|<a href="./bucket/Heynote.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHeynote.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||为开发人员提供的专用便签本。|
|[ImageGlass](https://imageglass.org)|<a href="./bucket/ImageGlass.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FImageGlass.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个轻量级的、多功能的图像查看器。|
|[InputTip-zip](https://inputtip.abgox.com)|<a href="./bucket/InputTip-zip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip-zip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||(zip 版本) 一个输入法状态实时提示工具。|
|[InputTip](https://inputtip.abgox.com/)|<a href="./bucket/InputTip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||(exe 版本) 一个输入法状态实时提示工具。|
|[Insomnia](https://insomnia.rest)|<a href="./bucket/Insomnia.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInsomnia.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个开源的跨平台 API 客户端，适用于 GraphQL、REST、WebSockets、SSE 和 gRPC。具有 Cloud、Local 和 Git 存储。|
|[Keyviz](https://mularahul.github.io/keyviz)|<a href="./bucket/Keyviz.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FKeyviz.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个免费的开源工具来可视化你的击键和鼠标实时动作。|
|[Koodo-Reader](https://koodo.960960.xyz)|<a href="./bucket/Koodo-Reader.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FKoodo-Reader.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个跨平台的电子书阅读器。|
|[Listary](https://www.listary.com)|<a href="./bucket/Listary.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FListary.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个革命性的 Windows 搜索工具。|
|[LocalSend](https://localsend.org/)|<a href="./bucket/LocalSend.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLocalSend.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一款免费的开源应用程序，它允许你在无需互联网连接的情况下，通过本地网络安全地与附近设备共享文件和消息。|
|[LX-Music](https://github.com/lyswhut/lx-music-desktop)|<a href="./bucket/LX-Music.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLX-Music.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个基于 electron 的音乐软件。|
|[MarkText](https://www.marktext.cc)|<a href="./bucket/MarkText.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMarkText.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个简单优雅的 MarkDown 编辑器。|
|[Motrix](https://motrix.app)|<a href="./bucket/Motrix.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMotrix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个全功能的下载器。|
|[MusicPlayer2](https://github.com/zhongyang219/MusicPlayer2)|<a href="./bucket/MusicPlayer2.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMusicPlayer2.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款集音乐播放、歌词显示、格式转换等众多功能于一身的音频播放软件。|
|[Neovide](https://neovide.dev)|<a href="./bucket/Neovide.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNeovide.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个 Neovim 的简单图形用户界面。|
|[Neovim](https://neovim.io/)|<a href="./bucket/Neovim.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNeovim.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个旨在重构 Vim 的文本编辑器项目。|
|[Notepad--](https://github.com/cxasm/notepad--)|<a href="./bucket/Notepad--.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepad--.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个文本编辑器。|
|[Notepad3](https://github.com/rizonesoft/Notepad3)|<a href="./bucket/Notepad3.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepad3.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个快速、轻量级的基于 Scintilla 的文本编辑器。|
|[Notepad4](https://github.com/zufuliu/notepad4)|<a href="./bucket/Notepad4.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepad4.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个轻量级的基于 Scintilla 的文本编辑器。|
|[NotepadNext](https://github.com/dail8859/NotepadNext)|<a href="./bucket/NotepadNext.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepadNext.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Notepad++ 的跨平台重新实现。|
|[Notepads](https://www.notepadsapp.com/)|<a href="./bucket/Notepads.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepads.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款设计简约的现代轻量级文本编辑器。|
|[Nushell](https://www.nushell.sh)|<a href="./bucket/Nushell.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNushell.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一种用 Rust 编写的新型 shell。|
|[OBS-Studio](https://obsproject.com)|<a href="./bucket/OBS-Studio.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FOBS-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||用于视频录制和直播的免费开源软件。|
|[Obsidian](https://obsidian.md)|<a href="./bucket/Obsidian.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FObsidian.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||强大的知识库，基于 Markdown 文件。|
|[PixPin](https://pixpin.cn/)|<a href="./bucket/PixPin.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPixPin.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个功能强大使用简单的截图/贴图/录屏工具。|
|[pot](https://pot-app.com/)|<a href="./bucket/pot.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fpot.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个跨平台的划词翻译和 OCR 软件。|
|[PotPlayer](https://potplayer.daum.net)|<a href="./bucket/PotPlayer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPotPlayer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||高度可定制的媒体播放器。|
|[PowerToysRun-ClipboardManager](https://github.com/CoreyHayward/PowerToys-Run-ClipboardManager)|<a href="./bucket/PowerToysRun-ClipboardManager.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ClipboardManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于轻松搜索和粘贴剪贴板历史记录。|
|[PowerToysRun-Everything](https://github.com/lin-ycv/EverythingPowerToys)|<a href="./bucket/PowerToysRun-Everything.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Everything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||PowerToys Run 中的 Everything 插件。|
|[PowerToysRun-GitHubRepo](https://github.com/8LWXpg/PowerToysRun-GitHubRepo)|<a href="./bucket/PowerToysRun-GitHubRepo.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-GitHubRepo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于搜索 GitHub 存储库，然后在默认浏览器中打开。|
|[PowerToysRun-HttpStatusCodes](https://github.com/grzhan/HttpStatusCodePowerToys)|<a href="./bucket/PowerToysRun-HttpStatusCodes.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-HttpStatusCodes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于搜索 HTTP 状态代码。|
|[PowerToysRun-Pomodoro](https://github.com/ruslanlap/PowerToysRun-Pomodoro)|<a href="./bucket/PowerToysRun-Pomodoro.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Pomodoro.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于管理你的生产力会话。|
|[PowerToysRun-ProcessKiller](https://github.com/8LWXpg/PowerToysRun-ProcessKiller)|<a href="./bucket/PowerToysRun-ProcessKiller.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ProcessKiller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于杀死进程。|
|[PowerToysRun-Scoop](https://github.com/Quriz/PowerToysRunScoop)|<a href="./bucket/PowerToysRun-Scoop.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Scoop.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于从 Scoop 包管理器中搜索、安装、更新和卸载软件包。|
|[PowerToysRun-Translator](https://github.com/N0I0C0K/PowerTranslator)|<a href="./bucket/PowerToysRun-Translator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Translator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 的翻译插件。|
|[PowerToysRun-Winget](https://github.com/bostrot/PowerToysRunPluginWinget)|<a href="./bucket/PowerToysRun-Winget.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Winget.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于从 Winget 包管理器中搜索和安装包。|
|[PSCompletions](https://pscompletions.abgox.com/)|<a href="./bucket/PSCompletions.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPSCompletions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️|`PSModule`|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。|
|[QtScrcpy](https://github.com/barry-ran/QtScrcpy)|<a href="./bucket/QtScrcpy.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FQtScrcpy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||通过 TCP/IP 或 USB 显示和控制 Android 设备。|
|[Readest](https://readest.com/)|<a href="./bucket/Readest.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FReadest.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款专为沉浸式深度阅读体验而设计的开源电子书阅读器。|
|[Rubick](https://github.com/rubickCenter/rubick)|<a href="./bucket/Rubick.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FRubick.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||基于 electron 的开源工具箱，自由集成丰富插件。|
|[RustDesk](https://github.com/rustdesk/rustdesk)|<a href="./bucket/RustDesk.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FRustDesk.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个安全的远程桌面访问工具，用 Rust 语言编写。|
|[scoop-install](https://gitee.com/abgox/scoop-install)|<a href="./bucket/scoop-install.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fscoop-install.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url。|
|[ScreenToGif](https://www.screentogif.com/)|<a href="./bucket/ScreenToGif.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FScreenToGif.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||屏幕、摄像头和画板录像，并有内置编辑器。|
|[SmartContextMenu](https://github.com/AlexanderPro/SmartContextMenu)|<a href="./bucket/SmartContextMenu.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSmartContextMenu.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||系统中所有窗口的智能上下文菜单。|
|[Spacedrive](https://www.spacedrive.com)|<a href="./bucket/Spacedrive.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSpacedrive.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个开源的跨平台文件浏览器，由一个用 Rust 编写的虚拟分布式文件系统提供支持。|
|[SQLynx](https://www.sqlynx.com/)|<a href="./bucket/SQLynx.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSQLynx.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||本地基于 Web 的 SQL IDE，支持企业桌面和网络管理。它是一款跨平台数据库工具，适用于所有数据处理人员。|
|[Steampp](https://steampp.net/)|<a href="./bucket/Steampp.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSteampp.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个开源跨平台的多功能 Steam 工具箱，包含 Github 网络加速等功能，它也被叫做: Watt Toolkit。|
|[STranslate](https://stranslate.zggsong.com)|<a href="./bucket/STranslate.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSTranslate.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一款即用即走的翻译、OCR工具。|
|[SuperProductivity](https://super-productivity.com)|<a href="./bucket/SuperProductivity.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSuperProductivity.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个先进的待办事项列表应用程序，集成了时间盒和时间跟踪功能。它还集成了 Jira、Gitlab、GitHub 和 Open Project。|
|[SwitchHosts](https://switchhosts.vercel.app)|<a href="./bucket/SwitchHosts.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSwitchHosts.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个管理、切换多个 hosts 方案的工具，快速切换 hosts。|
|[Tabby](https://tabby.sh)|<a href="./bucket/Tabby.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTabby.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个现代终端。|
|[TinyRDM](https://redis.tinycraft.cc/)|<a href="./bucket/TinyRDM.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTinyRDM.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款现代轻量级跨平台 Redis 桌面管理器。|
|[TrafficMonitor](https://github.com/zhongyang219/TrafficMonitor)|<a href="./bucket/TrafficMonitor.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTrafficMonitor.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个用于显示当前网速、CPU及内存利用率的桌面悬浮窗软件，并支持任务栏显示，支持更换皮肤。|
|[TranslucentTB](https://github.com/TranslucentTB/TranslucentTB)|<a href="./bucket/TranslucentTB.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTranslucentTB.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个轻量级的实用程序，使 Windows 任务栏半透明/透明。|
|[TTime](https://ttime.timerecord.cn/)|<a href="./bucket/TTime.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTTime.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款简洁、高效、高颜值的输入、截图、划词翻译软件。|
|[Typora](https://typora.io)|<a href="./bucket/Typora.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTypora.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个 Markdown 编辑器和阅读器，所见即所得。|
|[Upscayl](https://upscayl.org/)|<a href="./bucket/Upscayl.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FUpscayl.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||免费开源的 AI 图像质量增强器。|
|[VLC](https://www.videolan.org/vlc)|<a href="./bucket/VLC.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVLC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款免费、开源的跨平台多媒体播放器及框架，可播放大多数多媒体文件，以及 DVD、音频 CD、VCD 及各类流媒体协议。|
|[VovStickyNotes](https://vovsoft.com/software/vov-sticky-notes/)|<a href="./bucket/VovStickyNotes.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVovStickyNotes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||创建数字贴纸和提醒事项。|
|[VSCode](https://code.visualstudio.com/)|<a href="./bucket/VSCode.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVSCode.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个轻量级、功能强大，插件生态丰富的文件编辑器。|
|[WeekToDo](https://weektodo.me/)|<a href="./bucket/WeekToDo.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FWeekToDo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个免费和开源的极简每周计划和待办事项应用程序，专注于隐私。|
|[WonderPen](https://www.tominlab.com/wonderpen)|<a href="./bucket/WonderPen.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FWonderPen.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一款专业的写作软件，致力于为作者提供专注且流畅的写作体验。|
|[XYplorer](https://www.xyplorer.com/index.php)|<a href="./bucket/XYplorer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FXYplorer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个 Windows 上的第三方文件管理器。|
|[XYplorerFree](https://www.xyplorer.com/free.php)|<a href="./bucket/XYplorerFree.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FXYplorerFree.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️|`NoUpdate`|(Free 版本) 一个 Windows 上的第三方文件管理器。|
|[Z-Library](https://go-to-library.sk/)|<a href="./bucket/Z-Library.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FZ-Library.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Z-Library —— 世界上最大的电子书图书馆。|
|[Zotero](https://www.zotero.org/)|<a href="./bucket/Zotero.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FZotero.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||一个免费，易于使用的工具，可帮助您收集，组织，注释，引用和共享研究。|
<!-- prettier-ignore-end -->
