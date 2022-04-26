from collections import namedtuple


def str_to_felt(text):
    if text.lower() != text:
        print(
            "Converting string to felt that has uppercase characters. Converting to lowercase."
        )
        text = text.lower()
    b_text = bytes(text, "utf-8")
    return int.from_bytes(b_text, "big")


CallOptionSubmission = namedtuple(
    "Entry",
    [
        "id",
        "expiration_timestamp",
        "fee",
        "size",
        "strike_price",
        "currency_address",
        "oracle_key",
    ],
)
UInt256 = namedtuple("UInt256", ["low", "high"])


def to_uint_decimals(input):
    return to_uint(int(input * 10**18))


# From OZ
def to_uint(a):
    """Takes in value, returns uint256-ish tuple."""
    return (a & ((1 << 128) - 1), a >> 128)
