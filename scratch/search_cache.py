import os
import sqlite3

asset_id = b"99597458102037"

# 1. Search in TEMP http cache
temp_dir = os.path.expandvars('%TEMP%\\Roblox\\http')
if os.path.exists(temp_dir):
    print(f"Searching in {temp_dir}...")
    for root, dirs, files in os.walk(temp_dir):
        for f in files:
            path = os.path.join(root, f)
            try:
                with open(path, 'rb') as fp:
                    data = fp.read()
                    if asset_id in data:
                        print(f"[FOUND TEMP] {path} | Size: {len(data)}")
                        # Print first 200 bytes
                        print(f"Header: {data[:200]}\n")
            except Exception as e:
                pass

# 2. Search in LOCALAPPDATA rbx-storage
storage_dir = os.path.expandvars('%LOCALAPPDATA%\\Roblox\\rbx-storage')
if os.path.exists(storage_dir):
    print(f"Searching in {storage_dir}...")
    for root, dirs, files in os.walk(storage_dir):
        for f in files:
            path = os.path.join(root, f)
            try:
                with open(path, 'rb') as fp:
                    data = fp.read()
                    if asset_id in data:
                        print(f"[FOUND STORAGE FILE] {path} | Size: {len(data)}")
                        print(f"Header: {data[:200]}\n")
            except Exception as e:
                pass

# 3. Search in SQLite database
db_path = os.path.expandvars('%LOCALAPPDATA%\\Roblox\\rbx-storage.db')
if os.path.exists(db_path):
    print(f"Searching in DB {db_path}...")
    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        cur.execute("SELECT hex(id), length(content), content FROM files")
        for row in cur.fetchall():
            h_id, length, content = row
            if content and asset_id in content:
                print(f"[FOUND IN DB] ID: {h_id} | Length: {length}")
                print(f"Header: {content[:200]}\n")
    except Exception as e:
        print(f"DB Error: {e}")
