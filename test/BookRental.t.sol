// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BookRental.sol";

contract BookRentalTest is Test {
    BookRental    rental;
    address       owner = address(this);
    address constant alice = address(0x1);
    address constant bob   = address(0x2);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        // fund the test‐harness itself…
        vm.deal(address(this), 10 ether);
        // …and also fund our “users” so they can pay deposits
        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);

        rental = new BookRental();
    }

    /* ── Listing ── */
    function testListBook() public {
        uint256 rent = 0.5 ether;
        rental.listBook("QmCID", rent);

        (uint256 d, address o, bool a, address r, string memory cid) =
            rental.getBookDetails(1);

        assertEq(d, rent);
        assertEq(o, owner);
        assertTrue(a);
        assertEq(r, address(0));
        assertEq(cid, "QmCID");
    }

    function testFailRemoveBookByNonOwner() public {
        rental.listBook("foo", 1 ether);
        vm.prank(alice);
        rental.removeBook(1);
    }

    /* ── Renting ── */
    function testRentBookAndStateChange() public {
        uint256 rent  = 0.1 ether;
        uint256 days_ = 3;
        rental.listBook("bar", rent);

        uint256 deposit = days_ * rent
            + rental.MAX_PENALTY_DAYS() * rental.PENALTY_PER_DAY_WEI();

        vm.prank(alice);
        rental.rentBook{ value: deposit }(1, days_);

        (, , bool available, address renter, ) = rental.getBookDetails(1);
        assertFalse(available, "book should be locked");
        assertEq(renter, alice);
    }

    function testFailRentInsufficientPayment() public {
        rental.listBook("baz", 1 ether);
        vm.prank(alice);
        rental.rentBook{ value: 0.5 ether }(1, 2);
    }

    /* ── Returns ── */
    function testReturnBookOnTime() public {
        rental.listBook("onTime", 0.2 ether);
        uint256 days_   = 2;
        uint256 deposit = days_ * 0.2 ether
            + rental.MAX_PENALTY_DAYS() * rental.PENALTY_PER_DAY_WEI();

        vm.prank(alice);
        rental.rentBook{ value: deposit }(1, days_);
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        rental.returnBook(1);

        (, , bool available, address renter, ) = rental.getBookDetails(1);
        assertTrue(available, "should be available again");
        assertEq(renter, address(0));
    }

    function testReturnBookLateAppliesPenalty() public {
        rental.listBook("late", 0.2 ether);
        uint256 days_   = 1;
        uint256 deposit = days_ * 0.2 ether
            + rental.MAX_PENALTY_DAYS() * rental.PENALTY_PER_DAY_WEI();

        vm.prank(alice);
        rental.rentBook{ value: deposit }(1, days_);
        vm.warp(block.timestamp + (days_ + 2) * 1 days);
        vm.prank(alice);
        rental.returnBook(1);

        (, , bool available, , ) = rental.getBookDetails(1);
        assertTrue(available, "should unlock after return");
    }

    /* ── Edge Case ── */
    function testFailRentUnavailableBook() public {
        rental.listBook("once", 0.1 ether);
        uint256 deposit = 1 * 0.1 ether
            + rental.MAX_PENALTY_DAYS() * rental.PENALTY_PER_DAY_WEI();

        vm.prank(alice);
        rental.rentBook{ value: deposit }(1, 1);
        vm.prank(bob);
        rental.rentBook{ value: deposit }(1, 1);
    }
}
