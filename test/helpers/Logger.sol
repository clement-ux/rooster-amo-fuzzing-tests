// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibString} from "@solady/utils/LibString.sol";

library Logger {
    using LibString for int32;
    using LibString for string;
    using LibString for uint256;

    // This format values in logs, however it reduce the speed of the tests.
    bool public constant FORMATED_LOGS = true;
    uint256 public constant DEFAULT_MAX_DIGITS = 14;

    function faa(uint256 amount) public pure returns (string memory) {
        return FORMATED_LOGS ? formatAmountAligned(amount, DEFAULT_MAX_DIGITS) : amount.toString();
    }

    function faa(uint256 amount, uint256 maxDigits) public pure returns (string memory) {
        return formatAmountAligned(amount, maxDigits);
    }

    function formatAmountAligned(uint256 amount, uint256 maxRawDigits) internal pure returns (string memory) {
        uint256 integer = amount / 1e18;
        uint256 fraction = amount % 1e18;

        // Step 1: convertir en string brute (sans virgules ni padding)
        string memory rawIntegerStr = integer.toString();

        // Step 2: ajouter les virgules
        string memory withCommas = addThousandSeparators(rawIntegerStr);
        uint256 targetLength = maxRawDigits;

        // Step 4: pad à gauche le résultat final (avec les virgules)
        string memory paddedInteger = padLeft(withCommas, targetLength);

        // Step 5: formater les décimales
        string memory fractionStr = uintToFixedLengthString(fraction, 18);

        return string(abi.encodePacked(paddedInteger, ".", fractionStr));
    }

    function uintToFixedLengthString(uint256 value, uint256 digits) internal pure returns (string memory) {
        string memory str = value.toString();
        uint256 length = bytes(str).length;

        if (length >= digits) return str;

        bytes memory result = new bytes(digits);
        for (uint256 i = 0; i < digits - length; i++) {
            result[i] = "0";
        }
        for (uint256 i = 0; i < length; i++) {
            result[digits - length + i] = bytes(str)[i];
        }

        return string(result);
    }

    function padLeft(string memory str, uint256 totalLength) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint256 padding = totalLength > strBytes.length ? totalLength - strBytes.length : 0;

        bytes memory padded = new bytes(totalLength);
        for (uint256 i = 0; i < padding; i++) {
            padded[i] = " ";
        }
        for (uint256 i = 0; i < strBytes.length; i++) {
            padded[padding + i] = strBytes[i];
        }

        return string(padded);
    }

    function addThousandSeparators(string memory number) internal pure returns (string memory) {
        bytes memory numBytes = bytes(number);
        uint256 len = numBytes.length;

        if (len <= 3) return number;

        uint256 commas = (len - 1) / 3;
        bytes memory result = new bytes(len + commas);

        uint256 j = result.length;
        uint256 k = 0;

        for (uint256 i = len; i > 0; i--) {
            j--;
            result[j] = numBytes[i - 1];
            k++;
            if (k % 3 == 0 && i != 1) {
                j--;
                result[j] = " ";
            }
        }

        return string(result);
    }

    function uintArrayToString(uint256[] memory _array) public pure returns (string memory) {
        bytes memory result;

        for (uint256 i = 0; i < _array.length; i++) {
            result = abi.encodePacked(result, _array[i].toString());
            if (i < _array.length - 1) {
                result = abi.encodePacked(result, ", ");
            }
        }

        return string(result);
    }

    function toString(int32[] memory values) public pure returns (string memory result) {
        result = "[";
        for (uint256 i; i < values.length; i++) {
            result = result.concat(values[i].toString());
            result = result.concat(i < values.length - 1 ? "," : "]");
        }
    }
}
