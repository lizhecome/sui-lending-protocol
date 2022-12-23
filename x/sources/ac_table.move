/// Access controlled table
/// Ownership is required to write or destory
/// Read is open to anyone
module x::ac_table {
  
  use std::option;
  use std::vector;
  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::vec_set::{Self, VecSet};
  use sui::tx_context::TxContext;
  
  use x::ownership::{Self, Ownership};
  
  struct AcTable<phantom T: drop, K: copy + drop + store, phantom V: store> has key, store {
    id: UID,
    table: Table<K, V>,
    keys: option::Option<VecSet<K>>,
    withKeys: bool
  }
  
  struct AcTableOwnership has drop {}
  
  /// Creates a new, empty table
  public fun new<T: drop, K: copy + drop + store, V: store>(
    _: T,
    withKeys: bool,
    ctx: &mut TxContext
  ): (AcTable<T, K, V>, Ownership<AcTableOwnership>) {
    let keys = if (withKeys) {
      option::some(vec_set::empty<K>())
    }  else {
      option::none()
    };
    let acTable = AcTable<T, K, V> {
      id: object::new(ctx),
      table: table::new(ctx),
      keys,
      withKeys,
    };
    let acTableOwnership = ownership::create_ownership(
      AcTableOwnership{},
      object::id(&acTable),
      ctx
    );
    (acTable, acTableOwnership)
  }
  
  /// Adds a key-value pair to the table.
  /// Aborts if the xtable already has an entry with that key `k: K`.
  /// Access controlled
  public fun add<T: drop, K: copy + drop + store, V: store>(
    self: &mut AcTable<T, K, V>,
    ownership: &Ownership<AcTableOwnership>,
    k: K, v: V
  ) {
    ownership::assert_owner(ownership, self);
    table::add(&mut self.table, k, v);
    if (self.withKeys) {
      let keys = option::borrow_mut(&mut self.keys);
      vec_set::insert(keys, k);
    }
  }
  
  /// Return: vector of all the keys
  public fun keys<T: drop, K: copy + drop + store, V: store>(
    self: &AcTable<T, K, V>,
  ): vector<K> {
    if (self.withKeys) {
      let keys = option::borrow(&self.keys);
      vec_set::into_keys(*keys)
    } else {
      vector::empty()
    }
  }
  
  /// Immutable borrows the value associated with the key in the table.
  /// Aborts if the table does not have an entry with that key `k: K`.
  public fun borrow<T: drop, K: copy + drop + store, V: store>(
    self: &AcTable<T, K, V>,
    k: K
  ): &V {
    table::borrow(&self.table, k)
  }
  
  /// Mutably borrows the value associated with the key in the table.
  /// Aborts if the table does not have an entry with that key `k: K`.
  /// Access control
  public fun borrow_mut<T: drop, K: copy + drop + store, V: store>(
    self: &mut AcTable<T, K, V>,
    ownership: &Ownership<AcTableOwnership>,
    k: K
  ): &mut V {
    ownership::assert_owner(ownership, self);
    table::borrow_mut(&mut self.table, k)
  }
  
  /// Mutably borrows the key-value pair in the table and returns the value.
  /// Aborts if the table does not have an entry with that key `k: K`.
  /// Witness control
  public fun remove<T: drop, K: copy + drop + store, V: store>(
    self: &mut AcTable<T, K, V>,
    ownership: &Ownership<AcTableOwnership>,
    k: K
  ): V {
    ownership::assert_owner(ownership, self);
    if (self.withKeys) {
      let keys = option::borrow_mut(&mut self.keys);
      vec_set::remove(keys, &k);
    };
    table::remove(&mut self.table, k)
  }
  
  /// Returns true if there is a value associated with the key `k: K` in table
  /// Permisionless
  public fun contains<T: drop, K: copy + drop + store, V: store>(
    self: &AcTable<T, K, V>,
    k: K
  ): bool {
    table::contains(&self.table, k)
  }
  
  /// Returns the size of the table, the number of key-value pairs
  /// Permisionless
  public fun length<T: drop, K: copy + drop + store, V: store>(
    self: &AcTable<T, K, V>,
  ): u64 {
    table::length(&self.table)
  }
  
  /// Returns true if the table is empty (if `length` returns `0`)
  /// Permisionless
  public fun is_empty<T: drop, K: copy + drop + store, V: store>(
    self: &AcTable<T, K, V>
  ): bool {
    table::is_empty(&self.table)
  }
  
  /// Destroys an empty table
  /// Aborts if the table still contains values
  /// Witness control
  public fun destroy_empty<T: drop, K: copy + drop + store, V: store>(
    self: AcTable<T, K, V>,
    ownership: &Ownership<AcTableOwnership>,
  ) {
    ownership::assert_owner(ownership, &self);
    let AcTable { id, table, keys: _, withKeys: _ } = self;
    table::destroy_empty(table);
    object::delete(id)
  }
  
  /// Drop a possibly non-empty table.
  /// Usable only if the value type `V` has the `drop` ability
  /// Witness control
  public fun drop<T: drop, K: copy + drop + store, V: drop + store>(
    self: AcTable<T, K, V>,
    ownership: &Ownership<AcTableOwnership>,
  ) {
    ownership::assert_owner(ownership, &self);
    let AcTable { id, table, keys: _, withKeys: _ } = self;
    table::drop(table);
    object::delete(id)
  }
}
