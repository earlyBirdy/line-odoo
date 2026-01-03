#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$root/.env" ]; then
  cp "$root/.env.example" "$root/.env"
  echo "Created .env from .env.example"
else
  echo ".env already exists"
fi

if [ ! -f "$root/backend/.env" ]; then
  cp "$root/backend/.env.example" "$root/backend/.env"
  echo "Created backend/.env from backend/.env.example"
else
  echo "backend/.env already exists"
fi

echo "Next: edit .env and backend/.env with real values (dev only)."
