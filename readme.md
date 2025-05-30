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
> If you cannot access Github resources due to network issues, you can try the following solutions:

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
4. Use [scoop-install](https://gitee.com/abgox/scoop-install) to install applications.

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
  - Some applications use [Link](#link), which cannot be reset correctly by `scoop reset`.
  - It is recommended to uninstall and reinstall it.

### Link

> [!Tip]
>
> Assume the Scoop root directory is `D:\Scoop`

- Scoop's `persist` is powerful, but unfortunately, it has a limitation: it only works if the application data resides within the installation directory.
- However, some applications store their data outside the installation directory, commonly in `$env:AppData`.
- For such applications, this repository uses `New-Item -ItemType Junction` to link.
- Taking [Helix](./bucket/Helix.json) as an example:
  - [Helix](./bucket/Helix.json) stores its data in `$env:AppData\helix`
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
    - **➖** : It is not necessary, or there are no data files.
    - **`Link`** : Use `New-Item -ItemType Junction` to persist. Refer to [Link](#link) for details.
  - **`Tag`**
    - `Font` : A font.
    - `PSModule` : A [PowerShell Module](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules).
    - `NoAutoUpdate` : `json.autoupdate` are not configured, and Scoop cannot automatically detect updates.
  - **`Description`** : App Description.

---

<!-- prettier-ignore-start -->
|App (62)|Version|Persist|Tag|Description|
|:-:|:-:|:-:|:-:|-|
|[AppFlowy](https://www.appflowy.io/)|<a href="./bucket/AppFlowy.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FAppFlowy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||An open-source alternative to Notion. You are in charge of your data and customizations.|
|[Bruno](https://www.usebruno.com/)|<a href="./bucket/Bruno.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FBruno.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Opensource IDE For Exploring and Testing API's (lightweight alternative to Postman/Insomnia).|
|[Carnac](http://carnackeys.com/)|<a href="./bucket/Carnac.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCarnac.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A keyboard logging and presentation utility.|
|[Cherry-Studio](https://cherry-ai.com)|<a href="./bucket/Cherry-Studio.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FCherry-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A desktop client that supports for multiple LLM providers.|
|[clash-verge-rev](https://github.com/clash-verge-rev/clash-verge-rev)|<a href="./bucket/clash-verge-rev.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fclash-verge-rev.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A modern GUI client based on Tauri for tailored proxy experience.|
|[DownKyi](https://github.com/leiurayer/downkyi)|<a href="./bucket/DownKyi.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FDownKyi.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A bilibili video download tool.|
|[draw.io](https://www.diagrams.net)|<a href="./bucket/draw.io.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fdraw.io.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A diagramming desktop app based on Electron that wraps the core draw.io editor.|
|[Escrcpy](https://github.com/viarotel-org/escrcpy)|<a href="./bucket/Escrcpy.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FEscrcpy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Graphical Scrcpy to display and control Android, devices powered by Electron.|
|[eSearch](https://esearch-app.netlify.app/)|<a href="./bucket/eSearch.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FeSearch.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Screenshot OCR search translate search for picture paste the picture on the screen screen recorder.|
|[Flow-Launcher](https://www.flowlauncher.com)|<a href="./bucket/Flow-Launcher.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFlow-Launcher.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Quick file searcher and app launcher with community-made plugins.|
|[Fluent-Search](https://github.com/adirh3/Fluent-Search)|<a href="./bucket/Fluent-Search.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFluent-Search.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||With it, you can search for running apps, browser tabs, in-app content, files and more.|
|[Font-Hack-NF](https://github.com/ryanoasis/nerd-fonts)|<a href="./bucket/Font-Hack-NF.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Hack-NF.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|Nerd Fonts patched 'Hack' Font family.|
|[Font-Maple-Mono-Normal-NL-NF-CN-Unhinted](https://github.com/subframe7536/Maple-font)|<a href="./bucket/Font-Maple-Mono-Normal-NL-NF-CN-Unhinted.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Maple-Mono-Normal-NL-NF-CN-Unhinted.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`| An open source monospace font with round corner and ligatures for IDE and command line. (version: Normal-NL-NF-CN-Unhinted)|
|[Font-Sarasa-Fixed-SC](https://github.com/be5invis/Sarasa-Gothic)|<a href="./bucket/Font-Sarasa-Fixed-SC.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFont-Sarasa-Fixed-SC.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖|`Font`|A perfectly 2:1 monospaced font. (version: Fixed-SC)|
|[FSViewer](https://www.faststone.org/FSViewerDetail.htm)|<a href="./bucket/FSViewer.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FFSViewer.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||FastStone Image Viewer is a fast, stable, user-friendly image browser, converter and editor.|
|[GeekUninstaller](https://geekuninstaller.com/)|<a href="./bucket/GeekUninstaller.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGeekUninstaller.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||The good free uninstaller.|
|[GitExtensions](https://gitextensions.github.io/)|<a href="./bucket/GitExtensions.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGitExtensions.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A standalone UI tool for managing git repositories.|
|[Gopeed](https://gopeed.com)|<a href="./bucket/Gopeed.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FGopeed.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A modern download manager. Built with Golang and Flutter.|
|[HashCalculator](https://github.com/hrpzcf/HashCalculator)|<a href="./bucket/HashCalculator.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHashCalculator.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A file hash calculator, which can calculate/verify/find duplicate files/change hash values in batch.|
|[HBuilderX](https://www.dcloud.io/hbuilderx.html)|<a href="./bucket/HBuilderX.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHBuilderX.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A code editor by DCloud.|
|[Helix](https://helix-editor.com)|<a href="./bucket/Helix.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FHelix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A post-modern modal text editor.|
|[ImageGlass](https://imageglass.org)|<a href="./bucket/ImageGlass.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FImageGlass.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A lightweight, versatile image viewer.|
|[InputTip-zip](https://inputtip.abgox.com)|<a href="./bucket/InputTip-zip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip-zip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||An input method status tip tool (zip version).|
|[InputTip](https://inputtip.abgox.com/)|<a href="./bucket/InputTip.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInputTip.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||An input method status tip tool (exe version).|
|[Insomnia](https://insomnia.rest)|<a href="./bucket/Insomnia.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FInsomnia.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||The open-source, cross-platform API client for GraphQL, REST, WebSockets, SSE and gRPC. With Cloud, Local and Git storage.|
|[Keyviz](https://mularahul.github.io/keyviz)|<a href="./bucket/Keyviz.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FKeyviz.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A free and open-source tool to visualize your keystrokes ⌨️ and 🖱️ mouse actions in real-time.|
|[Koodo-Reader](https://koodo.960960.xyz)|<a href="./bucket/Koodo-Reader.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FKoodo-Reader.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A cross-platform ebook reader.|
|[Listary](https://www.listary.com)|<a href="./bucket/Listary.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FListary.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A revolutionary search utility for Windows.|
|[LocalSend](https://localsend.org/)|<a href="./bucket/LocalSend.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLocalSend.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A free, open-source app that allows you to securely share files and messages with nearby devices over your local network without needing an internet connection.|
|[LX-Music](https://github.com/lyswhut/lx-music-desktop)|<a href="./bucket/LX-Music.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FLX-Music.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||An electron-based music player.|
|[MarkText](https://www.marktext.cc)|<a href="./bucket/MarkText.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMarkText.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A simple and elegant markdown editor.|
|[Motrix](https://motrix.app)|<a href="./bucket/Motrix.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMotrix.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A full-featured download manager.|
|[MusicPlayer2](https://github.com/zhongyang219/MusicPlayer2)|<a href="./bucket/MusicPlayer2.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FMusicPlayer2.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Audio player which supports music collection playback, lyrics display, format conversion and many other functions.|
|[Neovide](https://neovide.dev)|<a href="./bucket/Neovide.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNeovide.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A simple graphical user interface for Neovim.|
|[Neovim](https://neovim.io/)|<a href="./bucket/Neovim.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNeovim.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A project that seeks to aggressively refactor Vim.|
|[NotepadNext](https://github.com/dail8859/NotepadNext)|<a href="./bucket/NotepadNext.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNotepadNext.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A cross-platform, reimplementation of Notepad++.|
|[Nushell](https://www.nushell.sh)|<a href="./bucket/Nushell.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FNushell.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A new type of shell written in Rust.|
|[OBS-Studio](https://obsproject.com)|<a href="./bucket/OBS-Studio.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FOBS-Studio.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Free and open source software for video recording and live streaming.|
|[Obsidian](https://obsidian.md)|<a href="./bucket/Obsidian.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FObsidian.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Powerful knowledge base that works on top of a local folder of plain text Markdown files.|
|[PixPin](https://pixpin.cn/)|<a href="./bucket/PixPin.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FPixPin.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A powerful and simple screenshot/stick/screen recording tool.|
|[pot](https://pot-app.com/)|<a href="./bucket/pot.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fpot.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A cross-platform software for text translation and OCR.|
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
|[QtScrcpy](https://github.com/barry-ran/QtScrcpy)|<a href="./bucket/QtScrcpy.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FQtScrcpy.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Display and control Android device via TCP/IP or USB.|
|[RustDesk](https://github.com/rustdesk/rustdesk)|<a href="./bucket/RustDesk.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FRustDesk.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||An open-source remote desktop software, written in Rust.|
|[scoop-install](https://gitee.com/abgox/scoop-install)|<a href="./bucket/scoop-install.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2Fscoop-install.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|➖||A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when installing the app in Scoop.|
|[ScreenToGif](https://www.screentogif.com/)|<a href="./bucket/ScreenToGif.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FScreenToGif.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Screen, webcam and sketchboard recorder with an integrated editor.|
|[SQLynx](https://www.sqlynx.com/)|<a href="./bucket/SQLynx.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSQLynx.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||Native Web-Based SQL IDE, support desktop and web management for enterprise. It's a cross-platform database tool for everyone working with data.|
|[Steampp](https://steampp.net/)|<a href="./bucket/Steampp.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSteampp.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A toolbox with lots of Steam tools. It's also known as Watt Toolkit.|
|[STranslate](https://stranslate.zggsong.com)|<a href="./bucket/STranslate.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FSTranslate.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A ready-to-go translation ocr tool.|
|[Tabby](https://tabby.sh)|<a href="./bucket/Tabby.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTabby.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||A terminal for a more modern age.|
|[Typora](https://typora.io)|<a href="./bucket/Typora.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FTypora.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|`Link`||A Markdown editor and reader.|
|[VSCode](https://code.visualstudio.com/)|<a href="./bucket/VSCode.json"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2FVSCode.json&query=%24.version&prefix=v&label=%20" alt="version" /></a>|✔️||Lightweight but powerful source code editor.|
<!-- prettier-ignore-end -->
