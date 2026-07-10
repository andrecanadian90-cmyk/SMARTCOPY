# SMARTCOPY

### copy by Ndrew | https://bernadaclub.my.id

> **Game Copier & Server Reconstructor untuk Roblox**
> Save, decompile, fix, dan rebuild game Roblox dari client-side dengan kualitas maximum.

---

## 🚀 CARA PAKAI (Copy-Paste ke Executor)

### Cara 1: All-in-One (Recommended)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/main.luau", true))()({
    mode = "full",
    IncludeTerrain = false,
    IncludeAssets = true,
    DownloadAssets = true,
    ServerSpy = false,
    ServerSpyDuration = 60,
    Decompile = true,
    NilInstances = true,
    SafeMode = true,
})
```
> Jalankan otomatis: Union fix → Save → Decompile → Asset scan → Terrain — dalam 1 script!

### Cara 2: GUI Menu (Pilih Manual)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/loader.luau"))()
```
> Menu GUI akan muncul di layar. Tinggal klik module yang mau dijalankan!

### Cara 2: Jalankan Module Tertentu
```lua
-- UnionFixer (jalankan SEBELUM save)
loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/modules/UnionFixer.luau"))()

-- ServerSpy (intercept semua remote)
local ServerSpy = loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/modules/ServerSpy.luau"))()
ServerSpy:Start()
-- mainkan game 2-5 menit, lalu:
ServerSpy:Stop()
ServerSpy:CopyReport()

-- DecompileChecker (retry decompile yg gagal)
loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/modules/DecompileChecker.luau"))()

-- AssetRipper (scan semua asset ID)
local AssetRipper = loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/modules/AssetRipper.luau"))()
AssetRipper:Scan({workspace})
AssetRipper:CopyReport()
AssetRipper:CopyDownloadScript("python") -- atau "powershell"

-- TerrainExtractor (extract terrain)
local TerrainExtractor = loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/modules/TerrainExtractor.luau"))()
TerrainExtractor:Extract()
TerrainExtractor:CopyRestoreScript()

-- WatermarkReplacer (ganti watermark USSI)
loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/modules/WatermarkReplacer.luau"))()
```

### Urutan Workflow Lengkap
```
1. Join game target dengan executor
2. Execute: UnionFixer          → fix Union sebelum save
3. Execute: USSI SaveInstance   → save game ke .rbxl
4. Execute: DecompileChecker    → retry script gagal decompile
5. Execute: WatermarkReplacer   → ganti branding
6. Execute: ServerSpy           → mainkan game, capture remotes
7. Execute: AssetRipper         → scan semua asset
8. Execute: TerrainExtractor    → extract terrain (jika ada)
```

---

## 📦 Struktur Repo

```
SMARTCOPY/
├── main.luau                          # Script utama (entry point)
├── README.md                          # Dokumentasi ini
├── modules/                           # Tool modules (jalankan di executor)
│   ├── ServerSpy.luau                 # Remote interceptor & server logic reconstructor
│   ├── AssetRipper.luau               # Asset ID scanner & batch downloader
│   ├── TerrainExtractor.luau          # Full terrain voxel data extractor
│   ├── UnionFixer.luau                # Union → MeshPart converter (fix broken unions)
│   ├── DecompileChecker.luau          # Dynamic decompile retry engine
│   ├── WatermarkReplacer.luau         # Replace USSI watermark dengan branding custom
│   ├── WatermarkCleaner.luau          # Hapus watermark USSI dari semua script
│   └── Utilities.luau                 # Shared utility functions
└── rebuild_scripts/                   # Server-side scripts yang di-rebuild manual
    ├── PASTE_IN_COMMAND_BAR.lua       # Installer script (paste di Studio Command Bar)
    ├── INSTALL_GUIDE.lua              # Panduan install step-by-step
    └── ServerScriptService/
        ├── ByteNetServer.server.lua   # Handler utama ByteNet (semua fitur game)
        ├── MainServer.server.lua      # Player join/leave, character setup
        ├── DonationBoardServer.server.lua
        ├── EffectsServer.server.lua
        ├── ServerListServer.server.lua
        └── Services/
            ├── OverheadService.luau   # Nametag overhead system
            └── PlayersService.luau    # OpRank admin system
```

---

## 🛠️ Fitur Modules

### 1. 🕵️ ServerSpy v2 (MAX LEVEL)
**File:** `modules/ServerSpy.luau`

Intercept SEMUA komunikasi client-server untuk rekonstruksi logic server.

| Fitur | Detail |
|---|---|
| Dual Hook Engine | `hookfunction` + `__namecall` metamethod hook |
| Return Value Capture | Capture return dari RemoteFunction |
| Call Stack Tracking | Tau script mana yang manggil remote |
| Deep Serialization | 6 level depth, buffer/binary support |
| Frequency Analysis | Auto-detect heartbeat vs action (calls/sec) |
| Smart Categorization | HEARTBEAT, ANIMATION, ECONOMY, SOCIAL, ADMIN, dll |
| Example Storage | Simpan 5 contoh call pertama per remote |
| Real-time Logging | Print live saat game berjalan |
| Timing Correlation | Link remote call ↔ instance spawn |
| Attribute Monitoring | Track attribute changes pada karakter |
| Server Stub Generator | Generate runnable server scripts dari data observasi |
| Clipboard Export | `CopyReport()` dan `CopyStubs()` |

