#!/usr/bin/env python3

import contextlib
import subprocess
import sys

from pathlib import Path

def config_file_path():
    return Path("~/mm.cfg").expanduser()

def flash_player_dir():
    path = None
    match sys.platform:
        case "linux":
            path = Path("~/.macromedia/Flash_Player")

        case "win32":
            path = Path("~/AppData/Roaming/Macromedia/Flash Player")

        case "darwin":
            path = Path("~/Library/Preferences/Macromedia/Flash Player")

    return path.expanduser()

def log_file_path():
    return flash_player_dir() / "Logs/flashlog.txt"

def trust_file_path():
    return flash_player_dir() / "#Security/FlashPlayerTrust/TFMSecretsLeaker.cfg"

CONFIG_CONTENTS = "TraceOutputFileEnable=1"

@contextlib.contextmanager
def cleanup_configs(config, backup_config):
    try:
        yield

    finally:
        config.unlink()

        if backup_config is not None:
            backup_config.rename(config)

def get_secrets(leaker_url):
    if sys.platform not in ("linux", "win32", "darwin"):
        raise ValueError(f"Unsupported platform: {sys.platform}")

    if "://" not in leaker_url:
        if "?" in leaker_url:
            leaker_url, parameters = leaker_url.split("?", 1)

            parameters = f"?{parameters}"
        else:
            parameters = ""

        leaker_url = Path(leaker_url).resolve()

        # Fortoresse has no policy file for cross-domain
        # loading, and so to support it we must manually
        # tell the standalone player to trust us.
        trust_file = trust_file_path()
        trust_file.parent.mkdir(parents=True, exist_ok=True)
        with trust_file.open("w") as f:
            f.write(str(leaker_url.parent))

        leaker_url = f"file://{leaker_url}{parameters}"

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
            subprocess.run(["flashplayerdebugger", leaker_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

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

def main(leaker_url):
    print(get_secrets(leaker_url), end="")

if __name__ == "__main__":
    if len(sys.argv) <= 1:
        print(f"Usage: {sys.argv[0]} <leaker SWF>")

        sys.exit(1)

    main(sys.argv[1])
