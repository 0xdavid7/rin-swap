#!/bin/bash

env_file=".env"
if [ -f "$env_file" ]; then
    export $(cat "$env_file" | grep -v '#' | sed 's/\r$//' | xargs)
else
    echo "${env_file} file not found"
    exit 1
fi

# Configuration
ETHERSCAN_API_KEY=$API_KEY_ETHERSCAN
CHAIN_ID="mainnet"         # Default to Ethereum mainnet
COMPILER_VERSION="v0.8.28" # Adjust to your compiler version
OPTIMIZER_RUNS="200"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

# Function to get verification API URL and explorer name
get_chain_config() {
    case $1 in
    base)
        EXPLORER_API="https://api.etherscan.io/v2/api?chainid=8453"
        EXPLORER_NAME="Basescan"
        EXPLORER_API_KEY=$ETHERSCAN_API_KEY
        ROUTER="0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24" # BaseSwap Router
        WETH="0x4200000000000000000000000000000000000006"   # WETH
        FEE_RATE="100"                                      # 1%
        # ABI encode the constructor arguments
        CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,uint256)" "$ROUTER" "$WETH" "$FEE_RATE")
        ;;
    *)
        echo -e "${RED}Error: Unsupported chain ID: $1${NC}"
        exit 1
        ;;
    esac
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --address CONTRACT_ADDRESS     Contract address to verify"
    echo "  --name CONTRACT_NAME          Contract name"
    echo "  --args CONSTRUCTOR_ARGS       Constructor arguments (optional)"
    echo "  --chain CHAIN_ID             Chain ID (default: 1)"
    echo "  --compiler VERSION           Compiler version (default: v0.8.19)"
    echo "  --runs OPTIMIZER_RUNS        Optimizer runs (default: 200)"
    echo "  --api-key ETHERSCAN_API_KEY  Etherscan API key"
    echo "  --help                       Display this help message"
    echo ""
    echo "Supported Chain IDs:"
    echo "  1: Ethereum Mainnet"
    echo "  5: Goerli Testnet"
    echo "  11155111: Sepolia Testnet"
    echo "  137: Polygon Mainnet"
    echo "  56: BSC Mainnet"
    echo "  42161: Arbitrum One"
    echo "  10: Optimism"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --address)
        CONTRACT_ADDRESS="$2"
        shift 2
        ;;
    --name)
        CONTRACT_NAME="$2"
        shift 2
        ;;
    --args)
        CONSTRUCTOR_ARGS="$2"
        shift 2
        ;;
    --chain)
        CHAIN_ID="$2"
        shift 2
        ;;
    --compiler)
        COMPILER_VERSION="$2"
        shift 2
        ;;
    --runs)
        OPTIMIZER_RUNS="$2"
        shift 2
        ;;
    --api-key)
        ETHERSCAN_API_KEY="$2"
        shift 2
        ;;
    --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

# Validate required parameters
if [ -z "$CONTRACT_ADDRESS" ] || [ -z "$CONTRACT_NAME" ]; then
    echo -e "${RED}Error: Contract address and name are required${NC}"
    usage
    exit 1
fi

# Get chain configuration
get_chain_config $CHAIN_ID

# Display verification parameters
echo -e "${YELLOW}Verification Parameters:${NC}"
echo -e "Chain: $EXPLORER_NAME (ID: $CHAIN_ID)"
echo -e "Contract Address: ${GREEN}$CONTRACT_ADDRESS${NC}"
echo -e "Contract Name: ${GREEN}$CONTRACT_NAME${NC}"
echo -e "Compiler Version: $COMPILER_VERSION"
echo -e "Optimizer Runs: $OPTIMIZER_RUNS"
if [ ! -z "$CONSTRUCTOR_ARGS" ]; then
    echo -e "Constructor Arguments: $CONSTRUCTOR_ARGS"
fi

# Confirm before proceeding
read -p "Proceed with verification? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Verification cancelled${NC}"
    exit 1
fi

# Build verification command
VERIFY_CMD="forge verify-contract"
VERIFY_CMD+=" --chain-id $CHAIN_ID"
VERIFY_CMD+=" --compiler-version $COMPILER_VERSION"
VERIFY_CMD+=" --num-of-optimizations $OPTIMIZER_RUNS"
VERIFY_CMD+=" --watch"
VERIFY_CMD+=" $CONTRACT_ADDRESS"
VERIFY_CMD+=" $CONTRACT_NAME"

# Add constructor args if provided
if [ ! -z "$CONSTRUCTOR_ARGS" ]; then
    VERIFY_CMD+=" --constructor-args $CONSTRUCTOR_ARGS"
fi

echo "Executing: $VERIFY_CMD"

# Set environment variables
export EXPLORER_API_KEY

# Execute verification
echo -e "\n${YELLOW}Executing verification...${NC}"
if eval $VERIFY_CMD; then
    echo -e "\n${GREEN}Verification submitted successfully!${NC}"
    echo -e "You can check the status on $EXPLORER_NAME"
else
    echo -e "\n${RED}Verification failed!${NC}"
    exit 1
fi
