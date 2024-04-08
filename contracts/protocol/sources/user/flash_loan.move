/// @title Module for flash loan from Scallop base asset pools
/// @author Scallop Labs
module protocol::flash_loan {

  use std::type_name::{Self, TypeName};
  use std::option::{Self, Option};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::event::emit;
  use whitelist::whitelist;
  use protocol::ticket_accesses::{Self, TicketForFlashLoanFeeDiscount};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::error;
  use protocol::reserve::{Self, FlashLoan};

  #[allow(unused_field)]
  struct BorrowFlashLoanEvent has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
  }

  #[allow(unused_field)]
  struct RepayFlashLoanEvent has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
  }

  struct BorrowFlashLoanV2Event has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
    fee: u64,
    fee_discount_numerator: u64,
    fee_discount_denominator: u64,
  }

  struct RepayFlashLoanV2Event has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
    fee: u64,
  }

  /// @notice Borrow flash loan from Scallop market
  /// @dev Flash loan is a loan that is borrowed and repaid in the same transaction
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param amount The amount of flash loan to borrow
  /// @param ctx The SUI transaction context object
  /// @return The borrowed coin object and the flash loan hot potato object
  /// @custom:T The type of asset to borrow
  public fun borrow_flash_loan<T>(
    version: &Version,
    market: &mut Market,
    amount: u64,
    ctx: &mut TxContext,
  ): (Coin<T>, FlashLoan<T>) {
    // check if version is supported
    version::assert_current_version(version);

    let (coin, receipt) = borrow_flash_loan_internal<T>(
      market,
      amount,
      option::none(),
      ctx,
    );

    (coin, receipt)
  }

  /// @notice Borrow flash loan from Scallop market
  /// @dev This should be called by contracts which have access to issue flash loan fee discount tickets
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param amount The amount of flash loan to borrow
  /// @param ticket The flash loan fee discount ticket
  /// @param ctx The SUI transaction context object
  /// @return The borrowed coin object and the flash loan hot potato object
  /// @custom:T The type of asset to borrow
  public fun borrow_flash_loan_with_ticket<T>(
    version: &Version,
    market: &mut Market,
    amount: u64,
    ticket: TicketForFlashLoanFeeDiscount,
    ctx: &mut TxContext,
  ): (Coin<T>, FlashLoan<T>) {
    // check if version is supported
    version::assert_current_version(version);

    let (coin, receipt) = borrow_flash_loan_internal<T>(
      market,
      amount,
      option::some(ticket),
      ctx,
    );

    (coin, receipt)
  }

  fun borrow_flash_loan_internal<T>(
    market: &mut Market,
    amount: u64,
    ticket_opt: Option<TicketForFlashLoanFeeDiscount>,
    ctx: &mut TxContext,
  ): (Coin<T>, FlashLoan<T>) {
    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    let coin_type = type_name::get<T>();
    // check if base asset is active
    assert!(
      market::is_base_asset_active(market, coin_type),
      error::base_asset_not_active_error()
    );

    let (fee_discount_numerator, fee_discount_denominator) = (0, 1);

    // Borrow the assets from market, and apply fee discount if any
    let (coin, receipt) = if (option::is_some(&ticket_opt)) {
      let fee_discount_ticket = option::extract(&mut ticket_opt);
      (fee_discount_numerator, fee_discount_denominator) = ticket_accesses::get_flash_loan_fee_discount(&fee_discount_ticket);
      market::borrow_flash_loan_with_ticket(market, fee_discount_ticket, amount, ctx)
    } else {
      market::borrow_flash_loan(market, amount, ctx)
    };

    // Emit the borrow flash loan event
    emit(BorrowFlashLoanV2Event {
      borrower: tx_context::sender(ctx),
      asset: coin_type,
      amount,
      fee: reserve::flash_loan_fee(&receipt),
      fee_discount_numerator: fee_discount_numerator,
      fee_discount_denominator: fee_discount_denominator,
    });

    // Return the borrowed coin object and the flash loan hot potato object
    (coin, receipt)
  }

  /// @notice Repay flash loan to Scallop market
  /// @dev This is the only method to repay flash loan, consume the flash loan hot potato object
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param coin The coin object to repay
  /// @param loan The flash loan hot potato object, which contains the borrowed amount and fee
  /// @ctx The SUI transaction context object
  /// @custom:T The type of asset to repay
  public fun repay_flash_loan<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    loan: FlashLoan<T>,
    ctx: &mut TxContext
  ) {
    // check if version is supported
    version::assert_current_version(version);

    // Emit the repay flash loan event
    emit(RepayFlashLoanV2Event {
      borrower: tx_context::sender(ctx),
      asset: type_name::get<T>(),
      amount: coin::value(&coin),
      fee: reserve::flash_loan_fee(&loan),
    });

    // Put the asset back to the market and consume the flash loan hot potato object
    market::repay_flash_loan(market, coin, loan)
  }
}
