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

- [Scoop completion in PSCompletions ](https://github.com/abgox/PSCompletions "PSCompletions")is recommended.

### For ones familiar with Scoop

1.  Add `abyss`. (Use Github or Gitee repository.)

    ```pwsh
    scoop bucket add abyss https://github.com/abgox/abyss
    ```

    ```pwsh
    scoop bucket add abyss https://gitee.com/abgox/abyss
    ```

2.  Install apps. (e.g. `InputTip-zip`)

    ```pwsh
    scoop install abyss/InputTip-zip
    ```

---

### Never used Scoop

- [What is Scoop?](https://scoop.sh/)
- [What is bucket in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)
- [What is App-Manifests in Scoop?](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Scoop install](https://github.com/ScoopInstaller/Install)
- [Scoop Document](https://github.com/ScoopInstaller/Scoop/wiki)

---

### Unable to Access Github Resources

> [!Tip]
>
> If you cannot access Github resources due to network issues, you can try the following solutions:

1. Use the Gitee repository
   ```pwsh
   scoop bucket add abyss https://gitee.com/abgox/abyss
   ```
2. Install [scoop-install](https://gitee.com/abgox/scoop-install)
   ```pwsh
   scoop install abyss/scoop-install
   ```
3. Configure URL replacement settings
   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```
4. Use [scoop-install](https://gitee.com/abgox/scoop-install) to install applications. For example, install `InputTip-zip`:

   ```pwsh
   scoop-install abyss/InputTip-zip
   ```

5. See [scoop-install](https://gitee.com/abgox/scoop-install) for more details.

---

### Persist

> [!Tip]
>
> Assume the Scoop root directory is `D:\Scoop`

- Scoop provides a `persist` configuration in the manifest files, which can persist data files in the application directory.
  - Taking [VSCode.json](./bucket/VSCode.json) as an example, Scoop will install it to `D:\Scoop\apps\VSCode`.
  - It will persist data directory: `D:\Scoop\apps\VSCode\data` => `D:\Scoop\persist\VSCode\data`.
  - After uninstalling, its settings, plugins, keybindings and other data will still be saved in the `D:\Scoop\apps\VSCode\data` directory.
    - If the `-p/--purge` parameter is used when uninstalling, the `D:\Scoop\persist\VSCode` directory will be removed.
  - After reinstalling, the data will continue to be used again.
- This is the most powerful feature of Scoop, which can quickly restore your application environment.
  - If you change to a new computer, just back up the `D:\Scoop` directory to new computer and run the following command to restore all applications.
    ```pwsh
    scoop reset *
    ```

## Link

> [!Tip]
>
> Assume the Scoop root directory is `D:\Scoop`

- Scoop's `persist` is extremely powerful, but unfortunately, it has a limitation: it only works if the application data resides within the installation directory.
- However, some applications store their data outside the installation directory, commonly in `$env:AppData`.
- For such applications, this repository uses `New-Item -ItemType Junction` to link.
- Taking [Helix](./bucket/Helix.json) as an example:
  - [Helix](./bucket/Helix.json) stores its data in `$env:AppData\helix`.
  - It will link: `$env:AppData\helix` => `D:\Scoop\persist\Helix\helix`

> [!Warning]
>
> Note: The linked directory will not be removed when the application is uninstalled.

---

### App Manifests

[简体中文](./readme-cn.md#应用清单) | [English](readme.md#app-manifests)

- Guide

  - **`App`** : App package name.
    - Click to view the official website or repository.
    - Sort by first letter(0-9,a-z).
  - **`Version`** : App version.
    - Click to view the manifest json file.
  - **`Persist`** : Persist data. Refer to [Persist](#persist) for details.
    - **✔️** : It has been done.
    - **`Link`** : Use `New-Item -ItemType Junction` to persist. Refer to [Link](#link) for details.
    - **➖** : It's not necessary, or the conditions are not meet.(e.g. data file not found)
  - **`Tag`**
    - `Font` : A font.
    - `PSModule` : A [PowerShell Module](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules).
    - `NoAutoUpdate` : `json.autoupdate` are not configured, and Scoop cannot automatically detect updates.
  - **`Description`** : App Description.

---

<!-- prettier-ignore-start -->
|App (30)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[DownKyi](https://github.com/leiurayer/downkyi)|<a href="./bucket/DownKyi.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FDownKyi.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A bilibili video download tool.|
|[eSearch](https://esearch-app.netlify.app/)|<a href="./bucket/eSearch.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FeSearch.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Screenshot OCR search translate search for picture paste the picture on the screen screen recorder.|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|<a href="./bucket/Font-Hack-NF.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Hack-NF.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|Nerd Fonts patched 'Hack' Font family.|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|<a href="./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Maple-Mono-Normal-NL-NF-CN-Unhinted.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`| An open source monospace font with round corner and ligatures for IDE and command line. (version: Normal-NL-NF-CN-Unhinted)|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|<a href="./bucket/Font-Sarasa-Fixed-SC.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Sarasa-Fixed-SC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|A perfectly 2:1 monospaced font. (version: Fixed-SC)|
|[FSViewer](https://www.faststone.org/FSViewerDetail.htm)|<a href="./bucket/FSViewer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFSViewer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||FastStone Image Viewer is a fast, stable, user-friendly image browser, converter and editor.|
|[HashCalculator](https://github.com/hrpzcf/HashCalculator)|<a href="./bucket/HashCalculator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHashCalculator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A file hash calculator, which can calculate/verify/find duplicate files/change hash values in batch.|
|[Helix](https://helix-editor.com)|<a href="./bucket/Helix.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHelix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A post-modern modal text editor.|
|[InputTip-zip](https://inputtip.abgox.com)|<a href="./bucket/InputTip-zip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip-zip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||An input method status tip tool (zip version).|
|[InputTip](https://inputtip.abgox.com/)|<a href="./bucket/InputTip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||An input method status tip tool (exe version).|
|[LocalSend](https://localsend.org/)|<a href="./bucket/LocalSend.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLocalSend.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A free, open-source app that allows you to securely share files and messages with nearby devices over your local network without needing an internet connection.|
|[LX-Music](https://github.com/lyswhut/lx-music-desktop)|<a href="./bucket/LX-Music.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLX-Music.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||An electron-based music player.|
|[PixPin](https://pixpin.cn/)|<a href="./bucket/PixPin.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPixPin.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A powerful and simple screenshot/stick/screen recording tool.|
|[PotPlayer](https://potplayer.daum.net)|<a href="./bucket/PotPlayer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPotPlayer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Highly customizable media player.|
|[PowerToysRun-ClipboardManager](https://github.com/CoreyHayward/PowerToys-Run-ClipboardManager)|<a href="./bucket/PowerToysRun-ClipboardManager.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ClipboardManager.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin for easily searching and pasting the clipboard history.|
|[PowerToysRun-Everything](https://github.com/lin-ycv/EverythingPowerToys)|<a href="./bucket/PowerToysRun-Everything.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Everything.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||Everything search plugin for PowerToys Run.|
|[PowerToysRun-GitHubRepo](https://github.com/8LWXpg/PowerToysRun-GitHubRepo)|<a href="./bucket/PowerToysRun-GitHubRepo.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-GitHubRepo.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin for searching and opening GitHub repositories.|
|[PowerToysRun-HttpStatusCodes](https://github.com/grzhan/HttpStatusCodePowerToys)|<a href="./bucket/PowerToysRun-HttpStatusCodes.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-HttpStatusCodes.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin for searching HTTP status codes.|
|[PowerToysRun-Pomodoro](https://github.com/ruslanlap/PowerToysRun-Pomodoro)|<a href="./bucket/PowerToysRun-Pomodoro.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Pomodoro.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin for managing your productivity sessions.|
|[PowerToysRun-ProcessKiller](https://github.com/8LWXpg/PowerToysRun-ProcessKiller)|<a href="./bucket/PowerToysRun-ProcessKiller.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-ProcessKiller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin for killing processes.|
|[PowerToysRun-Scoop](https://github.com/Quriz/PowerToysRunScoop)|<a href="./bucket/PowerToysRun-Scoop.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Scoop.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin that allows you to search, install, update and uninstall packages from the Scoop package manager.|
|[PowerToysRun-Translator](https://github.com/N0I0C0K/PowerTranslator)|<a href="./bucket/PowerToysRun-Translator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Translator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A translate plugin for PowerToys Run.|
|[PowerToysRun-Winget](https://github.com/bostrot/PowerToysRunPluginWinget)|<a href="./bucket/PowerToysRun-Winget.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPowerToysRun-Winget.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerToys Run plugin that allows you to search and install packages from the Winget package manager.|
|[PSCompletions](https://pscompletions.abgox.com/)|<a href="./bucket/PSCompletions.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPSCompletions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️|`PSModule`|A completion manager for better and simpler use completions in PowerShell.|
|[scoop-install](https://gitee.com/abgox/scoop-install)|<a href="./bucket/scoop-install.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fscoop-install.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when installing the app in Scoop.|
|[ScreenToGif](https://www.screentogif.com/)|<a href="./bucket/ScreenToGif.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FScreenToGif.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Screen, webcam and sketchboard recorder with an integrated editor.|
|[Steampp](https://steampp.net/)|<a href="./bucket/Steampp.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSteampp.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A toolbox with lots of Steam tools. It's also known as Watt Toolkit.|
|[STranslate](https://stranslate.zggsong.com)|<a href="./bucket/STranslate.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSTranslate.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A ready-to-go translation ocr tool.|
|[Tabby](https://tabby.sh)|<a href="./bucket/Tabby.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTabby.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A terminal for a more modern age.|
|[VSCode](https://code.visualstudio.com/)|<a href="./bucket/VSCode.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVSCode.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Lightweight but powerful source code editor.|
<!-- prettier-ignore-end -->
