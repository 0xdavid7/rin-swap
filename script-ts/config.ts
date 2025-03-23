import { createWalletClient, custom, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'

export const walletClient = createWalletClient({
    chain: sepolia,
    transport: http()
})
