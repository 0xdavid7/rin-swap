import { http, createPublicClient, createWalletClient, defineChain } from 'viem'
import { mainnet, sepolia } from 'viem/chains'

export const walletClient = createWalletClient({
    chain: sepolia,
    transport: http()
})

export const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
})