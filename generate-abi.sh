mkdir -p abi
forge inspect src/MagicSpendWithdrawalManager.sol:MagicSpendWithdrawalManager abi > ./abi/MagicSpendWithdrawalManager.abi.json
forge inspect src/MagicSpendStakeManager.sol:MagicSpendStakeManager abi > ./abi/MagicSpendStakeManager.abi.json
