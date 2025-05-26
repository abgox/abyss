<p align="center">
    <h1 align="center">✨ abgox-bucket ✨</h1>
</p>

<p align="center">
    <a href="readme.md">English</a> |
    <a href="readme-cn.md">简体中文</a> |
    <a href="https://github.com/abgox/abgox-bucket">Github</a> |
    <a href="https://gitee.com/abgox/abgox-bucket">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/abgox-bucket/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/abgox-bucket" alt="license" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/abgox-bucket.svg">
        <img src="https://img.shields.io/github/languages/code-size/abgox/abgox-bucket.svg" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/abgox-bucket.svg">
        <img src="https://img.shields.io/github/repo-size/abgox/abgox-bucket.svg" alt="code size" />
    </a>
    <a href="https://github.com/abgox/abgox-bucket">
        <img src="https://img.shields.io/github/created-at/abgox/abgox-bucket" alt="created" />
    </a>
</p>

- [Scoop completion in PSCompletions ](https://github.com/abgox/PSCompletions "PSCompletions")is recommended.

### For ones familiar with Scoop

1.  Add `abgox-bucket`. (Use Github or Gitee repository.)

    ```shell
    scoop bucket add abgox-bucket https://github.com/abgox/abgox-bucket
    ```

    ```shell
    scoop bucket add abgox-bucket https://gitee.com/abgox/abgox-bucket
    ```

2.  Install apps. (e.g. `InputTip-zip`)

    ```shell
    scoop install abgox-bucket/InputTip-zip
    ```

---

### Never used Scoop

- [What is Scoop?](https://github.com/ScoopInstaller/Scoop)
- [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Scoop install](https://github.com/ScoopInstaller/Install)
- [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)

---

### App Manifests

- Guide

  - **`App`** : App package name.
    - Click to view the official website or repository.
    - Sort by first letter(0-9,a-z).
  - **`Version`** : App version.
    - Click to view the manifest json file.
  - **`Persist`** : Important data of software is saved to `persist` directory.
    - **✔️** : It has been done.
    - **➖** : It's not necessary, or the conditions are not meet.(e.g. data file not found)
  - **`Tag`**
    - `Font` : A font.
    - `PSModule` : A [PowerShell Module](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules).
    - `NoAutoUpdate` : `json.autoupdate` are not configured, and Scoop cannot automatically detect updates.
  - **`Description`** : App Description.

---

<!-- prettier-ignore-start -->
|App (21)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|<a href="./bucket/Font-Hack-NF.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Hack-NF.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|Hack 字体，Nerd Font 系列。<br />Nerd Fonts patched 'Hack' Font family.|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|<a href="./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Maple-Mono-Normal-NL-NF-CN-Unhinted.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|一款带连字和控制台图标的圆角等宽字体，中英文宽度完美2:1 (版本: Normal-NL-NF-CN-Unhinted)。<br /> An open source monospace font with round corner and ligatures for IDE and command line. (version: Normal-NL-NF-CN-Unhinted)|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|<a href="./bucket/Font-Sarasa-Fixed-SC.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Sarasa-Fixed-SC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|一款中英文宽度完美2:1的等宽字体 (版本: Fixed-SC)。<br />A perfectly 2:1 monospaced font. (version: Fixed-SC)|
|[HashCalculator](https://github.com/hrpzcf/HashCalculator)|<a href="./bucket/HashCalculator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FHashCalculator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个文件哈希值计算工具，批量计算/批量校验/查找重复文件/改变哈希值等。<br />A file hash calculator, which can calculate/verify/find duplicate files/change hash values in batch.|
|[InputTip-zip](https://inputtip.abgox.com)|<a href="./bucket/InputTip-zip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip-zip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个输入法状态实时提示工具(zip 版本)。<br />An input method status tip tool (zip version).|
|[InputTip](https://inputtip.abgox.com/)|<a href="./bucket/InputTip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个输入法状态实时提示工具。<br />An input method status tip tool.|
|[LX-Music](https://github.com/lyswhut/lx-music-desktop)|<a href="./bucket/LX-Music.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FLX-Music.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个基于 electron 的音乐软件。<br />An electron-based music player.|
|[PixPin](https://pixpin.cn/)|<a href="./bucket/PixPin.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPixPin.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个功能强大使用简单的截图/贴图/录屏工具|
|[PowerToysRun-ClipboardManager](https://github.com/CoreyHayward/PowerToys-Run-ClipboardManager)|<a href="./bucket/PowerToysRun-ClipboardManager.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ClipboardManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于轻松搜索和粘贴剪贴板历史记录。<br />A PowerToys Run plugin for easily searching and pasting the clipboard history.|
|[PowerToysRun-Everything](https://github.com/lin-ycv/EverythingPowerToys)|<a href="./bucket/PowerToysRun-Everything.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Everything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||PowerToys Run 中的 Everything 插件。<br />Everything search plugin for PowerToys Run.|
|[PowerToysRun-GitHubRepo](https://github.com/8LWXpg/PowerToysRun-GitHubRepo)|<a href="./bucket/PowerToysRun-GitHubRepo.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-GitHubRepo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于搜索 GitHub 存储库，然后在默认浏览器中打开。<br />A PowerToys Run plugin PowerToys Run Plugin for searching and opening GitHub repositories.|
|[PowerToysRun-HttpStatusCodes](https://github.com/grzhan/HttpStatusCodePowerToys)|<a href="./bucket/PowerToysRun-HttpStatusCodes.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-HttpStatusCodes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于搜索 HTTP 状态代码。<br />A PowerToys Run plugin for for searching HTTP status codes.|
|[PowerToysRun-Pomodoro](https://github.com/ruslanlap/PowerToysRun-Pomodoro)|<a href="./bucket/PowerToysRun-Pomodoro.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Pomodoro.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于管理你的生产力会话。<br />A PowerToys Run plugin that manage your productivity sessions.|
|[PowerToysRun-ProcessKiller](https://github.com/8LWXpg/PowerToysRun-ProcessKiller)|<a href="./bucket/PowerToysRun-ProcessKiller.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ProcessKiller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于杀死进程。<br />A PowerToys Run plugin for killing processes.|
|[PowerToysRun-Scoop](https://github.com/Quriz/PowerToysRunScoop)|<a href="./bucket/PowerToysRun-Scoop.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Scoop.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于从 Scoop 包管理器中搜索、安装、更新和卸载软件包。<br />A PowerToys Run plugin that allows you to search, install, update and uninstall packages from the Scoop package manager.|
|[PowerToysRun-Translator](https://github.com/N0I0C0K/PowerTranslator)|<a href="./bucket/PowerToysRun-Translator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Translator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 的翻译插件。<br />A translate plugin for PowerToys Run.|
|[PowerToysRun-Winget](https://github.com/bostrot/PowerToysRunPluginWinget)|<a href="./bucket/PowerToysRun-Winget.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Winget.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||一个 PowerToys Run 插件，用于从 Winget 包管理器中搜索和安装包。<br />A PowerToys Run plugin that allows you to search and install packages from the Winget package manager.|
|[PSCompletions](https://pscompletions.abgox.com/)|<a href="./bucket/PSCompletions.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FPSCompletions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️|`PSModule`|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。<br />A completion manager for better and simpler use completions in PowerShell.|
|[Steampp](https://steampp.net/)|<a href="./bucket/Steampp.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FSteampp.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个开源跨平台的多功能 Steam 工具箱，包含 Github 网络加速等功能，它也被叫做: "Watt Toolkit"。<br />A toolbox with lots of Steam tools. It's also known as "Watt Toolkit".|
|[STranslate](https://stranslate.zggsong.com)|<a href="./bucket/STranslate.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FSTranslate.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一款即用即走的翻译、OCR工具。<br />A ready-to-go translation ocr tool.|
|[Tabby](https://tabby.sh)|<a href="./bucket/Tabby.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2FTabby.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||一个现代终端。<br />A terminal for a more modern age.|
<!-- prettier-ignore-end -->
