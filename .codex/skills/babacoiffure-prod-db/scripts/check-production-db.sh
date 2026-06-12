#!/usr/bin/env bash
set -euo pipefail

for name in BABACOIFFURE_DB_USERNAME BABACOIFFURE_DB_PASSWORD; do
    value="${!name-}"
    if [[ -n "${value}" ]]; then
        printf '%s=set len=%s\n' "${name}" "${#value}"
    else
        printf '%s=missing\n' "${name}"
    fi
done

if ! command -v mongosh >/dev/null 2>&1; then
    echo "mongosh=missing"
    exit 1
fi

printf 'mongosh=%s\n' "$(command -v mongosh)"

uri="$(
    python3 - <<'PY'
import os
import urllib.parse

username = os.environ.get("BABACOIFFURE_DB_USERNAME")
password = os.environ.get("BABACOIFFURE_DB_PASSWORD")

if not username or not password:
    raise SystemExit("missing credentials")

encoded_username = urllib.parse.quote(username)
encoded_password = urllib.parse.quote(password)

print(
    "mongodb+srv://"
    f"{encoded_username}:{encoded_password}"
    "@cluster0.k2k9ux7.mongodb.net/production"
    "?retryWrites=true&w=majority&appName=Cluster0"
)
PY
)"

mongosh "${uri}" --quiet --eval '
const collections = db.getCollectionNames().slice(0, 20).join(",");
print(`ping=${db.runCommand({ ping: 1 }).ok}`);
print(`db=${db.getName()}`);
print(`collections=${collections}`);
'
