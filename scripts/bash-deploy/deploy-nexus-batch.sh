#!/usr/bin/env bash

# Load centralized network configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/networks.sh"

printMan() {
    printf "Usage: $0 <Environment: local|mainnet|testnet> [--preset <main|demo|staging>] [chain1 chain2 ...]\n"
    printf "Examples:\n"
    printf "  $0 mainnet --preset main\n"
    printf "  $0 testnet demo-ethereum demo-op demo-base\n"
    printf "  $0 mainnet --preset staging\n"
}

if [ $# -lt 1 ]; then
    printMan
    exit 1
fi

ENVIRONMENT=$1
shift

PRESET=""
CHAINS=()

while (( "$#" )); do
    case "$1" in
        --preset)
            shift
            PRESET=$1
            ;;
        *)
            CHAINS+=("$1")
            ;;
    esac
    shift
done

if [ -n "$PRESET" ]; then
    PRESET_CHAINS=$(get_preset_chains "$PRESET")
    if [ $? -ne 0 ]; then
        printf "Unknown preset: %s\n" "$PRESET"
        exit 1
    fi
    read -ra CHAINS <<< "$PRESET_CHAINS"
fi

if [ ${#CHAINS[@]} -eq 0 ]; then
    printf "No chains provided.\n"
    printMan
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

for CHAIN in "${CHAINS[@]}"; do
    printf "\n===============================================\n"
    printf "Deploying to %s (%s)\n" "$CHAIN" "$ENVIRONMENT"
    printf "===============================================\n\n"
    ( cd "$SCRIPT_DIR" && bash deploy-nexus.sh "$ENVIRONMENT" "$CHAIN" ) || {
        printf "Deployment failed for %s (%s)\n" "$CHAIN" "$ENVIRONMENT"
        exit 1
    }
done

printf "\nAll deployments completed successfully.\n"


