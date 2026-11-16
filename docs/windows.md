# Drift in Windows Terminal

On 64-bit Windows, run the setup executable to install Drift, mpv, and yt-dlp
for your account. Open Drift from the Start menu. Remove it through **Settings
→ Apps → Installed apps** or by running `unins000.exe` in the install folder.
Your settings and playlists live separately in `%APPDATA%\drift`.

## Portable ZIP

1. Extract the ZIP to a folder of your choice.
2. Install native mpv and put `mpv.exe` on your `PATH`. With Scoop, run `scoop bucket add extras` if needed, then `scoop install mpv`.
3. Open a new Windows Terminal PowerShell tab in the extracted folder.

```powershell
.\drift.exe --check
.\drift.exe
```

The ZIP includes the official [yt-dlp Windows executable](https://github.com/yt-dlp/yt-dlp/releases). Keep it beside Drift. If playback reports HTTP 403, use `--check` to see which version and path Drift is using. Replace that copy with the current official `yt-dlp.exe` if needed, then restart Drift. In the player, use `:play` to retry the stopped track or `:next` to skip it.

Compare the release's `.zip.sha256` value with the result of `Get-FileHash -Algorithm SHA256` on the ZIP. The archive includes the source for Drift and the bundled yt-dlp under `source/`.

The setup executable has its own `.exe.sha256` file and includes the
[mpv 0.41.0 Windows build](https://sourceforge.net/projects/mpv-player-windows/files/release/)
with its license. See the [mpv source](https://github.com/mpv-player/mpv/tree/v0.41.0)
and [Windows build scripts](https://github.com/shinchiro/mpv-winbuild-cmake).
