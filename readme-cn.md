<p align="center">
    <h1 align="center">✨ aether ✨</h1>
</p>

<p align="center">
    <a href="readme.md">English</a> |
    <a href="readme-cn.md">简体中文</a> |
    <a href="https://github.com/abgox/aether">Github</a> |
    <a href="https://gitee.com/abgox/aether">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/aether/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/aether" alt="license" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/aether.svg">
        <img src="https://img.shields.io/github/languages/code-size/abgox/aether.svg" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/aether.svg">
        <img src="https://img.shields.io/github/repo-size/abgox/aether.svg" alt="code size" />
    </a>
    <a href="https://github.com/abgox/aether">
        <img src="https://img.shields.io/github/created-at/abgox/aether" alt="created" />
    </a>
</p>

- 推荐使用 [PSCompletions 项目中的 scoop 补全 ](https://gitee.com/abgox/PSCompletions "PSCompletions")

### 正在使用 Scoop

1. 添加 `aether` (使用 Github 或 Gitee 仓库)

   ```pwsh
   scoop bucket add aether https://github.com/abgox/aether
   ```

   ```pwsh
   scoop bucket add aether https://gitee.com/abgox/aether
   ```

2. 安装应用(以 `InputTip-zip` 举例)

   ```pwsh
   scoop install aether/InputTip-zip
   ```

### 没有使用过 Scoop

- [什么是 Scoop?](https://scoop.sh/)
- [什么是 Scoop 中的 bucket?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [什么是 Scoop 中的应用清单(App-Manifests)?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [安装 Scoop](https://github.com/ScoopInstaller/Install)
- [Scoop 文档](https://github.com/ScoopInstaller/Scoop/wiki)

---

### 无法访问 Github 资源

> [!Tip]
>
> 如果因为网络问题无法访问 Github 资源，可以尝试以下方案

1. 使用 Gitee 仓库
   ```pwsh
   scoop bucket add aether https://gitee.com/abgox/aether
   ```
2. 安装 [scoop-install](https://gitee.com/abgox/scoop-install)
   ```pwsh
   scoop install aether/scoop-install
   ```
3. 设置 url 替换配置
   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```
4. 使用 [scoop-install](https://gitee.com/abgox/scoop-install) 安装应用，以 `InputTip-zip` 为例

   ```pwsh
   scoop-install aether/InputTip-zip
   ```

5. 更多详情请查看 [scoop-install](https://gitee.com/abgox/scoop-install)

---

### Persist

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 在清单文件中提供了 `persist` 配置，可以持久化保存应用目录下的数据文件

  - 以 [VSCode.json](./bucket/VSCode.json) 为例, Scoop 会将其安装到 `D:\Scoop\apps\VSCode` 目录下
  - 然后会持久化数据目录: `D:\Scoop\apps\VSCode\data` => `D:\Scoop\persist\VSCode\data`
  - 卸载后，它的设置、插件、快捷键等数据仍然会保存在 `D:\Scoop\persist\VSCode\data` 目录下
    - 如果卸载时使用 `-p/--purge` 参数，`D:\Scoop\persist\VSCode` 目录会被删除
  - 重新安装后，又会继续使用这些数据

- 这是 Scoop 最强大的特性，可以快速的恢复自己的应用环境
  - 假如你换了新的电脑，只要将 `D:\Scoop` 目录备份到新电脑中，然后运行以下命令即可恢复所有应用
    ```pwsh
    scoop reset *
    ```

## Link

> [!Tip]
>
> 假设 Scoop 的根目录是 `D:\Scoop`

- Scoop 的 persist 非常强大，遗憾的是它有局限性: 只有应用数据在应用安装目录下，才可以使用它
- 但是有些应用的数据是存储在安装目录之外的，常见的是在 `$env:AppData` 目录下
- 像这样的应用，本仓库中使用 `New-Item -ItemType Junction` 进行链接
- 以 [Helix](./bucket/Helix.json) 为例
  - [Helix](./bucket/Helix.json) 的数据目录是 `$env:AppData\helix`
  - 它会进行链接: `$env:AppData\helix` => `D:\Scoop\persist\Helix\helix`

> [!Warning]
>
> 需要注意: 卸载应用时不会删除链接目录

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
    - **`Link`** : 使用 `New-Item -ItemType Junction` 实现, 详情参考 [Link](#link)
    - **`➖`**：没必要或不满足条件(如：无数据文件)
  - **`Tag`**：应用标签

    - `Font`：一种字体
    - `PSModule`：一个 [PowerShell 模块](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules)
    - `NoAutoUpdate`：没有配置 `json.autoupdate`，Scoop 无法自动检测更新

  - **`Description`**：应用描述

---

<!-- prettier-ignore-start -->
|App (29)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[DownKyi](https://github.com/leiurayer/downkyi)|<a href="./bucket/DownKyi.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FDownKyi.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个B站(bilibili)视频下载工具。|
|[eSearch](https://esearch-app.netlify.app/)|<a href="./bucket/eSearch.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FeSearch.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||截屏 离线OCR 搜索翻译 以图搜图 贴图 录屏 万向滚动截屏 屏幕翻译。|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|<a href="./bucket/Font-Hack-NF.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Hack-NF.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|Hack 字体，Nerd Font 系列。|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|<a href="./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Maple-Mono-Normal-NL-NF-CN-Unhinted.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|一款带连字和控制台图标的圆角等宽字体，中英文宽度完美2:1 (版本: Normal-NL-NF-CN-Unhinted)。|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|<a href="./bucket/Font-Sarasa-Fixed-SC.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Sarasa-Fixed-SC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|一款中英文宽度完美2:1的等宽字体 (版本: Fixed-SC)。|
|[FSViewer](https://www.faststone.org/FSViewerDetail.htm)|<a href="./bucket/FSViewer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FFSViewer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Faststone Image Viewer 是一个快速，稳定，用户友好的图像浏览器，转换器和编辑器。|
|[HashCalculator](https://github.com/hrpzcf/HashCalculator)|<a href="./bucket/HashCalculator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FHashCalculator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个文件哈希值计算工具，批量计算/批量校验/查找重复文件/改变哈希值等。|
|[InputTip-zip](https://inputtip.abgox.com)|<a href="./bucket/InputTip-zip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip-zip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个输入法状态实时提示工具(zip 版本)。|
|[InputTip](https://inputtip.abgox.com/)|<a href="./bucket/InputTip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个输入法状态实时提示工具(exe 版本)。|
|[LocalSend](https://localsend.org/)|<a href="./bucket/LocalSend.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FLocalSend.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一款免费的开源应用程序，它允许你在无需互联网连接的情况下，通过本地网络安全地与附近设备共享文件和消息。|
|[LX-Music](https://github.com/lyswhut/lx-music-desktop)|<a href="./bucket/LX-Music.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FLX-Music.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个基于 electron 的音乐软件。|
|[PixPin](https://pixpin.cn/)|<a href="./bucket/PixPin.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPixPin.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个功能强大使用简单的截图/贴图/录屏工具。|
|[PotPlayer](https://potplayer.daum.net)|<a href="./bucket/PotPlayer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPotPlayer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||高度可定制的媒体播放器。|
|[PowerToysRun-ClipboardManager](https://github.com/CoreyHayward/PowerToys-Run-ClipboardManager)|<a href="./bucket/PowerToysRun-ClipboardManager.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ClipboardManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于轻松搜索和粘贴剪贴板历史记录。|
|[PowerToysRun-Everything](https://github.com/lin-ycv/EverythingPowerToys)|<a href="./bucket/PowerToysRun-Everything.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Everything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||PowerToys Run 中的 Everything 插件。|
|[PowerToysRun-GitHubRepo](https://github.com/8LWXpg/PowerToysRun-GitHubRepo)|<a href="./bucket/PowerToysRun-GitHubRepo.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-GitHubRepo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于搜索 GitHub 存储库，然后在默认浏览器中打开。|
|[PowerToysRun-HttpStatusCodes](https://github.com/grzhan/HttpStatusCodePowerToys)|<a href="./bucket/PowerToysRun-HttpStatusCodes.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-HttpStatusCodes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于搜索 HTTP 状态代码。|
|[PowerToysRun-Pomodoro](https://github.com/ruslanlap/PowerToysRun-Pomodoro)|<a href="./bucket/PowerToysRun-Pomodoro.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Pomodoro.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于管理你的生产力会话。|
|[PowerToysRun-ProcessKiller](https://github.com/8LWXpg/PowerToysRun-ProcessKiller)|<a href="./bucket/PowerToysRun-ProcessKiller.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ProcessKiller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于杀死进程。|
|[PowerToysRun-Scoop](https://github.com/Quriz/PowerToysRunScoop)|<a href="./bucket/PowerToysRun-Scoop.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Scoop.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于从 Scoop 包管理器中搜索、安装、更新和卸载软件包。|
|[PowerToysRun-Translator](https://github.com/N0I0C0K/PowerTranslator)|<a href="./bucket/PowerToysRun-Translator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Translator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 的翻译插件。|
|[PowerToysRun-Winget](https://github.com/bostrot/PowerToysRunPluginWinget)|<a href="./bucket/PowerToysRun-Winget.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Winget.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于从 Winget 包管理器中搜索和安装包。|
|[PSCompletions](https://pscompletions.abgox.com/)|<a href="./bucket/PSCompletions.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FPSCompletions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️|`PSModule`|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。|
|[scoop-install](https://gitee.com/abgox/scoop-install)|<a href="./bucket/scoop-install.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2Fscoop-install.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url。|
|[ScreenToGif](https://www.screentogif.com/)|<a href="./bucket/ScreenToGif.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FScreenToGif.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||屏幕、摄像头和画板录像，并有内置编辑器。|
|[Steampp](https://steampp.net/)|<a href="./bucket/Steampp.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FSteampp.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个开源跨平台的多功能 Steam 工具箱，包含 Github 网络加速等功能，它也被叫做: Watt Toolkit。|
|[STranslate](https://stranslate.zggsong.com)|<a href="./bucket/STranslate.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FSTranslate.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一款即用即走的翻译、OCR工具。|
|[Tabby](https://tabby.sh)|<a href="./bucket/Tabby.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FTabby.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个现代终端。|
|[VSCode](https://code.visualstudio.com/)|<a href="./bucket/VSCode.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Faether%2Frefs%2Fheads%2Fmain%2Fbucket%2FVSCode.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个轻量级、功能强大，插件生态丰富的文件编辑器。|
<!-- prettier-ignore-end -->
