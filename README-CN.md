<p align="center">
    <h1 align="center">✨ abgox-bucket ✨</h1>
</p>

<p align="center">
    <a href="README.md">English</a> |
    <a href="README-CN.md">简体中文</a> |
    <a href="https://github.com/abgox/abgox-bucket">Github</a> |
    <a href="https://gitee.com/abgox/abgox-bucket">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/abgox-bucket/blob/main/LICENSE">
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

-   推荐使用 [PSCompletions 项目中的 scoop 补全 ](https://gitee.com/abgox/PSCompletions "PSCompletions")

### 正在使用 Scoop

1. 添加 `abgox-bucket` (使用 Github 或 Gitee 仓库)

    ```shell
    scoop bucket add abgox-bucket https://github.com/abgox/abgox-bucket
    ```

    ```shell
    scoop bucket add abgox-bucket https://gitee.com/abgox/abgox-bucket
    ```

2. 安装应用(以 `InputTip` 举例)

    ```shell
    scoop install abgox-bucket/InputTip
    ```

### 没有使用过 Scoop

-   [什么是 Scoop?](https://github.com/ScoopInstaller/Scoop)
-   [什么是 Scoop 中的 bucket?](https://github.com/ScoopInstaller/Scoop)
-   [什么是 Scoop 中的应用清单(App-Manifests)?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
-   [安装 Scoop](https://github.com/ScoopInstaller/Install)
-   [Scoop 文档](https://github.com/ScoopInstaller/Scoop/wiki)

---

### 应用清单

-   说明

    -   **`App`** ：应用包名
        -   点击跳转官网或仓库
        -   按照数字字母排序(0-9,a-z)
    -   **`Persist`** ：应用重要数据保存到 `persist` 目录中
        -   **`✔️`** ：已实现
        -   **`➖`** ：没必要或不满足条件(比如：找不到数据文件)
    -   **`Tag`**

        -   `Font`: 一种字体
        -   `PSModule`: 一个 PowerShell 模块
        -   `NoAutoUpdate` : `json.autoupdate` 未配置，Scoop 无法自动检测更新

    -   **`Description`**: 应用描述

---

<!-- prettier-ignore-start -->
|App|Persist|Tag|Description|
|:-:|:-:|:-:|-|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|➖|`Font`|Hack 字体，Nerd Font 系列。<br>Nerd Fonts patched 'Hack' Font family.|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|➖|`Font`|一款带连字和控制台图标的圆角等宽字体，中英文宽度完美2:1 (版本: Normal-NL-NF-CN-Unhinted)。<br> An open source monospace font with round corner and ligatures for IDE and command line. (version: Normal-NL-NF-CN-Unhinted)|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|➖|`Font`|一款中英文宽度完美2:1的等宽字体 (版本: Fixed-SC)。<br>A perfectly 2:1 monospaced font. (version: Fixed-SC)|
|[InputTip-zip](https://inputtip.abgox.com)|✔️||一个输入法状态实时提示工具(zip 版本)。<br>An input method status tip tool (zip version).|
|[InputTip](https://inputtip.abgox.com/)|✔️||一个输入法状态实时提示工具。<br>An input method status tip tool.|
|[PixPin](https://pixpin.cn/)|✔️||一个功能强大使用简单的截图/贴图/录屏工具|
|[PSCompletions](https://pscompletions.abgox.com/)|✔️|`PSModule`|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。<br>A completion manager for better and simpler use completions in PowerShell.|
|[Steampp](https://steampp.net/)|✔️||一个开源跨平台的多功能 Steam 工具箱，包含 Github 网络加速等功能，它也被叫做: "Watt Toolkit"。<br>A toolbox with lots of Steam tools. It's also known as "Watt Toolkit".|
<!-- prettier-ignore-end -->
