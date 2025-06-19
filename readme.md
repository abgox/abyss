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
> [scoop and scoop-install completion in PSCompletions](https://github.com/abgox/PSCompletions) is recommended.

> [!Warning]
>
> - Manifests in `abyss` is based on [bin/utils.ps1](./bin/utils.ps1).
> - If other buckets want to merge them, be careful to check availability.

### Features

#### Bucket

- `abyss` draws on the naming format of [winget-pkgs](https://github.com/microsoft/winget-pkgs): `Publisher.PackageIdentifier`

#### Manifest

- For apps that cannot use [persist](#persist), [Link](#link) will be used as a fallback.
- When uninstalling or updating an apps, the system will first attempt to terminate the process. For details, refer to [Config](#config).
- Improved information output during installation and uninstallation.
  - Localized output. (Chinese/English)
  - Shows notifications for environment variable modifications.

---

### If you are using Scoop

1.  Add `abyss` with Github or Gitee repository.

    ```pwsh
    scoop bucket add abyss https://github.com/abgox/abyss.git
    ```

    ```pwsh
    scoop bucket add abyss https://gitee.com/abgox/abyss.git
    ```

2.  Install apps.

    ```pwsh
    scoop install abyss/InputTip-zip
    ```

---

### If you are not using Scoop

- [What is Scoop?](https://scoop.sh/)
- [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Scoop install](https://github.com/ScoopInstaller/Install)
- [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)

---

### If you cannot access Github

> [!Tip]
>
> If you cannot access Github resources due to network issues, you can try the following solutions.

1. Use the Gitee repository.
   ```pwsh
   scoop bucket add abyss https://gitee.com/abgox/abyss.git
   ```
2. Install [scoop-install](https://gitee.com/abgox/scoop-install).
   ```pwsh
   scoop install abyss/scoop-install
   ```
3. Configure URL replacement settings.
   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```
4. Use [scoop-install](https://gitee.com/abgox/scoop-install) to install apps.

   ```pwsh
   scoop-install abyss/InputTip-zip
   ```

5. See [scoop-install](https://gitee.com/abgox/scoop-install) for more details.

---

### Config

- Apps in `abyss` have some [features](#features) controlled by `app-uninstall-action-level`.
- You can set it using the following command:

  ```pwsh
  scoop config app-uninstall-action-level 123
  ```

- If not configured, the default value is `1`.

- Configuration values and their action:

  - Values can be combined, e.g. `12` means both `1` and `2` will execute.

  | Value | Action                                                      |
  | ----- | ----------------------------------------------------------- |
  | `0`   | No additional operations                                    |
  | `1`   | Attempt to terminate processes before uninstallation/update |
  | `2`   | Remove Link directories (those created by [Link](#link))    |
  | `3`   | Clean up temporary data during uninstallation               |

### Persist

> [!Tip]
>
> Assume the Scoop root directory is `D:\Scoop`

- Scoop provides a `persist` configuration in the manifest files, which can persist data files in the app directory.

  - Taking [PSCompletions](./bucket/PSCompletions.json) as an example, Scoop will install it to `D:\Scoop\apps\PSCompletions`.
  - It will persist data directory and file:
    - `D:\Scoop\apps\PSCompletions\completions` => `D:\Scoop\persist\PSCompletions\completions`
    - `D:\Scoop\apps\PSCompletions\data.json` => `D:\Scoop\persist\PSCompletions\data.json`
  - When uninstalling [PSCompletions](./bucket/PSCompletions.json), Scoop only removes the `D:\Scoop\apps\PSCompletions` directory, not the `D:\Scoop\persist\PSCompletions` directory.
    - So, its settings and completion data will still be saved in the `D:\Scoop\persist\PSCompletions` directory.
    - After reinstalling, the data will continue to be used again.
  - If the `-p/--purge` parameter is used when uninstalling, the `D:\Scoop\persist\PSCompletions` directory will be removed.

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
- Taking [VSCode](./bucket/VSCode.json) as an example:
  - [VSCode](./bucket/VSCode.json) stores its data in `$env:AppData\Code` and `$env:UserProfile\.vscode`
  - `$env:AppData` = `$env:UserProfile\AppData\Roaming`
  - `$persist_dir` = `D:\Scoop\persist\VSCode`
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
