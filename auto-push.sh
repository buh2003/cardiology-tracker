#!/bin/bash
# Auto-push cardiology tracker to GitHub Pages via GitHub API
# No git required — uploads file directly over HTTPS
# Runs every Monday at 8:30 AM via LaunchAgent (after Cowork task at 8:09 AM)

FILE="/Users/benjaminhoffman/Documents/Claude/Research/Award Funding Tracker/cardiology-tracker/Cardiology_Fellowship_Funding_Tracker.html"
TOKEN="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"
OWNER="buh2003"
REPO="cardiology-tracker"
REMOTE_PATH="Cardiology_Fellowship_Funding_Tracker.html"
LOG="/tmp/cardiology-tracker-push.log"

echo "$(date): Starting push..." >> "$LOG"

# Get current file SHA from GitHub (required for updates)
SHA=$(curl -s \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$OWNER/$REPO/contents/$REMOTE_PATH" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" 2>>"$LOG")

if [ -z "$SHA" ]; then
  echo "$(date): ERROR — could not retrieve file SHA from GitHub." >> "$LOG"
  exit 1
fi

echo "$(date): Got SHA: $SHA" >> "$LOG"

# Build and push payload via Python (handles large files + escaping safely)
python3 - "$FILE" "$SHA" "$TOKEN" "$OWNER" "$REPO" "$REMOTE_PATH" "$LOG" << 'PYEOF'
import sys, json, base64, urllib.request, urllib.error
from datetime import date

file_path, sha, token, owner, repo, remote_path, log = sys.argv[1:]

with open(file_path, 'rb') as f:
    content = base64.b64encode(f.read()).decode('ascii')

payload = json.dumps({
    "message": f"Weekly tracker auto-sync — {date.today().isoformat()}",
    "content": content,
    "sha": sha
}).encode('utf-8')

req = urllib.request.Request(
    f"https://api.github.com/repos/{owner}/{repo}/contents/{remote_path}",
    data=payload,
    method="PUT",
    headers={
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json"
    }
)

try:
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
        commit_sha = result['commit']['sha']
        with open(log, 'a') as lf:
            lf.write(f"Push successful — commit {commit_sha}\n")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    with open(log, 'a') as lf:
        lf.write(f"ERROR {e.code}: {body}\n")
    sys.exit(1)
PYEOF
