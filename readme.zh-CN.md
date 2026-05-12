<h1 align="center">✨<a href="https://abyss.abgox.com/">abyss</a>✨</h1>

<p align="center">
    <a href="readme.md">English</a> |
    <a href="readme.zh-CN.md">简体中文</a> |
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
    <a href="https://www.microsoft.com/windows">
        <img src="https://img.shields.io/badge/Target-Windows%2010-blue" alt="target" />
    </a>
    <a href="https://abyss.abgox.com/docs/manifest-list">
        <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fabyss.abgox.com%2Fmanifest-list.json&query=%24.count&label=Manifests" alt="manifests" />
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
  <strong>喜欢这个项目？请给它 Star ⭐️ 或 <a href="https://abgox.com/donate">赞赏 💰</a></strong>
</p>

> [!Important]
>
> - [abyss](https://abyss.abgox.com) 是一个精心设计、自成体系的 [Scoop](https://scoop.sh/) bucket
> - 它旨在成为类似 Winget 的 Scoop 方案 + [数据持久化](https://abyss.abgox.com/docs/features/data-persistence)
> - 它的清单是基于 [util](./util/) 编写的，其他 bucket 不应该合并它们，以避免冲突和错误

## 特性

> [!Tip]
>
> 区别于标准的 Scoop bucket，[abyss](https://abyss.abgox.com) 包含了一些额外的特性

- [清单状态控制](https://abyss.abgox.com/docs/features/manifest-status-control)
- [完善的数据持久化](https://abyss.abgox.com/docs/features/data-persistence)
- [灵活的应用安装方案](https://abyss.abgox.com/docs/features/install-solution)
- [Scoop 配置控制的其他功能](https://abyss.abgox.com/docs/features/extra-features)
- 由 [scoop-i18n](https://scoop-i18n.abgox.com) 提供多语言支持
- 标准化的目录结构和应用清单命名
  - 参考了 [winget-pkgs](https://github.com/microsoft/winget-pkgs)
  - 格式: **Publisher.PackageIdentifier**

## 演示

> [!Tip]
>
> 如果这里无法显示，[可以在官网上查看](https://abyss.abgox.com)

![Demo](https://abyss.abgox.com/demo.zh-CN.gif)

## 如果没有用过 Scoop

> [!Tip]
>
> - 如果你无法访问 Github ，建议使用 [scoop-installer-mirrors](https://gitee.com/scoop-installer-mirrors)
> - 它可以让你正常安装并使用 Scoop，无需访问 Github

- [Scoop](https://scoop.sh/)
- [Scoop - Github Wiki](https://github.com/ScoopInstaller/Scoop/wiki)

## 如果正在使用 Scoop

1. 添加 [abyss](https://abyss.abgox.com) bucket ([Github](https://github.com/abgox/abyss) 或 [Gitee](https://gitee.com/abgox/abyss))

   ```shell
   scoop bucket add abyss https://github.com/abgox/abyss
   ```

   ```shell
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 在 [PowerShell](https://www.microsoft.com/powershell) 中，使用 [PSCompletions](https://pscompletions.abgox.com) 添加 `scoop` 命令补全

   ```shell
   scoop install abyss/abgox.PSCompletions
   ```

   ```shell
   Import-Module PSCompletions
   ```

   ```shell
   psc add scoop
   ```

3. 安装 [scoop-i18n](https://scoop-i18n.abgox.com) 以提供多语言支持

   ```shell
   scoop install abyss/abgox.scoop-i18n
   ```

## 如果无法访问 Github 资源

[scoop-tools](https://scoop-tools.abgox.com) 允许你临时使用替换之后的代理 url 来下载安装包

- Github: https://github.com/abgox/scoop-tools
- Gitee: https://gitee.com/abgox/scoop-tools

## [清单列表](https://abyss.abgox.com/docs/manifest-list)
