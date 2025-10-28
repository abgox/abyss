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

---

<p align="center">
  <strong>Just like the abyss — limitless, mysterious, and filled with treasures.</strong>
</p>
<p align="center">
  <strong>喜欢这个项目？请给它 Star ⭐️ 或 <a href="https://abgox.com/donate">赞赏 💰</a></strong>
</p>

> [!Tip]
>
> - [abyss](https://abyss.abgox.com) 是一个非常特别的 Scoop bucket 仓库
> - 它旨在成为类似 Winget 的 Scoop 方案 + [数据持久化](https://abyss.abgox.com/features/data-persistence)
> - 其中的应用清单是基于 [bin/utils.ps1](./bin/utils.ps1) 编写的
> - 它们包含一些 [特性](#特性)，其他 bucket 不应该合并它们，以避免冲突和错误

### 特性

- [完善的数据持久化](https://abyss.abgox.com/features/data-persistence)
- [灵活的应用安装方案](https://abyss.abgox.com/features/install-solution)
- [清单状态控制](https://abyss.abgox.com/features/manifest-state-control)
- [更多的扩展功能](https://abyss.abgox.com/features/extra-features)
- [abgox/scoop-i18n](https://scoop-i18n.abgox.com) 提供 i18n 支持
- 参考了 [winget-pkgs](https://github.com/microsoft/winget-pkgs)
  - 清单命名格式: `Publisher.PackageIdentifier`
  - 目录结构: `bucket/a/abgox/abgox.scoop-i18n.json`

### 演示

![Demo](https://abyss.abgox.com/demo.zh-CN.gif)

---

### 如果你没有使用 Scoop

> [!Tip]
>
> - 如果你无法访问 Github ，建议使用 [Scoop 镜像](https://gitee.com/scoop-installer-mirrors)
> - 它可以让你正常安装并使用 Scoop，无需访问 Github

- [Scoop](https://scoop.sh/)
- [Scoop 文档](https://github.com/ScoopInstaller/Scoop/wiki)
- [什么是 Scoop 中的 bucket?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [什么是 Scoop 中的应用清单(App Manifests)?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)

### 如果你正在使用 Scoop

> [!Warning]
>
> 请确保使用 `abyss` 作为 bucket 的名称，避免部分清单在解析 depends 时找不到 `abyss` bucket

1. 添加 [abyss](https://abyss.abgox.com) ([Github](https://github.com/abgox/abyss) 或 [Gitee](https://gitee.com/abgox/abyss))

   ```shell
   scoop bucket add abyss https://github.com/abgox/abyss
   ```

   ```shell
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```

2. 使用 [PSCompletions](https://gitee.com/abgox/PSCompletions) 添加 `scoop` 命令补全

   ```shell
   scoop install abyss/abgox.PSCompletions
   ```

   ```shell
   Import-Module PSCompletions
   ```

   ```shell
   psc add scoop
   ```

3. 安装 [scoop-i18n](https://scoop-i18n.abgox.com) 以提供 i18n 支持

   ```shell
   scoop install abyss/abgox.scoop-i18n
   ```

### 如果你无法访问 Github 资源

- 可以使用 [scoop-tools](https://scoop-tools.abgox.com)，它允许你临时使用替换之后的代理 url 来下载安装包，以解决下载问题
  - Github: https://github.com/abgox/scoop-tools
  - Gitee: https://gitee.com/abgox/scoop-tools

### 应用列表

> [!Tip]
>
> 在 [官网](https://abyss.abgox.com) 中查看: https://abyss.abgox.com/app-list

- [简体中文](./app-list.zh-CN.md)
- [English](./app-list.md)
