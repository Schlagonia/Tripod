# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
# change ETH_RPC_URL to another one (e.g., FTM_RPC_URL) for different chains
FORK_URL := ${ETH_RPC_URL} 

# For deployments. Add all args without a comma
# ex: 0x316..FB5 "Name" 10
constructor-args := 0xe05bc41541EB81446e765FF793BCD8D11cc373C3 0x4665D82fFA753Ec4165c5b1910CF6Eb8AB00778f 0x9067e0Ab15987668bCdA16aC7e0E8a64C9Ad9A0a 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 0xA13a9247ea42D743238089903570127DdA72fE44 0x1e9F147241dA9009417811ad5858f22Ed1F9F9fd

build  :; forge build
test   :; forge test -vv --fork-url ${FORK_URL} --etherscan-api-key ${ETHERSCAN_API_KEY}
test-gas   :; forge test -vv --gas-report --fork-url ${FORK_URL} --etherscan-api-key ${ETHERSCAN_API_KEY}
trace   :; forge test -vvv --fork-url ${FORK_URL} --etherscan-api-key ${ETHERSCAN_API_KEY}
gas   :; forge test -vv --fork-url ${FORK_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --gas-report
test-contract :; forge test -vv --fork-url ${FORK_URL} --match-contract $(contract) --etherscan-api-key ${ETHERSCAN_API_KEY}
trace-contract :; forge test -vvv --fork-url ${FORK_URL} --match-contract $(contract) --etherscan-api-key ${ETHERSCAN_API_KEY}
gas-contract :; forge test -vv --fork-url ${FORK_URL} --match-contract $(contract) --etherscan-api-key ${ETHERSCAN_API_KEY} --gas-report
deploy	:; forge create --rpc-url ${FORK_URL} --constructor-args ${constructor-args} --private-key ${PRIV_KEY} src/ProviderStrategy.sol:ProviderStrategy --etherscan-api-key ${ETHERSCAN_API_KEY} --verify
# local tests without fork
test-local  :; forge test
trace-local  :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot
