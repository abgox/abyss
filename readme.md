<h1 align="center">✨<a href="https://abyss.abgox.com">abyss</a>✨</h1>

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
        <img src="https://img.shields.io/github/created-at/abgox/abyss" alt="created" />
    </a>
</p>

<p align="center">
    <a href="https://www.microsoft.com/windows">
        <img src="https://img.shields.io/badge/platform-Windows%2010+-blue" alt="platform" />
    </a>
    <a href="https://abyss.abgox.com/manifests">
        <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fabyss.abgox.com%2Fmanifests.json&query=%24.count&label=manifests" alt="manifests" />
    </a>
    <a href="https://github.com/abgox/abyss/commits">
        <img src="https://img.shields.io/github/commit-activity/m/abgox/abyss" alt="commit activity" />
    </a>
</p>

---

<p align="center">
  <strong>Just like abyss — limitless, mysterious, and filled with treasures.</strong>
</p>
<p align="center">
  <strong>Just like abyss — always building your stable source.</strong>
</p>
<p align="center">
  <strong>Star ⭐️ or <a href="https://abgox.com/donate">Donate 💰</a> if you like it!</strong>
</p>

> [!IMPORTANT]
>
> - [abyss](https://abyss.abgox.com) is an engineered and opinionated [Scoop bucket](https://scoop.sh/#/apps?q=%22https%3A%2F%2Fgithub.com%2Fabgox%2Fabyss%22).
> - Its [manifests](https://abyss.abgox.com/manifests) are written with [util](./util/) and [a unique bucket name](https://abyss.abgox.com/docs/bucket-name), making them unusable for other buckets.

## Features

> [!TIP]
>
> Unlike standard buckets, [abyss](https://abyss.abgox.com) includes extra features.

- [Better Data Persistence](https://abyss.abgox.com/docs/features/data-persistence)
- [Explicit Manifest Status Control](https://abyss.abgox.com/docs/features/manifest-status-control)
- [Flexible App Installation Solution](https://abyss.abgox.com/docs/features/install-solution)
- [Extra Features via Scoop Configuration](https://abyss.abgox.com/docs/features/extra-features)
- Multilingual support powered by [scoop-i18n](https://scoop-i18n.abgox.com).
- Standardized directory structure and manifest name.
  - Inspired by: [winget-pkgs](https://github.com/microsoft/winget-pkgs)
  - Name Format: **Publisher.PackageIdentifier**

## Manifests

**View, search, and filter manifests**: https://abyss.abgox.com/manifests

## Demo

![Demo](https://abyss.abgox.com/demo.gif)

## If you have never used Scoop

> [!TIP]
>
> - It is recommended to use the [scoop-installer-mirrors](https://gitee.com/scoop-installer-mirrors) if you cannot access Github.
> - It allows you to install and use Scoop normally without accessing Github.

- [Scoop](https://scoop.sh)
- [Scoop - Github Wiki](https://github.com/ScoopInstaller/Scoop/wiki)

## If you are currently using Scoop

1. Add the [abyss](https://abyss.abgox.com) bucket from [Github](https://github.com/abgox/abyss) or [Gitee](https://gitee.com/abgox/abyss).

   ```shell
   scoop bucket add abyss https://github.com/abgox/abyss
   ```

   ```shell
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. Add `scoop` completion via [PSCompletions](https://pscompletions.abgox.com) in [PowerShell](https://www.microsoft.com/powershell).

   ```shell
   scoop install abyss/abgox.PSCompletions
   ```

   ```powershell
   Import-Module PSCompletions
   ```

   ```shell
   psc add scoop
   ```

3. Install [scoop-i18n](https://scoop-i18n.abgox.com) to provide multilingual support.

   ```shell
   scoop install abyss/abgox.scoop-i18n
   ```

## If you cannot access Github resources

[scoop-tools](https://scoop-tools.abgox.com) allows you to temporarily use the replaced proxy URL to download app packages.

- Github: https://github.com/abgox/scoop-tools
- Gitee: https://gitee.com/abgox/scoop-tools

## License

[MIT](./license) © [abgox](https://www.abgox.com)
