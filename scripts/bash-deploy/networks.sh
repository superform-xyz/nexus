#!/usr/bin/env bash

# Ensure we're running with bash 4.0+ for associative arrays
if [ -z "${BASH_VERSION}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: This script requires bash 4.0 or higher for associative arrays"
    echo "Current shell: ${SHELL:-unknown}"
    echo "Bash version: ${BASH_VERSION:-not bash}"
    echo "Please run with: bash $0"
    exit 1
fi

# Centralized network configuration for Nexus deployment scripts
# Used by: deploy-nexus.sh, deploy-nexus-batch.sh, sync_nexus_to_s3.sh

# Chain ID to chain name mappings (matches S3 format with proper case)
declare -A CHAIN_NAMES=(
    ["1"]="Ethereum"
    ["10"]="Optimism" 
    ["8453"]="Base"
    ["137"]="Polygon"
    ["42161"]="Arbitrum"
    ["43114"]="Avalanche"
    ["56"]="BSC"
    ["98866"]="Plume"
)

# Get chain name from chain ID
get_chain_name() {
    local chain_id=$1
    echo "${CHAIN_NAMES[$chain_id]}"
}

# Get all supported chain IDs
get_all_chain_ids() {
    echo "${!CHAIN_NAMES[@]}"
}

# Environment-based S3 bucket configuration
get_s3_bucket_for_environment() {
    local environment=$1
    case "$environment" in
        "main"|"demo")
            echo "vnet-state"
            ;;
        "staging")
            echo "superform-deployment-state"
            ;;
        "production")
            echo "ERROR: Production environment does not support S3 sync" >&2
            echo "ERROR: Production Nexus deployments can be done via deploy-nexus.sh, but S3 sync is manual" >&2
            return 1
            ;;
        *)
            echo "ERROR: Invalid environment: $environment" >&2
            echo "ERROR: Supported environments for S3 sync: main, demo, staging" >&2
            return 1
            ;;
    esac
}

# Determine environment from chain name prefix
get_environment_from_chain_name() {
    local chain_name_input=$1
    
    if [[ $chain_name_input == main-* ]]; then
        echo "main"
    elif [[ $chain_name_input == demo-* ]]; then
        echo "demo"
    elif [[ $chain_name_input == staging-* ]]; then
        echo "staging"
    else
        echo "production"
    fi
}

# Default validator configuration per environment
get_default_validator() {
    local chain_name=$1
    local prev_default_validator="0xDF1e60d1Dd1bEf8E37ECac132c04a4D7D41A6ca6"
    
    if [[ $chain_name == demo-* ]]; then
        echo "0x4795Bd019eb8D19b2696d22c351eECA9E00bb8F3"
    elif [[ $chain_name == main-* ]]; then
        echo "0x37Fe31C1CA7E1eF4b7aD418b77F01318a977716e"
    elif [[ $chain_name == staging-* ]]; then
        echo "0x229822FAd0DB012BF2863dD6c7739703fc4b8260"
    else
        echo "$prev_default_validator"
    fi
}

# RPC URL configuration (OnePassword integration)
get_rpc_url() {
    local chain_name=$1
    
    case "$chain_name" in
        # Main environment chains
        "main-ethereum")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/MAIN_ETHEREUM_VNET/credential
            ;;
        "main-op")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/MAIN_OPTIMISM_VNET/credential
            ;;
        "main-base")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/MAIN_BASE_VNET/credential
            ;;
        # Demo environment chains
        "demo-ethereum")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/DEMO_ETHEREUM_VNET/credential
            ;;
        "demo-op")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/DEMO_OPTIMISM_VNET/credential
            ;;
        "demo-base")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/DEMO_BASE_VNET/credential
            ;;
        # Staging environment chains
        "staging-bsc")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential
            ;;
        "staging-ethereum")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential
            ;;
        "staging-arbitrum")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential
            ;;
        "staging-base")
            op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential
            ;;
        *)
            echo "ERROR: Unsupported chain: $chain_name" >&2
            echo "Supported chains: main-ethereum, main-op, main-base, demo-ethereum, demo-op, demo-base, staging-bsc, staging-ethereum, staging-arbitrum, staging-base" >&2
            return 1
            ;;
    esac
}

# Chain presets for batch deployment
get_preset_chains() {
    local preset=$1
    
    case "$preset" in
        "main")
            echo "main-ethereum main-op main-base"
            ;;
        "demo")
            echo "demo-ethereum demo-op demo-base"
            ;;
        "staging")
            echo "staging-bsc staging-ethereum staging-arbitrum staging-base"
            ;;
        *)
            echo "ERROR: Unknown preset: $preset" >&2
            return 1
            ;;
    esac
}

# Validate environment
validate_environment() {
    local environment=$1
    
    case "$environment" in
        "main"|"demo"|"staging"|"production")
            return 0
            ;;
        *)
            echo "ERROR: Invalid environment: $environment" >&2
            echo "Environment must be one of: main, demo, staging, production" >&2
            return 1
            ;;
    esac
}

# Validate chain name format
validate_chain_name() {
    local chain_name=$1
    
    # Check if it's a valid chain name format
    if [[ $chain_name =~ ^(main|demo|staging)-[a-z]+$ ]] || [[ $chain_name =~ ^[a-z]+$ ]]; then
        return 0
    else
        echo "ERROR: Invalid chain name format: $chain_name" >&2
        return 1
    fi
}

# Get chain ID from environment chain name (reverse lookup)
get_chain_id_from_env_chain_name() {
    local env_chain_name=$1
    local base_chain_name
    
    # Extract base chain name (remove environment prefix)
    if [[ $env_chain_name == *-* ]]; then
        base_chain_name=${env_chain_name#*-}
    else
        base_chain_name=$env_chain_name
    fi
    
    # Handle special mappings
    case "$base_chain_name" in
        "op") base_chain_name="optimism" ;;
    esac
    
    # Find chain ID by base name
    for chain_id in "${!CHAIN_NAMES[@]}"; do
        if [[ "${CHAIN_NAMES[$chain_id]}" == "$base_chain_name" ]]; then
            echo "$chain_id"
            return 0
        fi
    done
    
    echo "ERROR: Could not find chain ID for: $env_chain_name" >&2
    return 1
}

# Print network configuration summary
print_network_summary() {
    echo "=== SUPPORTED NETWORKS ==="
    echo "Chain ID -> Chain Name:"
    for chain_id in $(printf '%s\n' "${!CHAIN_NAMES[@]}" | sort -n); do
        printf "  %6s -> %s\n" "$chain_id" "${CHAIN_NAMES[$chain_id]}"
    done
    echo ""
    echo "Environments: main, demo, staging, production"
    echo "S3 Sync Support:"
    echo "  main/demo  -> vnet-state"
    echo "  staging    -> superform-deployment-state"
    echo "  production -> S3 sync not supported (manual process)"
    echo ""
    echo "Note: Production Nexus deployments can be done via deploy-nexus.sh,"
    echo "      but S3 sync must be handled manually for production"
    echo ""
    echo "Available Presets:"
    echo "  main    -> main-ethereum main-op main-base"
    echo "  demo    -> demo-ethereum demo-op demo-base"  
    echo "  staging -> staging-bsc staging-ethereum staging-arbitrum staging-base"
    echo "=========================="
}