```lua
-- Cara pakai:
ServerSpy:Start()              -- mulai monitoring
-- mainkan game 2-5 menit --
ServerSpy:Stop()               -- stop
ServerSpy:CopyReport()         -- copy full report
ServerSpy:CopyStubs()          -- copy generated server scripts
```

---

### 2. 🎨 AssetRipper
**File:** `modules/AssetRipper.luau`

Scan semua instance untuk extract asset IDs (mesh, texture, sound, animation, dll).

| Fitur | Detail |
|---|---|
| Full Property Scan | MeshId, TextureId, SoundId, Image, AnimationId, dll |
| Auto Categorize | Mesh, Texture, Sound, Animation, Decal, Sky, dll |
| Deduplicate | Hapus duplikat asset ID otomatis |
| Batch Download Script | Generate PowerShell/Python script download |
| Usage Tracking | Catat instance mana yang pakai asset mana |

```lua
AssetRipper:Scan({workspace})
AssetRipper:GetStats()              -- jumlah per kategori
AssetRipper:GenerateDownloadScript() -- script download batch
```

---

### 3. 🏔️ TerrainExtractor
**File:** `modules/TerrainExtractor.luau`

Extract FULL terrain voxel data dari game.

| Fitur | Detail |
|---|---|
| Chunk Processing | 64x64x64 chunks (optimal memory) |
| Material & Occupancy | Save Materials + Occupancy data |
| Smart Skip | Skip empty chunks otomatis |
| Luau Output | Generate executable Luau code untuk recreate terrain |
| Progress Callback | Real-time progress reporting |

```lua
TerrainExtractor:Extract({onProgress = function(pct) print(pct.."%") end})
TerrainExtractor:SerializeForReplay()  -- Luau code output
```

---

### 4. 🔧 UnionFixer
**File:** `modules/UnionFixer.luau`

Convert UnionOperations → MeshParts sebelum save, supaya visual tetap intact.

| Fitur | Detail |
|---|---|
| Hidden Property Read | Baca `AssetId` via `gethiddenproperty()` |
| Full Property Copy | Transform, appearance, physics, children, attributes, tags |
| Constraint Retargeting | Update WeldConstraint/Joint references otomatis |
| Safety Fallback | Union tanpa AssetId ditandai untuk review manual |

```lua
-- Jalankan SEBELUM USSI save:
UnionFixer:Run({workspace})
```

---

### 5. 🔄 DecompileChecker v2
**File:** `modules/DecompileChecker.luau`

Dynamic retry engine — decompile ulang script yang gagal dengan timeout eskalasi.

| Fitur | Detail |
|---|---|
| Auto Detection | Scan semua script untuk "Failed to decompile" markers |
| Escalating Timeout | 15s → 30s → 60s → 120s → 240s → 300s |
| Progress Tracking | Per-round reporting |
| Smart Stop | Stop kalau semua selesai atau tidak ada progress |
| Final Report | Success rate + daftar script yang masih gagal |

```lua
-- Jalankan SETELAH USSI save:
DecompileChecker:Run()
```

---

### 6. 🏷️ WatermarkReplacer
**File:** `modules/WatermarkReplacer.luau`

Replace watermark USSI dengan branding custom.

```lua
-- Default: "copy by Ndrew | https://bernadaclub.my.id"
WatermarkReplacer:Run()
```

---

### 7. 🧹 WatermarkCleaner
**File:** `modules/WatermarkCleaner.luau`

Hapus total watermark USSI dari semua script (tanpa replace).

---

## 🏗️ Rebuild Scripts (Kelas Malam)

Server scripts yang sudah di-reconstruct untuk game **Kelas Malam**:

| Script | Fungsi |
|---|---|
| `ByteNetServer` | Handler utama: Dances, Tools, Likes, Music, Carry, Profile Sync, Overhead |
| `MainServer` | Player join/leave, character setup |
| `OverheadService` | Nametag floating di atas kepala (clone dari template, dynamic update) |
| `PlayersService` | OpRank admin system |
| `DonationBoardServer` | Donation leaderboard |
| `EffectsServer` | Visual effects replication |
| `ServerListServer` | Server list & player count |

---

## 🚀 Workflow Lengkap

```
1. Join game target dengan executor
2. Jalankan UnionFixer         → fix Union sebelum save
3. Jalankan USSI SaveInstance   → save game ke .rbxl
4. Jalankan DecompileChecker   → retry script yang gagal decompile
5. Jalankan WatermarkReplacer  → ganti branding
6. Jalankan ServerSpy          → mainkan game, capture remote calls
7. ServerSpy:CopyStubs()      → generate server scripts
8. Buka .rbxl di Roblox Studio
9. Paste rebuild scripts via Command Bar
10. Test play & iterate
```
