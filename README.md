# ⚡ NexusCopy v1.0

Advanced Roblox Map Copier — copy full maps with terrain, meshes, textures, audio, and server logic reconstruction.

## Features

- 🏔️ **Full Terrain Extraction** — voxel-by-voxel terrain capture
- 📦 **Asset Ripper** — scan & download all meshes, textures, audio, animations
- 🕵️ **Server Spy** — intercept Remote calls and reconstruct server scripts
- 📝 **Full Script Decompilation** — powered by USSI engine
- 🛡️ **Safe Mode** — kick before save for anti-cheat protection
- ⚡ **One-Click Copy** — single script runs everything

## Quick Start

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/nightmarescriptsatu-png/NexusCopy/main/main.luau", 
    true
))()
```

## Full Copy (Recommended)

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/nightmarescriptsatu-png/NexusCopy/main/main.luau", 
    true
))()({
    mode = "full",
    IncludeTerrain = true,
    IncludeAssets = true,
    DownloadAssets = true,
    ServerSpy = true,
    ServerSpyDuration = 120,
    Decompile = true,
    NilInstances = true,
    SafeMode = true,
})
```

## Output Files

| File | Contents |
|---|---|
| `[Game].rbxlx` | Full instance tree |
| `NexusCopy_Terrain.luau` | Terrain restore script (run in Studio) |
| `NexusCopy_Assets.json` | Asset manifest with download URLs |
| `NexusCopy_Download.ps1` | PowerShell batch asset downloader |
| `NexusCopy_ServerSpy_Report.txt` | Remote communication logs |
| `NexusCopy_ServerStubs.lua` | Auto-generated server scripts |

## Credits

Built with [UniversalSynSaveInstance](https://github.com/luau/UniversalSynSaveInstance) as the core saveinstance engine.
