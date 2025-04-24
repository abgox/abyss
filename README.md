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

-   [Scoop completion in PSCompletions ](https://github.com/abgox/PSCompletions "PSCompletions")is recommended.

### For ones familiar with Scoop

1.  Add `abgox-bucket`.

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
    -   **`Persist`** : Important data of software is saved to `persist` directory.
        -   **✔️** : It has been done.
        -   **➖** : It's not necessary, or the conditions are not meet.(e.g. data file not found)
    -   **`Tag`**
        -   `Font`: A font.
        -   `PSModule`: A PowerShell Module.
        -   `NoAutoUpdate` : `json.autoupdate` are not configured, and Scoop cannot automatically detect updates.
    -   **`Description`**: App Description.

---

<!-- prettier-ignore-start -->
|App|Persist|Tag|Description|
|:-:|:-:|:-:|-|
|[PSCompletions](https://github.com/abgox/PSCompletions)|✔️|`PSModule`|一个 PowerShell 命令补全管理模块，更简单、更方便的在 PowerShell 中使用命令补全。<br>A completion manager for better and simpler use completions in PowerShell.|
<!-- prettier-ignore-end -->
