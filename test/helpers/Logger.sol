// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Logger {
    // Converts a uint256 to a string with 12 digits before and 18 after the decimal point
    // Replaces leading zeros in the integer part with spaces
    function uintToFixedString(uint256 number) public pure returns (string memory) {
        // Split the number into integer and decimal parts
        // Consider the last 18 digits as decimals
        uint256 decimalPlaces = 18;
        uint256 divisor = 10 ** decimalPlaces; // 1 followed by 18 zeros
        uint256 integerPart = number / divisor;
        uint256 decimalPart = number % divisor;

        // Convert the parts to strings
        string memory integerStr = uintToString(integerPart);
        string memory decimalStr = uintToString(decimalPart);

        // Pad the integer part with spaces on the left for leading zeros
        string memory paddedInteger = padLeftWithSpaces(integerStr, 12);

        // Pad the decimal part with zeros on the left
        string memory paddedDecimal = padLeft(decimalStr, 18);

        // Concatenate with the decimal point
        return string(abi.encodePacked(paddedInteger, ".", paddedDecimal));
    }

    // Converts a uint256 to a string
    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        // Count the number of digits
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        // Create a byte array to store the digits
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    // Pads a string with spaces on the left until it reaches the desired length
    function padLeftWithSpaces(string memory str, uint256 length) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= length) {
            return str;
        }

        // Create a new array for padding
        bytes memory padded = new bytes(length);
        uint256 spacesToAdd = length - strBytes.length;

        // Fill with spaces
        for (uint256 i = 0; i < spacesToAdd; i++) {
            padded[i] = bytes1(uint8(32)); // ' '
        }

        // Copy the existing digits
        for (uint256 i = 0; i < strBytes.length; i++) {
            padded[spacesToAdd + i] = strBytes[i];
        }

        return string(padded);
    }

    // Pads a string with zeros on the left until it reaches the desired length
    function padLeft(string memory str, uint256 length) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= length) {
            return str;
        }

        // Create a new array for padding
        bytes memory padded = new bytes(length);
        uint256 zerosToAdd = length - strBytes.length;

        // Fill with zeros
        for (uint256 i = 0; i < zerosToAdd; i++) {
            padded[i] = bytes1(uint8(48)); // '0'
        }

        // Copy the existing digits
        for (uint256 i = 0; i < strBytes.length; i++) {
            padded[zerosToAdd + i] = strBytes[i];
        }

        return string(padded);
    }
}
