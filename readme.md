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

<p align="center">
    <a href="https://github.com/abgox/abyss/actions/workflows/excavator.yml">
        <img src="https://github.com/abgox/abyss/actions/workflows/excavator.yml/badge.svg" alt="excavator" />
    </a>
    <a href="./manifest-list.md">
        <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgithub.com%2Fabgox%2Fabyss%2Fraw%2Fmain%2Fmanifest-list.json&query=%24.count&label=Manifests" alt="manifests" />
    </a>
    <a href="https://github.com/abgox/abyss/commits">
        <img src="https://img.shields.io/github/commit-activity/m/abgox/abyss" alt="commit activity" />
    </a>
</p>

---

<p align="center">
  <strong>Just like the abyss — limitless, mysterious, and filled with treasures.</strong>
</p>
<p align="center">
  <strong>Star ⭐️ or <a href="https://abgox.com/donate">Donate 💰</a> if you like it!</strong>
</p>

> [!Important]
>
> - [abyss](https://abyss.abgox.com) is an engineered and opinionated Scoop bucket.
> - It aims to provide a Winget-like solution with [data persistence](https://abyss.abgox.com/features/data-persistence).
> - Its manifests are based on [utils.ps1](./script/utils.ps1), and other buckets should not merge them to avoid conflicts and errors.

## Features

> [!Tip]
>
> Unlike the standard Scoop bucket, [abyss](https://abyss.abgox.com) includes some extra features.

- [Manifest Status Control](https://abyss.abgox.com/features/manifest-status-control)
- [Enhanced Data Persistence](https://abyss.abgox.com/features/data-persistence)
- [Flexible App Installation Solution](https://abyss.abgox.com/features/install-solution)
- [Extra Features via Scoop Configuration](https://abyss.abgox.com/features/extra-features)
- Multilingual support powered by [scoop-i18n](https://scoop-i18n.abgox.com).
- Standardized directory structure and manifest naming.
  - Inspired by: [winget-pkgs](https://github.com/microsoft/winget-pkgs)
  - Format: **Publisher.PackageIdentifier**

## Demo

> [!Tip]
>
> If it cannot be displayed here, [you can check it on the official website](https://abyss.abgox.com).

![Demo](https://abyss.abgox.com/demo.gif)

## If you have never used Scoop

> [!Tip]
>
> - If you cannot access Github, it is recommended to use the [scoop-installer-mirrors](https://gitee.com/scoop-installer-mirrors).
> - It allows you to install and use Scoop normally without accessing Github.

- [Scoop](https://scoop.sh/)
- [Scoop - Github Wiki](https://github.com/ScoopInstaller/Scoop/wiki)
- [Scoop bucket - Github Wiki](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [Scoop App-Manifest - Github Wiki](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)

## If you are currently using Scoop

1.  Add the [abyss](https://abyss.abgox.com) bucket ([Github](https://github.com/abgox/abyss) or [Gitee](https://gitee.com/abgox/abyss)).

    ```shell
    scoop bucket add abyss https://github.com/abgox/abyss
    ```

    ```shell
    scoop bucket add abyss https://gitee.com/abgox/abyss
    ```

2.  Add `scoop` completion via [PSCompletions](https://pscompletions.abgox.com).

    ```shell
    scoop install abyss/abgox.PSCompletions
    ```

    ```shell
    Import-Module PSCompletions
    ```

    ```shell
    psc add scoop
    ```

3.  Install [scoop-i18n](https://scoop-i18n.abgox.com) to provide multilingual support.

    ```shell
    scoop install abyss/abgox.scoop-i18n
    ```

## If you cannot access Github resources

[scoop-tools](https://scoop-tools.abgox.com) is a good solution that allows you to temporarily use the replaced proxy URL to download app packages.

- Github: https://github.com/abgox/scoop-tools
- Gitee: https://gitee.com/abgox/scoop-tools

## Manifest List

> [!Tip]
>
> Check on the official website: https://abyss.abgox.com/manifest-list

- [English](./manifest-list.md)
- [简体中文](./manifest-list.zh-CN.md)
