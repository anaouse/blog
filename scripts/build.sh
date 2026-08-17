#!/usr/bin/env bash
# 本地编译检查：frontend（pnpm build，含 TS 类型检查）+ backend（go build）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Building frontend"
(cd frontend && pnpm build)

echo "==> Building backend"
(cd backend && go build ./...)

echo "==> Build OK"
