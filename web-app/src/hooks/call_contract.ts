import {
  useContract,
  useStarknetCall,
  useStarknetInvoke,
} from "@starknet-react/core";
import { toHex } from "starknet/utils/number";
import { RegistryRecord } from "../interfaces/record";
import { networkId } from "../services/wallet.service";
import CallContractAbi from "../abi/CallOption.json";
import AccountContractAbi from "../abi/AccountContract.json";
import { Abi } from "starknet";
import { getCallOptionContractAddress } from "../services/address.service";

export interface RecordHookT {
  record: RegistryRecord | undefined;
  loading: boolean;
  error: string;
}

export const useCallContract = () => {
  const network = networkId();
  const callContractAddress = getCallOptionContractAddress(network);
  return useContract({
    abi: CallContractAbi as Abi,
    address: callContractAddress,
  });
};

export const useAccountContract = (accountAddress: string) => {
  return useContract({
    abi: AccountContractAbi as Abi,
    address: accountAddress,
  });
};

export const getOptionId = () => {
  const { contract } = useCallContract();
  const { data, loading, error } = useStarknetInvoke<Array<string | string[]>>({
    contract,
    method: "generate_call_option_id",
  });
  return { data, loading, error };
};

export const submitCallOptionBuy = (
  expirationTimestamp: string,
  fee: string,
  size: string,
  strikePrice: string,
  currencyAddress: string,
  oracleKey: string
): RecordHookT => {
  const { contract } = useCallContract();
  const {
    data: optionId,
    loading: optionIdLoading,
    error: optionIdError,
  } = getOptionId();
  if (optionIdLoading) {
    console.log("Loading");
  } else if (optionIdError) {
    console.error(optionIdError);
  }
  console.log(`Submitting with option id ${optionId}`);
  const args = [
    optionId,
    expirationTimestamp,
    fee,
    size,
    strikePrice,
    currencyAddress,
    oracleKey,
  ];
  const { data, loading, error } = useStarknetCall({
    contract,
    method: "register_call_option",
    args,
  });
  let record: RegistryRecord | undefined = undefined;
  if (data !== undefined) {
    record = {
      ownerAddress: toHex(data[0].owner_addr),
      resolverAddress: toHex(data[0].resolver_addr),
      apexNamehash: toHex(data[0].apex_namehash),
    };
  }
  return { record, loading, error };
};
