import { isHex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { walletClient } from "./config";
import { RIN_ABI } from "./RIN_ABI";


const withdrawFees = async () => {
    try {
        const privkey = process.env.PRIVATE_KEY;
        if (!isHex(privkey)) {
            throw new Error("Invalid private key");
        }
        const account = privateKeyToAccount(privkey);
        console.log(account);

        const result = await walletClient.writeContract({
            address: '0x11Cc34a2690cc9AA58C5A727711a4F8E12B56d59',
            abi: RIN_ABI,
            functionName: 'withdrawFees',
            account,
        })

        console.log(result);
    } catch (error) {
        console.error(error);
    }
}

withdrawFees();