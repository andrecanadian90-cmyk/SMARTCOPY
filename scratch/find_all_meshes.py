import os

cache_dirs = [
    os.path.expandvars('%TEMP%\\Roblox\\http'),
    os.path.expandvars('%LOCALAPPDATA%\\Roblox\\rbx-storage')
]

print("Scanning cache folders...")
found_meshes = []
for c_dir in cache_dirs:
    if not os.path.exists(c_dir):
        continue
    print(f"Scanning: {c_dir}")
    for root, dirs, files in os.walk(c_dir):
        for f in files:
            p = os.path.join(root, f)
            try:
                with open(p, 'rb') as fp:
                    header = fp.read(100)
                    # Check for Roblox mesh signatures
                    # Roblox meshes can be gzipped (starts with \x1f\x8b) or raw (starts with version or CSG)
                    is_mesh = False
                    if header.startswith(b"version ") or b"CSG" in header:
                        is_mesh = True
                        sig = "raw"
                    elif header.startswith(b"\x1f\x8b"):
                        # Try to read a bit inside or check if it's gzip
                        # Decompress first 100 bytes of gzip to check signature
                        import gzip
                        try:
                            fp.seek(0)
                            with gzip.open(fp, 'rb') as gfp:
                                decomp = gfp.read(50)
                                if decomp.startswith(b"version ") or b"CSG" in decomp:
                                    is_mesh = True
                                    sig = f"gzipped ({decomp[:20]})"
                        except Exception:
                            pass
                    
                    if is_mesh:
                        size = os.path.getsize(p)
                        found_meshes.append((p, size, sig))
            except Exception:
                pass

print(f"Found {len(found_meshes)} potential mesh/CSG files in cache:")
# Sort by size descending
found_meshes.sort(key=lambda x: x[1], reverse=True)
for path, size, sig in found_meshes[:20]:
    print(f"- Size: {size:<7} bytes | Sig: {sig:<25} | Path: {path}")
