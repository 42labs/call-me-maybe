import React, { FormEvent, useState } from "react";
import Button from "../components/Button";
import { StyledInternalLink } from "../components/StyledLink";
import { WalletProps } from "./_app";
import Wallet from "../components/Wallet";
import classNames from "classnames";

export const StyledTextInput = (
  props: React.DetailedHTMLProps<
    React.InputHTMLAttributes<HTMLInputElement>,
    HTMLInputElement
  >
) => (
  <input
    type="text"
    {...props}
    className={classNames(
      props.className,
      "placeholder-purple-500 py-2 px-4 my-4 rounded-lg text-lg w-5/12 max-w-4xl min-w-fit"
    )}
  ></input>
);

const CallOptionInputForm = ({
  setBuyTx,
}: {
  setBuyTx: (tx: string) => void;
}) => {
  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const expirationTimestamp = event.target[0].value;
    const fee = event.target[1].value;
    const size = event.target[2].value;
    const strikePrice = event.target[3].value;
    const currencyAddress =
      "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"; // of ETH on Starknet Goerli
    const oracleKey = "0x6574682F757364"; // str_to_felt("eth/usd") as hex
    console.log(
      expirationTimestamp,
      fee,
      size,
      strikePrice,
      currencyAddress,
      oracleKey
    );
    console.log("SUBMIT");
  };
  const textInputClassName = "block m-auto";
  return (
    <div className="flex my-2">
      <form onSubmit={onSubmit} className="m-auto w-full text-center">
        <StyledTextInput
          placeholder="Enter expiration timestamp"
          className={textInputClassName}
        ></StyledTextInput>
        <StyledTextInput
          placeholder="Enter fee (in ETH)"
          className={textInputClassName}
        ></StyledTextInput>
        <StyledTextInput
          placeholder="Enter call size (in number of ETH)"
          className={textInputClassName}
        ></StyledTextInput>
        <StyledTextInput
          placeholder="Enter strike price (in ETH/USD)"
          className={textInputClassName}
        ></StyledTextInput>
        <input
          type="submit"
          value="Submit Call Option Buy"
          className="mx-8 my-4 inline py-4 px-6 border border-solid border-violet-900 rounded-lg text-lg float hover:bg-violet-900 hover:text-white hover:cursor-pointer"
        />
      </form>
    </div>
  );
};

const RegisterPage = ({ walletProps }: { walletProps: WalletProps }) => {
  const [buyTx, setBuyTx] = useState<string>();

  return (
    <div>
      <div className="my-4">
        {buyTx ? (
          <div>Submitted transaction to buy options</div>
        ) : !walletProps.isConnected ? (
          <div className="mx-auto text-center">
            <div className="block mx-auto my-2 text-xl">
              Connect your wallet in order to buy a call option.
            </div>
            <Button onClick={walletProps.handleConnectClick}>
              Connect Wallet
            </Button>
          </div>
        ) : (
          <></>
        )}
        <CallOptionInputForm setBuyTx={(tx: string) => setBuyTx(tx)} />
        <Wallet {...walletProps} />
        <div className="mx-auto text-center mb-12 h-full">
          <div className="mt-6">
            You can also sell call options{" "}
            <StyledInternalLink href="/sell">here</StyledInternalLink>.
          </div>
        </div>
      </div>
    </div>
  );
};

export default RegisterPage;
