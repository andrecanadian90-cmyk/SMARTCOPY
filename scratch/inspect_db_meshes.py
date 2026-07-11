import os
import sqlite3
import gzip

db_path = os.path.expandvars('%LOCALAPPDATA%\\Roblox\\rbx-storage.db')
if not os.path.exists(db_path):
    print("Database not found!")
    exit()

conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("SELECT hex(id), content FROM files")

print("Scanning SQLite database for cached meshes...")
found = 0
for row in cur.fetchall():
    h_id, content = row
    if not content:
        continue
    
    # Try decompressing if gzipped
    data = content
    if content.startswith(b"\x1f\x8b"):
        try:
            data = gzip.decompress(content)
        except Exception:
            pass
            
    header = data[:150]
    if header.startswith(b"version ") or b"CSG" in header or header.startswith(b"RBXH"):
        found += 1
        print(f"Match {found}: ID = {h_id} | Size = {len(data)}")
        print(f"Header: {header[:120]}")
        print("-" * 50)
