#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
engine=${UE_ROOT:-/Users/Shared/Epic Games/UE_5.8}
project="$root/unreal/FifthAvenue/FifthAvenue.uproject"
build="$engine/Engine/Build/BatchFiles/Mac/Build.sh"
"$build" FifthAvenueEditor Mac Development -Project="$project" -architecture=arm64 -NoHotReload -NoUBA -MaxParallelActions=2
"$build" FifthAvenue Mac Development -Project="$project" -architecture=arm64 -NoHotReload -NoUBA -MaxParallelActions=2
"$engine/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="$project" -platform=Mac -clientconfig=Development -architecture=arm64 -skipbuildeditor -nocompileeditor -cook -stage -pak -package -nop4 -unattended -map=/Game/Manhattan/HeraldSquare -stagingdirectory="$root/dist/unreal-mac"
