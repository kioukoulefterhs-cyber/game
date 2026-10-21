#!/usr/bin/env python3
"""Vendors studio-core into a Godot project's addons/studio_core folder.

Godot cannot load scripts from outside a project, so each game keeps a committed copy.
studio-core/ is the source of truth; never edit the copy directly.

    python3 tools/build-scripts/sync_core.py games/circuit-garden          # copy
    python3 tools/build-scripts/sync_core.py games/circuit-garden --check  # fail if out of date

Godot's generated .uid files in the copy are preserved.
"""
import argparse
import filecmp
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "studio-core")


def files_under(base):
    out = set()
    for dirpath, _, names in os.walk(base):
        for n in names:
            if n.endswith(".uid") or n.endswith(".import") or n == "README.md":
                continue
            out.add(os.path.relpath(os.path.join(dirpath, n), base))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("project", help="path to the Godot project (folder with project.godot)")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    dst = os.path.join(os.path.abspath(args.project), "addons", "studio_core")
    src_files = files_under(SRC)
    dst_files = files_under(dst) if os.path.isdir(dst) else set()
    stale = sorted(dst_files - src_files)
    changed = sorted(f for f in src_files if f not in dst_files or not filecmp.cmp(os.path.join(SRC, f), os.path.join(dst, f), shallow=False))
    if args.check:
        for f in changed:
            print("out of date:", f)
        for f in stale:
            print("stale:", f)
        sys.exit(1 if changed or stale else 0)
    for f in changed:
        os.makedirs(os.path.dirname(os.path.join(dst, f)), exist_ok=True)
        shutil.copy2(os.path.join(SRC, f), os.path.join(dst, f))
    for f in stale:
        os.remove(os.path.join(dst, f))
        uid = os.path.join(dst, f + ".uid")
        if os.path.exists(uid):
            os.remove(uid)
    print(f"synced {len(changed)} changed, removed {len(stale)} stale -> {dst}")


if __name__ == "__main__":
    main()
