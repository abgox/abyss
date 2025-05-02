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

-   [Scoop completion in PSCompletions ](https://github.com/abgox/PSCompletions "PSCompletions")is recommended.

### For ones familiar with Scoop

1.  Add `abgox-bucket`. (Use Github or Gitee repository.)

    ```shell
    scoop bucket add abgox-bucket https://github.com/abgox/abgox-bucket
    ```

    ```shell
    scoop bucket add abgox-bucket https://gitee.com/abgox/abgox-bucket
    ```

2.  Install apps. (e.g. `InputTip`)

    ```shell
    scoop install abgox-bucket/InputTip
    ```

---

### Never used Scoop

-   [What is Scoop?](https://github.com/ScoopInstaller/Scoop)
-   [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
-   [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
-   [Scoop install](https://github.com/ScoopInstaller/Install)
-   [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)

---

### App Manifests

-   Guide

    -   **`App`** : App package name.
        -   Click to view the official website or repository.
        -   Sort by first letter(0-9,a-z).
    -   **`Version`** : App version.
        -   Click to view the manifest json file.
    -   **`Persist`** : Important data of software is saved to `persist` directory.
        -   **✔️** : It has been done.
        -   **➖** : It's not necessary, or the conditions are not meet.(e.g. data file not found)
    -   **`Tag`**
        -   `Font` : A font.
        -   `PSModule` : A [PowerShell Module](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules).
        -   `NoAutoUpdate` : `json.autoupdate` are not configured, and Scoop cannot automatically detect updates.
    -   **`Description`** : App Description.

---

<!-- prettier-ignore-start -->
|App (8)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|[v3.4.0](./bucket/Font-Hack-NF.json)|➖|`Font`|Hack 字体，Nerd Font 系列。<br />Nerd Fonts patched 'Hack' Font family.|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|[v7.2](./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json)|➖|`Font`|一款带连字和控制台图标的圆角等宽字体，中英文宽度完美2:1 (版本: Normal-NL-NF-CN-Unhinted)。<br /> An open source monospace font with round corner and ligatures for IDE and command line. (version: Normal-NL-NF-CN-Unhinted)|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|[v1.0.30](./bucket/Font-Sarasa-Fixed-SC.json)|➖|`Font`|一款中英文宽度完美2:1的等宽字体 (版本: Fixed-SC)。<br />A perfectly 2:1 monospaced font. (version: Fixed-SC)|
|[InputTip-zip](https://inputtip.abgox.com)|[v2.37.5](./bucket/InputTip-zip.json)|✔️||一个输入法状态实时提示工具(zip 版本)。<br />An input method status tip tool (zip version).|
|[InputTip](https://inputtip.abgox.com/)|[v2.37.5](./bucket/InputTip.json)|✔️||一个输入法状态实时提示工具。<br />An input method status tip tool.|
|[PixPin](https://pixpin.cn/)|[v2.0.0.3](./bucket/PixPin.json)|✔️||一个功能强大使用简单的截图/贴图/录屏工具|
|[PSCompletions](https://pscompletions.abgox.com/)|[v5.5.0](./bucket/PSCompletions.json)|✔️|`PSModule`|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。<br />A completion manager for better and simpler use completions in PowerShell.|
|[Steampp](https://steampp.net/)|[v3.0.0-rc.16](./bucket/Steampp.json)|✔️||一个开源跨平台的多功能 Steam 工具箱，包含 Github 网络加速等功能，它也被叫做: "Watt Toolkit"。<br />A toolbox with lots of Steam tools. It's also known as "Watt Toolkit".|
<!-- prettier-ignore-end -->
