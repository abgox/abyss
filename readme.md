<h1 align="center">✨<a href="https://abyss.abgox.com/">abyss</a>✨</h1>

<p align="center">
    <a href="readme.zh-CN.md">简体中文</a> |
    <a href="readme.md">English</a> |
    <a href="https://github.com/abgox/abyss">Github</a> |
    <a href="https://gitee.com/abgox/abyss">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/abyss">
        <img src="https://img.shields.io/github/stars/abgox/abyss" alt="github stars" />
    </a>
    <a href="https://github.com/abgox/abyss/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/abyss" alt="license" />
    </a>
    <a href="https://github.com/abgox/abyss">
        <img src="https://img.shields.io/github/languages/code-size/abgox/abyss" alt="code size" />
    </a>
    <a href="https://github.com/abgox/abyss">
        <img src="https://img.shields.io/github/repo-size/abgox/abyss" alt="repo size" />
    </a>
    <a href="https://github.com/abgox/abyss">
        <img src="https://img.shields.io/github/created-at/abgox/abyss" alt="created" />
    </a>
</p>

---

<p align="center">
  <strong>Just like the abyss — limitless, mysterious, and filled with treasures.</strong>
</p>
<p align="center">
  <strong>Star ⭐️ or <a href="https://abgox.com/donate">Donate 💰</a> if you like it!</strong>
</p>

> [!Tip]
>
> - [abyss](https://abyss.abgox.com) is a very special Scoop bucket repository.
> - It aims to be a Scoop solution similar to Winget with [data persistence](https://abyss.abgox.com/features/data-persistence).
> - Manifests are based on [bin/utils.ps1](./bin/utils.ps1).
> - They contain some [features](#features), and other buckets should not merge them to avoid conflicts and errors.

### Features

- [Enhanced Data Persistence](https://abyss.abgox.com/features/data-persistence)
- [Flexible App Installation Solution](https://abyss.abgox.com/features/install-solution)
- [Manifest State Control](https://abyss.abgox.com/features/manifest-state-control)
- [Extra Features](https://abyss.abgox.com/features/extra-features)
- Multilingual support powered by [abgox/scoop-i18n](https://scoop-i18n.abgox.com).
- Inspired by [winget-pkgs](https://github.com/microsoft/winget-pkgs).
  - Manifest naming format: `Publisher.PackageIdentifier`
  - Directory structure: `bucket/a/abgox/abgox.scoop-i18n.json`

### Demo

![Demo](https://abyss.abgox.com/demo.gif)

---

### If you are not using Scoop

> [!Tip]
>
> - If you cannot access Github, it is recommended to use the [Scoop mirror](https://gitee.com/scoop-installer-mirrors).
> - It allows you to install and use Scoop normally without accessing Github.

- [Scoop](https://scoop.sh/)
- [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)
- [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)

### If you are using Scoop

> [!Warning]
>
> Please use `abyss` as the bucket name to avoid "bucket not found" errors when parsing "depends" in some manifests.

1.  Add the [abyss](https://abyss.abgox.com) bucket via [Github](https://github.com/abgox/abyss) or [Gitee](https://gitee.com/abgox/abyss).

    ```shell
    scoop bucket add abyss https://github.com/abgox/abyss
    ```

    ```shell
    scoop bucket add abyss https://gitee.com/abgox/abyss
    ```

2.  Use [PSCompletions](https://github.com/abgox/PSCompletions) to add `scoop` completion.

    ```shell
    scoop install abyss/abgox.PSCompletions
    ```

    ```shell
    Import-Module PSCompletions
    ```

    ```shell
    psc add scoop
    ```

3.  Install [scoop-i18n](https://scoop-i18n.abgox.com) to enable i18n support.

    ```shell
    scoop install abyss/abgox.scoop-i18n
    ```

### If you cannot access Github resources

- You can use [scoop-tools](https://scoop-tools.abgox.com), and it allows you to temporarily use the replaced proxy url to download the installation package.
  - Github: https://github.com/abgox/scoop-tools
  - Gitee: https://gitee.com/abgox/scoop-tools

### App List

> [!Tip]
>
> Check on the official website: https://abyss.abgox.com/app-list

- [English](./app-list.md)
- [简体中文](./app-list.zh-CN.md)
