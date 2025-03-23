#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

env_file=".env"
if [ -f "$env_file" ]; then
    export $(cat "$env_file" | grep -v '#' | sed 's/\r$//' | xargs)
else
    echo "${env_file} file not found"
    exit 1
fi

# Function to check required environment variables
check_env() {
    local missing=0

    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: PRIVATE_KEY is not set${NC}"
        missing=1
    fi

    if [ -z "$API_KEY_ETHERSCAN" ]; then
        echo -e "${RED}Error: API_KEY_ETHERSCAN is not set${NC}"
        missing=1
    fi

    if [ -z "$ALCHEMY_API_KEY" ]; then
        echo -e "${RED}Error: ALCHEMY_API_KEY is not set${NC}"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

# Function to set network-specific configurations
set_network_config() {
    case "$NETWORK" in
    "mainnet")
        RPC_URL="https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
        VERIFIER_URL="https://api.etherscan.io/v2/api?chainid=1"
        ROUTER="0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D" # Uniswap V2 Router
        WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"   # WETH
        ;;
    "base")
        RPC_URL="base-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
        VERIFIER_URL="https://api.etherscan.io/v2/api?chainid=8453"
        ROUTER="0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24" # BaseSwap Router
        WETH="0x4200000000000000000000000000000000000006"   # WETH
        ;;
    "sepolia")
        RPC_URL="https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_API_KEY"
        VERIFIER_URL="https://api.etherscan.io/v2/api?chainid=11155111"
        ROUTER="0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3" # Uniswap V2 Router
        WETH="0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14"   # WETH
        ;;
    "fork")
        RPC_URL="http://14.253.139.39:8545"
        VERIFIER_URL="https://api.etherscan.io/v2/api?chainid=1"
        ROUTER="0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D" # Uniswap V2 Router
        WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"   # WETH
        ;;
    *)
        echo -e "${RED}Error: Unsupported network '$NETWORK'${NC}"
        echo "Supported networks: mainnet, base, bnb, sepolia"
        exit 1
        ;;
    esac
}

# Function to display information
info() {
    echo -e "\n${GREEN}════════════════════════════════════ DEPLOYMENT CONFIG ════════════════════════════════════${NC}"
    echo -e "${BLUE}NETWORK:${NC}            $NETWORK"
    echo -e "${BLUE}RPC_URL:${NC}            $RPC_URL"
    echo -e "${BLUE}VERIFIER_URL:${NC}       $VERIFIER_URL"
    echo -e "${BLUE}API_KEY_ETHERSCAN:${NC}    $API_KEY_ETHERSCAN"
    echo -e "${BLUE}ROUTER:${NC}             $ROUTER"
    echo -e "${BLUE}WETH:${NC}               $WETH"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════════════${NC}\n"
}

# Function to deploy the contract
deploy() {
    echo -e "${GREEN}Deploying RinSwap contract...${NC}"

    # Build Forge script command
    FORGE_CMD="forge script script/Deploy.s.sol \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --sig 'run(address,address)' $ROUTER $WETH"

    # if network is fork, not verify
    if [ "$NETWORK" != "fork" ]; then
        FORGE_CMD="$FORGE_CMD --etherscan-api-key $API_KEY_ETHERSCAN"
        FORGE_CMD="$FORGE_CMD --verify $VERIFIER_URL"
    fi

    # Execute the command
    echo "Executing: $FORGE_CMD"
    eval $FORGE_CMD

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Deployment successful!${NC}"
    else
        echo -e "${RED}Deployment failed!${NC}"
        exit 1
    fi
}

# Main script execution
main() {
    # Parse arguments
    NETWORK=${1:-"mainnet"}
    FEE_BPS=${2:-100} # Default 1%

    # Check required environment variables
    check_env

    # Set network configuration
    set_network_config

    # Display deployment information
    info

    # Confirm deployment
    read -p "Continue with deployment? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo "Deployment cancelled"
        exit 0
    fi

    # Deploy the contract
    deploy
}

# Execute main function
main "$@"
