import urllib.request
import struct
import gzip
import io

# Download a public mesh for testing
url = "https://assetdelivery.roblox.com/v1/asset/?id=11368204072"
print(f"Downloading test mesh from {url}...")
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Roblox/WinInet'})
    with urllib.request.urlopen(req) as response:
        compressed_data = response.read()
    print(f"Downloaded {len(compressed_data)} bytes.")
except Exception as e:
    print(f"Download failed: {e}")
    compressed_data = None

if compressed_data:
    # Check if gzipped
    if compressed_data.startswith(b"\x1f\x8b"):
        print("Decompressing gzip content...")
        try:
            data = gzip.decompress(compressed_data)
            print(f"Decompressed size: {len(data)} bytes.")
        except Exception as e:
            print(f"Gzip decompress failed: {e}")
            data = compressed_data
    else:
        data = compressed_data

    # Save raw mesh
    with open("test_mesh.mesh", "wb") as f:
        f.write(data)
    
    # Try parsing
    header = data[:12]
    print(f"Header: {header}")
    
    if header.startswith(b"version 2.00"):
        print("Parsing version 2.00 binary mesh...")
        # Header is 12 bytes for version string + 12 bytes of header data
        header_size, num_meshes, num_submeshes, num_vertices, num_indices = struct.unpack("<HBBII", data[12:24])
        print(f"header_size: {header_size}, num_vertices: {num_vertices}, num_indices: {num_indices}")
        
        # Vertex size in v2.00 is 36 or 40 bytes depending on layout (usually 36 bytes: 3*float pos, 3*float norm, 2*float uv, 1*float tangent/color)
        # Let's read vertices
        vert_start = 12 + header_size
        vert_size = 40 # 3 pos, 3 norm, 2 uv, 4 tangent
        
        # Test vertex reading
        vertices = []
        for i in range(num_vertices):
            offset = vert_start + i * vert_size
            if offset + 12 <= len(data):
                x, y, z = struct.unpack("<fff", data[offset:offset+12])
                vertices.append((x, y, z))
        
        print(f"Successfully read {len(vertices)} vertices. First few: {vertices[:5]}")
        
        # Indices follow vertices
        indices_start = vert_start + num_vertices * vert_size
        indices = []
        for i in range(num_indices):
            offset = indices_start + i * 4
            if offset + 4 <= len(data):
                idx = struct.unpack("<I", data[offset:offset+4])[0]
                indices.append(idx)
        print(f"Successfully read {len(indices)} indices. First few: {indices[:6]}")
