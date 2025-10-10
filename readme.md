<h1 align="center">✨<a href="https://abyss.abgox.com/">abyss</a>✨</h1>

<p align="center">
    <a href="readme.zh-CN.md">简体中文</a> |
    <a href="readme.md">English</a> |
    <a href="https://github.com/abgox/abyss">Github</a> |
    <a href="https://gitee.com/abgox/abyss">Gitee</a>
</p>

<p align="center">
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

> [!Warning]
>
> - Manifests in `abyss` are based on [bin/utils.ps1](./bin/utils.ps1).
> - They contain some [features](#features) outside of the official Scoop specification, and other buckets should not merge them to avoid conflicts and errors.

### Features

- Some apps that cannot use [Persist](#persist), [Link](#link) will be used as a fallback.
- Some spps use installers instead of zip to install.
- Use extra abilities via some [config](#config).
- Use [abgox/scoop-i18n](https://scoop-i18n.abgox.com) to enable i18n support.
- Inspired by [winget-pkgs](https://github.com/microsoft/winget-pkgs).
  - Manifest naming format: `Publisher.PackageIdentifier`
  - Directory structure: `bucket/a/abgox/abgox.scoop-i18n.json`

### Demo

![Demo](https://abyss.abgox.com/demo.gif)

---

### If you are not using Scoop

- [Scoop](https://scoop.sh/)
- [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)
- [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)

### If you are using Scoop

> [!Warning]
>
> Please use `abyss` as the bucket name to avoid "bucket not found" errors when parsing "depends" in some manifests.

1.  Add [abyss](https://abyss.abgox.com) with [Github](https://github.com/abgox/abyss) or [Gitee](https://gitee.com/abgox/abyss) repository.

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

### If you have problems accessing Github

- You can use [scoop-tools](https://scoop-tools.abgox.com), and it allows you to temporarily use the replaced proxy url to download the installation package.
  - Github: https://github.com/abgox/scoop-tools
  - Gitee: https://gitee.com/abgox/scoop-tools

### Config

#### abgox-abyss-app-uninstall-action

- It will control additional actions when uninstalling the app.
- You can set it using the following command:

  ```shell
  scoop config abgox-abyss-app-uninstall-action 123
  ```

- If not configured, the default value is `1`.
- Values can be combined, e.g. `12` means both `1` and `2` will execute.
- If you don't need them, you can set it to any value that does not include them.
- Configuration values and their action:

  | Value | Action                                                               |
  | ----- | -------------------------------------------------------------------- |
  | `1`   | Attempt to terminate processes before uninstallation/update          |
  | `2`   | Remove file/directory created by [Link](#link) during uninstallation |
  | `3`   | Clean up temporary data during uninstallation                        |

#### abgox-abyss-app-shortcuts-action

- Some apps in `abyss` are installed via installers, which automatically create shortcuts.
- Scoop also creates shortcuts defined in the manifest, which may result in duplicate shortcuts.
- So, you can use this config to control whether to create shortcuts defined in the manifest.

  ```shell
  scoop config abgox-abyss-app-shortcuts-action 2
  ```

- If not set, the default value is `1`.
- Configuration values and their action:

  | Value | Action                                                                                                                 |
  | :---: | ---------------------------------------------------------------------------------------------------------------------- |
  |  `0`  | **Do not create** shortcuts defined in the manifest                                                                    |
  |  `1`  | **Create** shortcuts defined in the manifest                                                                           |
  |  `2`  | If the app is installed via installer, **do not create** shortcuts defined in the manifest; otherwise, **create** them |

#### abgox-abyss-bucket-name

- It is only used to record the name of `abyss` added locally, and then it is used in some special cases.
- Don't modify it manually. When installing/updating/uninstalling an app in `abyss`, it will be automatically updated.
- For example:

  - You can install a specific version of JetBrains.WebStorm.

    ```shell
    scoop install abyss/JetBrains.WebStorm@2025.1.2
    ```

  - It will be used during installation to avoid installation errors.

- Reference: https://github.com/abgox/abyss/issues/10

### Persist

> [!Tip]
>
> Assume the Scoop root directory is `D:\scoop`

- Scoop provides a `persist` configuration in the manifest files, which can persist data files in the app directory.

  - Taking [abgox.PSCompletions](./bucket/a/abgox/abgox.PSCompletions.json) as an example, Scoop will install it to `D:\scoop\apps\abgox.PSCompletions`.
  - It will persist data directory and file:
    - `D:\scoop\apps\abgox.PSCompletions\completions` => `D:\scoop\persist\abgox.PSCompletions\completions`
    - `D:\scoop\apps\abgox.PSCompletions\data.json` => `D:\scoop\persist\abgox.PSCompletions\data.json`
  - When uninstalling [abgox.PSCompletions](./bucket/a/abgox/abgox.PSCompletions.json), Scoop only removes the `D:\scoop\apps\abgox.PSCompletions` directory, not the `D:\scoop\persist\abgox.PSCompletions` directory.
    - So, its settings and completion data will still be saved in the `D:\scoop\persist\abgox.PSCompletions` directory.
    - After reinstalling, the data will continue to be used again.
  - If the `-p/--purge` parameter is used when uninstalling, the `D:\scoop\persist\abgox.PSCompletions` directory will be removed.

- This is the most powerful feature of Scoop, which can quickly restore your app environment.
  - Some apps in `abyss` use [Link](#link), which cannot be reset correctly by `scoop reset`.
  - It is recommended to force update the app by `scoop update --force <app>`.

### Link

> [!Tip]
>
> Assume the Scoop root directory is `D:\scoop`

- Scoop's `persist` is powerful, but unfortunately, it has a limitation: it only works if the app data resides within the installation directory.
- However, some apps store their data outside the installation directory, commonly in `$env:AppData`.
- For such apps, they will use `New-Item -ItemType Junction` to link.
  - It uses the following rules to form the directory structure:
    - If there is `$env:UserProfile`, replace it with `$persist_dir`.
    - Otherwise, replace the drive letter with `$persist_dir`.
- Taking [Microsoft.VisualStudioCode](./bucket/m/Microsoft/Microsoft.VisualStudioCode.json) as an example:
  - [Microsoft.VisualStudioCode](./bucket/m/Microsoft/Microsoft.VisualStudioCode.json) stores its data in `$env:AppData\Code` and `$env:UserProfile\.vscode`
  - `$env:AppData` = `$env:UserProfile\AppData\Roaming`
  - `$persist_dir` = `D:\scoop\persist\Microsoft.VisualStudioCode`
  - It will link:
    - `$env:UserProfile\AppData\Roaming\Code` => `$persist_dir\AppData\Roaming\Code`
    - `$env:UserProfile\.vscode` => `$persist_dir\.vscode`

> [!Warning]
>
> - Some apps store data as files instead of directories, requiring SymbolicLink to link.
> - SymbolicLink requires administrator permission or [Developer Mode](https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging).
> - these apps will be added with the `RequireAdmin` tag in the [App List](#app-list).

---

### App List

> [!Tip]
>
> Check on the official website: https://abyss.abgox.com/app-list

- [English](./app-list.md)
- [简体中文](./app-list.zh-CN.md)
