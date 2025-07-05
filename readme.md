<p align="center">
    <h1 align="center">✨ abyss ✨</h1>
</p>

<p align="center">
    <a href="readme-cn.md">简体中文</a> |
    <a href="readme.md">English</a> |
    <a href="https://github.com/abgox/abyss">Github</a> |
    <a href="https://gitee.com/abgox/abyss">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/abyss/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/abyss" alt="license" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/abyss.svg">
        <img src="https://img.shields.io/github/languages/code-size/abgox/abyss.svg" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/abyss.svg">
        <img src="https://img.shields.io/github/repo-size/abgox/abyss.svg" alt="code size" />
    </a>
    <a href="https://github.com/abgox/abyss">
        <img src="https://img.shields.io/github/created-at/abgox/abyss" alt="created" />
    </a>
</p>

> [!Tip]
>
> [scoop/scoop-install/scoop-update completion in PSCompletions](https://github.com/abgox/PSCompletions) is recommended.

> [!Warning]
>
> - Manifests in `abyss` are based on [bin/utils.ps1](./bin/utils.ps1).
>   - They follow a special style that differs from the official Scoop buckets.
> - Some [features](#features) are included that are **not** part of the official Scoop specification.
> - Other buckets should not merge them. Otherwise, please verify their compatibility and availability.

### Features

#### Bucket

- Inspired by [winget-pkgs](https://github.com/microsoft/winget-pkgs).

  - Manifest naming format: `Publisher.PackageIdentifier`
  - Directory structure: `bucket/a/abgox/abgox.PSCompletions.json`

#### Manifest

- For apps that cannot use [persist](#persist), [Link](#link) will be used as a fallback.
- When uninstalling or updating an apps, the system will first attempt to terminate the process. For details, refer to [Config](#config).
- Improved information output during installation and uninstallation.
  - Localized output. (Chinese/English)
  - Shows notifications for environment variable modifications.

---

### If you are using Scoop

1.  Add `abyss` with Github or Gitee repository.

    ```powershell
    scoop bucket add abyss https://github.com/abgox/abyss.git
    ```

    ```powershell
    scoop bucket add abyss https://gitee.com/abgox/abyss.git
    ```

2.  Use [PSCompletions](https://github.com/abgox/PSCompletions) to add `scoop` completion.

    ```powershell
    scoop install abyss/abgox.PSCompletions
    ```

    ```powershell
    Import-Module PSCompletions
    ```

    ```powershell
    psc add scoop
    ```

3.  Install apps.

    ```powershell
    scoop install abyss/abgox.PSCompletions
    ```

### Demo

![Demo](https://abyss.abgox.com/demo.gif)

---

### If you are not using Scoop

- [What is Scoop?](https://scoop.sh/)
- [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Scoop install](https://github.com/ScoopInstaller/Install)
- [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)

---

### If you have problems accessing Github

> [!Tip]
>
> If you cannot access Github resources quickly due to network issues, you can try the following solutions.

1. Use the Gitee repository.

   ```powershell
   scoop bucket add abyss https://gitee.com/abgox/abyss.git
   ```

2. Install [scoop-install](https://gitee.com/abgox/scoop-tools) and [scoop-update](https://gitee.com/abgox/scoop-tools).

   ```powershell
   scoop install abyss/abgox.scoop-install
   ```

   ```powershell
   scoop install abyss/abgox.scoop-update
   ```

3. Configure URL replacement.

   ```powershell
   scoop config scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"
   ```

4. Use [PSCompletions](https://github.com/abgox/PSCompletions) to add command completion.

   ```powershell
   psc add scoop-install scoop-update
   ```

5. Use [scoop-install](https://gitee.com/abgox/scoop-tools) to install apps.

   ```powershell
   scoop-install abyss/Microsoft.PowerShell
   ```

6. Use [scoop-update](https://gitee.com/abgox/scoop-tools) to update apps.

   ```powershell
   scoop-update abyss/Microsoft.PowerShell
   ```

7. For more details, please visit:

   - https://github.com/abgox/scoop-tools
   - https://gitee.com/abgox/scoop-tools

---

### Config

#### app-uninstall-action-level

- Apps in `abyss` have some [features](#features) controlled by it.
- You can set it using the following command:

  ```powershell
  scoop config app-uninstall-action-level 123
  ```

- If not configured, the default value is `1`.
- Values can be combined, e.g. `12` means both `1` and `2` will execute.
- Configuration values and their action:

  | Value | Action                                                      |
  | ----- | ----------------------------------------------------------- |
  | `1`   | Attempt to terminate processes before uninstallation/update |
  | `2`   | Remove Link directories (those created by [Link](#link))    |
  | `3`   | Clean up temporary data during uninstallation               |

#### abgox-abyss-bucket-name

- It is used to record the name of `abyss` added locally, and then it is used in some special cases.
- It doesn't need to be modified manually. When installing/updating/uninstalling an app in `abyss`, it will be automatically updated.
- For example:
  - If you use `scoop install abyss/Microsoft.PowerShell@7.5.2` to specify version `7.5.2`.
  - It will be used during installation to avoid installation errors.
- Reference: https://github.com/abgox/abyss/issues/10

### Persist

> [!Tip]
>
> Assume the Scoop root directory is `D:\Scoop`

- Scoop provides a `persist` configuration in the manifest files, which can persist data files in the app directory.

  - Taking [abgox.PSCompletions](./bucket/a/abgox/abgox.PSCompletions.json) as an example, Scoop will install it to `D:\Scoop\apps\abgox.PSCompletions`.
  - It will persist data directory and file:
    - `D:\Scoop\apps\abgox.PSCompletions\completions` => `D:\Scoop\persist\abgox.PSCompletions\completions`
    - `D:\Scoop\apps\abgox.PSCompletions\data.json` => `D:\Scoop\persist\abgox.PSCompletions\data.json`
  - When uninstalling [abgox.PSCompletions](./bucket/a/abgox/abgox.PSCompletions.json), Scoop only removes the `D:\Scoop\apps\abgox.PSCompletions` directory, not the `D:\Scoop\persist\abgox.PSCompletions` directory.
    - So, its settings and completion data will still be saved in the `D:\Scoop\persist\abgox.PSCompletions` directory.
    - After reinstalling, the data will continue to be used again.
  - If the `-p/--purge` parameter is used when uninstalling, the `D:\Scoop\persist\abgox.PSCompletions` directory will be removed.

- This is the most powerful feature of Scoop, which can quickly restore your app environment.
  - Some apps in `abyss` use [Link](#link), which cannot be reset correctly by `scoop reset`.
  - It is recommended to force update the app by `scoop update --force <app>`.

### Link

> [!Tip]
>
> Assume the Scoop root directory is `D:\Scoop`

- Scoop's `persist` is powerful, but unfortunately, it has a limitation: it only works if the app data resides within the installation directory.
- However, some apps store their data outside the installation directory, commonly in `$env:AppData`.
- For such apps, they will use `New-Item -ItemType Junction` to link.
- Taking [Microsoft.VisualStudioCode](./bucket/m/Microsoft/Microsoft.VisualStudioCode.json) as an example:
  - [Microsoft.VisualStudioCode](./bucket/m/Microsoft/Microsoft.VisualStudioCode.json) stores its data in `$env:AppData\Code` and `$env:UserProfile\.vscode`
  - `$env:AppData` = `$env:UserProfile\AppData\Roaming`
  - `$persist_dir` = `D:\Scoop\persist\Microsoft.VisualStudioCode`
  - It will link:
    - `$env:UserProfile\AppData\Roaming\Code` => `$persist_dir\AppData\Roaming\Code`
    - `$env:UserProfile\.vscode` => `$persist_dir\.vscode`

> [!Warning]
>
> - Some apps store data as files instead of directories, requiring SymbolicLink to link.
> - SymbolicLink requires administrator permission, so these apps will be added with the `RequireAdmin` tag.

---

### App Manifests

[Gitee - abgox/abyss](https://gitee.com/abgox/abyss) may not display them normally, please use [Github - abgox/abyss](https://github.com/abgox/abyss).

- [English](./app-list.md)
- [简体中文](./app-list-cn.md)
