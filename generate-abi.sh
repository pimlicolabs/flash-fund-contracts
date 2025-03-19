mkdir -p abi
forge inspect src/FlashFundWithdrawalManager.sol:FlashFundWithdrawalManager abi > ./abi/FlashFundWithdrawalManager.abi.json
forge inspect src/FlashFundStakeManager.sol:FlashFundStakeManager abi > ./abi/FlashFundStakeManager.abi.json
