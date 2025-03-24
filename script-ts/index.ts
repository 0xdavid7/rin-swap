import { defineChain, formatEther, isHex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { RIN_ABI } from "./RIN_ABI";
import { publicClient, walletClient } from "./config";


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

const watchContractBalance = async () => {
    try {
        const result = await publicClient.getBalance({
            address: "0x11Cc34a2690cc9AA58C5A727711a4F8E12B56d59"
        })
        console.log(formatEther(result));
    } catch (error) {
        console.error(error);
    }
}

const main = async () => {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log("No command provided");
        return;
    }

    const command = args[0];
    if (command === "withdrawFees") {
        await withdrawFees();
    } else if (command === "watchContractBalance") {
        await watchContractBalance();
    } else {
        console.log("Invalid command");
    }
}

main();
