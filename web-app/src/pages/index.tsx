import React from "react";
import ActionButton from "../components/ActionButton";
import { StyledExternalLink } from "../components/StyledLink";

const IndexPage = () => (
  <div>
    <div className="flex">
      <div className="text-center px-4 py-0 mx-auto mb-8 text-lg w-8/12">
        Call options built on top of Pontis, the Starknet oracle. Learn more
        about Pontis{" "}
        <StyledExternalLink
          target="_blank"
          href="https://bit.ly/pontis-overview"
        >
          here
        </StyledExternalLink>
        .
      </div>
    </div>

    <div className="flex my-4">
      <div className="text-center m-auto">What would you like to do?</div>
    </div>

    <div className="flex mx-auto">
      <div className="m-auto my-2">
        <ActionButton pagePath="/buy" text="Buy" />
        <ActionButton pagePath="/sell" text="Sell" />
      </div>
    </div>
  </div>
);

export default IndexPage;
