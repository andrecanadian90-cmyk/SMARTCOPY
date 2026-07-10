-- ============================================================
-- SMARTCOPY Rebuild — Kelas Malam
-- HOW TO INSTALL SERVER SCRIPTS
--
-- Step-by-step guide to add these scripts to your game
-- ============================================================

--[[

INSTALLATION GUIDE:
==================

1. Buka file "place 99498215431251 Kelas Malam.rbxlx" di Roblox Studio

2. Di Explorer panel, klik kanan "ServerScriptService"
   → Insert Object → Script

3. Untuk SETIAP file .server.lua, buat Script baru:

   ServerScriptService/
   ├── MainServer              ← paste isi MainServer.server.lua
   ├── ByteNetServer           ← paste isi ByteNetServer.server.lua
   ├── DonationBoardServer     ← paste isi DonationBoardServer.server.lua
   ├── EffectsServer           ← paste isi EffectsServer.server.lua
   └── ServerListServer        ← paste isi ServerListServer.server.lua

4. Buat folder "Tools" di ServerStorage:
   ServerStorage/
   └── Tools/
       └── Concave             ← pindahkan Tool "Concave" dari 
                                  Workspace/[player] ke sini

5. Cek ReplicatedStorage/Packages/ByteNet
   → Ini ModuleScript yang sudah ter-decompile
   → Baca packet definitions di situ
   → Update ByteNetServer.server.lua sesuai packet definitions

6. Update admin list di EffectsServer.server.lua
   → Ganti nama-nama admin dengan nama kamu / admin kamu

7. Test: File → Publish to Roblox → Start Server (2 players)

NOTES:
======
- Script "MainControl" asli ditandai "[FilteringEnabled] Server Scripts 
  are IMPOSSIBLE to save" — ini normal, semua server script memang 
  ga bisa di-save
  
- Script "CO2GonServer" juga ditandai IMPOSSIBLE — kita sudah 
  rebuild logicnya di EffectsServer.server.lua

- ByteNet packet definitions ada di ReplicatedStorage, sudah 
  ter-decompile — baca itu untuk tahu exact data structure

- Saweria integration butuh API key kamu sendiri, atau pakai 
  static data di DonationBoardServer.server.lua

]]
