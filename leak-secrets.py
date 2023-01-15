#!/usr/bin/env python3

import contextlib
import subprocess
import sys

from pathlib import Path

def config_file_path():
    return Path("~/mm.cfg").expanduser()

def log_file_path():
    path = None
    match sys.platform:
        case "linux":
            path = Path("~/.macromedia/Flash_Player/Logs/flashlog.txt")

        case "win32":
            path = Path("~/AppData/Roaming/Macromedia/Flash Player/Logs/flashlog.txt")

        case "darwin":
            path = Path("~/Library/Preferences/Macromedia/Flash Player/Logs/flashlog.txt")

    return path.expanduser()

CONFIG_CONTENTS = "TraceOutputFileEnable=1"

@contextlib.contextmanager
def cleanup_configs(config, backup_config):
    try:
        yield

    finally:
        config.unlink()

        if backup_config is not None:
            backup_config.rename(config)

def get_secrets(leaker_path):
    if sys.platform not in ("linux", "win32", "darwin"):
        raise ValueError(f"Unsupported platform: {sys.platform}")

    config = config_file_path()

    backup_config = None
    if config.exists():
        backup_config = Path("mm.cfg.bak")
        if backup_config.exists():
            raise ValueError(f"Backup config file already exists: {backup_config}")

        config.rename(backup_config)

    with config.open("w") as f:
        f.write(CONFIG_CONTENTS)

    with cleanup_configs(config, backup_config):
        try:
            subprocess.run(["flashplayerdebugger", leaker_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        except FileNotFoundError:
            print(
                "You must have the debug flash standalone projector installed "
                "and accessible through the 'flashplayerdebugger' command."

                "\n\n"
            )

            raise

    log = log_file_path()
    with log.open() as f:
        return f.read()

def main(leaker_path):
    print(get_secrets(leaker_path), end="")

if __name__ == "__main__":
    if len(sys.argv) <= 1:
        print(f"Usage: {sys.argv[0]} <leaker SWF>")

        sys.exit(1)

    main(sys.argv[1])