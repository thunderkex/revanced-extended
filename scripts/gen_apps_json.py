#!/usr/bin/env python3
import json, sys
try:
    import yaml
except ImportError:
    import subprocess, sys as _sys
    subprocess.check_call([_sys.executable, "-m", "pip", "install", "pyyaml", "-q"])
    import yaml

with open("config/apps.yaml") as f:
    data = yaml.safe_load(f)

apps = []
for app_id, cfg in data["apps"].items():
    apps.append({
        "id": app_id,
        "enabled": cfg.get("enabled", False),
        "package": cfg.get("package", ""),
        "patch_source": cfg.get("patch_source", ""),
        "architectures": cfg.get("architectures", []),
        "mode": cfg.get("mode", "patch"),
        "patches": cfg.get("patches", []),
        "dependencies": cfg.get("dependencies", []),
        "module": cfg.get("module", {}),
    })

import os
os.makedirs("docs", exist_ok=True)
with open("docs/apps.json", "w") as f:
    json.dump({"apps": apps}, f, indent=2)

print(f"Generated docs/apps.json with {len(apps)} apps.")
