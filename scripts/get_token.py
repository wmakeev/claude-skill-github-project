#!/usr/bin/env python3
"""
Generate a short-lived GitHub App installation access token.

Configuration is read from ~/.claude/github-bot/config.json with structure:
{
  "app_id": "3172171",
  "installation_id": "118624077",
  "private_key_path": "/abs/path/to/key.pem",
  "bot_login": "mvv-claude-code-bot[bot]"
}

Usage:
    python3 get_token.py                     # uses installation_id from config
    python3 get_token.py <installation_id>   # explicit override

The script prints the token to stdout (no trailing newline) so it can be
captured into an env var:
    GH_TOKEN=$(python3 ~/.claude/github-bot/get_token.py)
"""
import json
import sys
import time
from pathlib import Path

try:
    import jwt  # PyJWT
    import requests
except ImportError as e:
    sys.stderr.write(
        f"Missing dependency: {e.name}. Install with: pip install PyJWT requests\n"
    )
    sys.exit(1)

CONFIG_PATH = Path.home() / ".claude" / "github-bot" / "config.json"


def main() -> int:
    if not CONFIG_PATH.exists():
        sys.stderr.write(f"Bot config not found: {CONFIG_PATH}\n")
        sys.stderr.write("Run scripts/setup-bot.sh from the github-project skill.\n")
        return 1

    cfg = json.loads(CONFIG_PATH.read_text())
    app_id = cfg["app_id"]
    key_path = Path(cfg["private_key_path"]).expanduser()
    installation_id = sys.argv[1] if len(sys.argv) > 1 else cfg["installation_id"]

    if not key_path.exists():
        sys.stderr.write(f"Private key not found: {key_path}\n")
        return 1

    private_key = key_path.read_text()

    # JWT for App authentication (max lifetime: 10 min).
    now = int(time.time())
    payload = {"iat": now - 60, "exp": now + 9 * 60, "iss": app_id}
    app_jwt = jwt.encode(payload, private_key, algorithm="RS256")

    # Exchange JWT for an installation token.
    url = (
        f"https://api.github.com/app/installations/{installation_id}/access_tokens"
    )
    resp = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {app_jwt}",
            "Accept": "application/vnd.github+json",
        },
        timeout=10,
    )
    if resp.status_code == 404:
        sys.stderr.write(
            f"404 from GitHub. The App is likely not installed on the target "
            f"repo, or installation_id {installation_id} is wrong.\n"
        )
        return 2
    if resp.status_code != 201:
        sys.stderr.write(f"GitHub returned {resp.status_code}: {resp.text}\n")
        return 3

    sys.stdout.write(resp.json()["token"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
