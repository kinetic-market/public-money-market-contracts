pragma solidity 0.5.17;

import "./Comptroller.sol";

contract LiquidateAllowedComptroller is Comptroller{        
    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) external returns (uint)
        {                    
            // Fake method to be mocked on tests, because of a problem with the smock
            cTokenBorrowed;
            cTokenCollateral;
            liquidator;
            borrower;
            repayAmount;
          
            return 1;
    }
}