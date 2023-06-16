// refactor obligation to better handle operations
module protocol::obligation {
  
  use std::type_name::{Self, TypeName};
  use std::vector;
  use sui::object::{Self, UID};
  use sui::tx_context;
  use sui::balance::{Self, Balance};
  
  use x::balance_bag::{Self, BalanceBag};
  use x::ownership::{Self, Ownership};
  use x::wit_table::{Self, WitTable};
  use x::witness::Witness;
  
  use protocol::obligation_debts::{Self, ObligationDebts, Debt};
  use protocol::obligation_collaterals::{Self, ObligationCollaterals, Collateral};
  use protocol::market::{Self, Market};
  
  friend protocol::repay;
  friend protocol::borrow;
  friend protocol::withdraw_collateral;
  friend protocol::deposit_collateral;
  friend protocol::liquidate;
  friend protocol::open_obligation;
  
  struct Obligation has key, store {
    id: UID,
    balances: BalanceBag,
    debts: WitTable<ObligationDebts, TypeName, Debt>,
    collaterals: WitTable<ObligationCollaterals, TypeName, Collateral>
  }
  
  struct ObligationOwnership has drop {}
  
  struct ObligationKey has key, store {
    id: UID,
    ownership: Ownership<ObligationOwnership>
  }

  // ==== Leave room for future extension ====

  public fun obligation_key_uid_mut(key: &ObligationKey, _: Witness<ObligationKey>): &mut UID {
    &mut key.id
  }

  public fun obligation_uid_mut(obligation: &Obligation, _: Witness<Obligation>): &mut UID {
    &mut obligation.id
  }

  public(friend) fun new(ctx: &mut tx_context::TxContext): (Obligation, ObligationKey) {
    let obligation = Obligation {
      id: object::new(ctx),
      balances: balance_bag::new(ctx),
      debts: obligation_debts::new(ctx),
      collaterals: obligation_collaterals::new(ctx),
    };
    let obligation_ownership = ownership::create_ownership(
      ObligationOwnership{},
      object::id(&obligation),
      ctx
    );
    let obligation_key = ObligationKey {
      id: object::new(ctx),
      ownership: obligation_ownership,
    };
    (obligation, obligation_key)
  }
  
  public fun assert_key_match(obligation: &Obligation, key: &ObligationKey) {
    ownership::assert_owner(&key.ownership, obligation)
  }
  
  public fun is_key_match(obligation: &Obligation, key: &ObligationKey): bool {
    ownership::is_owner(&key.ownership, obligation)
  }
  
  public(friend) fun accrue_interests(
    obligation: &mut Obligation,
    market: &Market,
  ) {
    let debt_types = debt_types(obligation);
    let (i, n) = (0, vector::length(&debt_types));
    while (i < n) {
      let type = *vector::borrow(&debt_types, i);
      let new_borrow_index = market::borrow_index(market, type);
      obligation_debts::accure_interest(&mut obligation.debts, type, new_borrow_index);
      i = i + 1;
    };
  }
  
  public(friend) fun withdraw_collateral<T>(
    self: &mut Obligation,
    amount: u64,
  ): Balance<T> {
    let type_name = type_name::get<T>();
    // reduce collateral amount
    obligation_collaterals::decrease(&mut self.collaterals, type_name, amount);
    // return the collateral balance
    balance_bag::split(&mut self.balances, amount)
  }
  
  public(friend) fun deposit_collateral<T>(
    self: &mut Obligation,
    balance: Balance<T>,
  ) {
    // increase collateral amount
    let type_name = type_name::get<T>();
    obligation_collaterals::increase(&mut self.collaterals, type_name, balance::value(&balance));
    // put the collateral balance
    if (balance_bag::contains<T>(&self.balances) == false) {
      balance_bag::init_balance<T>(&mut self.balances);
    };
    balance_bag::join(&mut self.balances, balance);
  }
  
  public(friend) fun init_debt(
    self: &mut Obligation,
    market: &Market,
    type_name: TypeName,
  ) {
    let borrow_index = market::borrow_index(market, type_name);
    obligation_debts::init_debt(&mut self.debts, type_name, borrow_index);
  }
  
  public(friend) fun increase_debt(
    self: &mut Obligation,
    type_name: TypeName,
    amount: u64,
  ) {
    obligation_debts::increase(&mut self.debts, type_name, amount);
  }
  
  public(friend) fun decrease_debt(
    self: &mut Obligation,
    type_name: TypeName,
    amount: u64,
  ) {
    obligation_debts::decrease(&mut self.debts, type_name, amount);
  }
  
  public fun debt(self: &Obligation, type_name: TypeName): (u64, u64) {
    obligation_debts::debt(&self.debts, type_name)
  }
  
  public fun collateral(self: &Obligation, type_name: TypeName): u64 {
    obligation_collaterals::collateral(&self.collaterals, type_name)
  }
  
  // return the debt types
  public fun debt_types(self: &Obligation): vector<TypeName> {
    wit_table::keys(&self.debts)
  }
  
  // return the collateral types
  public fun collateral_types(self: &Obligation): vector<TypeName> {
    wit_table::keys(&self.collaterals)
  }
  
  public fun balance_bag(self: &Obligation): &BalanceBag {
    &self.balances
  }
  
  public fun debts(self: &Obligation): &WitTable<ObligationDebts, TypeName, Debt> {
    &self.debts
  }
  
  public fun collaterals(self: &Obligation): &WitTable<ObligationCollaterals, TypeName, Collateral> {
    &self.collaterals
  }
}
