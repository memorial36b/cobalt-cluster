# Module: Inventory

# Fields should match database
class InventoryItem
  # Construct a new item.
  def initialize(hash)
    @entry_id = hash[:entry_id]
    @owner_user_id = hash[:owner_user_id]
    @item_id = hash[:item_id]
    @timestamp = hash[:timestamp]
    @expiration = hash[:expiration]
    @value = hash[:value]
  end

  # Get entry id
  def entry_id
    return @entry_id
  end

  # Get owner user id
  def owner_user_id
    return @owner_user_id
  end

  # Get item id
  def item_id
    return @item_id
  end

  # Get timestamp
  def timestamp
    return @timestamp
  end

  # Get expiration timestamp
  def expiration
    return @expiration
  end

  # Get value
  def value
    return @value
  end

  # Get item type
  def item_type
    return Bot::Inventory::get_item_type_from_id(@item_id)
  end

  # Get item type ui name
  def type_ui_name
    item_type_id = item_type
    return Bot::Inventory::get_item_type_ui_name(item_type_id)
  end

  # Get ui name
  def ui_name
    Bot::Inventory::get_item_ui_name_from_id(@item_id)
  end
end

# Helper functions for inventory management
# Note: Not defined in lib because DB must already be init'ed.
module Bot::Inventory
  extend Convenience
  include Constants

  # User inventory (purchased/received items)
  # { entry_id, owner_user_id, item_id, timestamp, expiration, value }
  USER_INVENTORY = DB[:econ_user_inventory]

  # Path to economy data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze

  module_function

  # Get the catalogue yaml document.
  # @return [YAML] Yaml catalogue document.
  def catalog
    return YAML.load_data!("#{ECON_DATA_PATH}/catalogue.yml")
  end

  # Get a generic value from the catalogue.
  # @param [Generic] key
  # @return [Generic] value or nil if not found.
  def catalog_value(key)
    return catalog[key]
  end

  # Get the item's unique id from the name.
  # @param [String] item_name Item's name as specified in catalogue.yaml
  # @return [Integer] Item id. Nil if not found.
  def get_item_id(item_name)
    item_id_name = item_name + "_id"
    return catalog[item_id_name]
  end
  
  # Get the item's unique id from the name.
  # @param [Integer] item_id The item's unique id.
  # @return [Integer] item type id
  def get_item_type_from_id(item_id)
    return item_id & 0xF000
  end

  # Get the item's unique id from the name.
  # @param [String] item_name Item's name as specified in catalogue.yaml
  # @return [Integer] item type id
  def get_item_type(item_name)
    item_id = get_item_id(item_name)
    return get_item_type_from_id(item_id)
  end

  # Get the value of a type of item.
  # @param [Integer] item_type item type identifier.
  # @return [Integer] The value of the item type in Starbucks. Returns zero if not found.
  def get_item_type_value(item_type)
    catalogue_key = u!(item_type)
    point_value_key = catalog[catalogue_key]
    return 0 if point_value_key == nil
    return Bot::Bank::appraise_item(point_value_key)
  end

  # Get an item's value from the id.
  # @param [Integer] item_id item id
  # @return [Integer] The value of the item in Starbucks.
  def get_item_value_from_id(item_id)
    item_type = get_item_type_from_id(item_id)
    return get_item_type_value(item_type)
  end

  # Get an item's value from the id.
  # @param [Integer] item_id item id
  # @return [Integer] The value of the item in Starbucks.
  def get_item_value(item_name)
    item_type = get_item_type(item_name)
    return get_item_type_value(item_type)
  end

  # Get an item type's ui name from the type id.
  # @param [Integer] item_type item type
  # @return [String] item type ui name or nil if not found
  def get_item_type_ui_name(item_type)
    return catalog[item_type] 
  end

  # Get an item's ui name from a the id.
  # @param [Integer] item_id item id
  # @return [String] item name or nil if not found 
  def get_item_ui_name_from_id(item_id)
    return catalog[item_id]
  end
  
  # Get the cost to renew an item type.
  # @param [Integer] item_type item type
  # @return [Integer] The cost to renew or nil if it doesn't expire.
  def get_item_type_renewal_cost(item_type)
    catalogue_key = u!(item_type) - 1
    point_value_key = catalog_value(catalogue_key)
    return nil if point_value_key == nil

    return Bot::Bank::appraise_item(point_value_key)
  end

  # Get the cost to renew an item with the given id.
  # @param [Integer] item_id item id identifier
  # @return [Integer] The cost to renew or nil if it doesn't expire.
  def get_item_renewal_cost_from_id(item_id)
    item_type = get_item_type_from_id(item_id)
    return get_item_type_renewal_cost(item_type)
  end

  # Get an item types's lifetime from the id. Assumes valid id.
  # @param [Integer] item_type The item type.
  # @return [Integer] number of days item lasts or nil if it doesn't expire
  def get_item_type_lifetime(item_type)
    key = u!(item_type) - 2
    return catalog_value(key)
  end

  # Get an item's lifetime from the id. Assumes valid id.
  # @param [Integer] item_id The item id.
  # @return [Integer] number of days item lasts or nil if it doesn't expire
  def get_item_lifetime_from_id(item_id)
    item_type = get_item_type_from_id(item_id)
    return get_item_type_lifetime(item_type)
  end

  # Add an item to the user's inventory.
  # @param [Integer] user_id user id
  # @param [Integer] item_id item id
  # @return [InventoryItem] Added item.
  def add_item(user_id, item_id)
    owner_user_id = user_id
    timestamp = Time.now.to_i
    value = get_item_value_from_id(item_id)
    expiration = nil

    # compute expiration if there is one
    lifetime = get_item_lifetime_from_id(item_id)
    if lifetime != nil
      expiration = (Time.now.to_datetime + lifetime).to_time.to_i
    end

    # add item
    entry_id = USER_INVENTORY.insert(
      owner_user_id: owner_user_id,
      item_id: item_id,
      timestamp: timestamp,
      expiration: expiration,
      value: value
    )

    item = USER_INVENTORY[entry_id: entry_id]
    return nil if item == nil

    return InventoryItem.new(item)
  end
  
  # Add an item to the user's inventory by name.
  # @param [Integer] user_id    user id
  # @param [String]  item_name  name of the item in catalogue.yml
  # @return [InventoryItem] Added item or nil if it could not be added.
  def add_item_by_name(user_id, item_name)
    # aggregate item information
    item_id = get_item_id(item_name)
    if item_id == nil
      raise ArgumentError, "Invalid item name specified #{item_name}!"
      return nil
    end

    return add_item(user_id, item_id)
  end

  # Push back the expiration date on a given item by it's lifetime.
  # @param [Integer] entry_id the item to renew
  # @param [bool] Success? Returns false if non-renewable or not found
  def renew_item(entry_id)
    item = USER_INVENTORY.where(entry_id: entry_id)
    return false if item == nil || item.first == nil || item.first[:expiration] == nil

    lifetime = get_item_lifetime_from_id(item.first[:item_id])
    return false if lifetime == nil

    new_expiration = (Time.at(item.first[:expiration]).to_datetime + lifetime).to_time.to_i
    item.update(expiration: new_expiration)
    return true
  end

  # Remove the specified item from inventory.
  # @param [Integer] entry_id the item to remove
  # @return [bool] Success?
  def remove_item(entry_id)
    USER_INVENTORY.where(entry_id: entry_id).delete
    return true
  end

  # Get the user's complete inventory
  # @param [Integer] user_id   user id
  # @param [Integer] item_type optional: item type to filter by
  # @return [Array<Item>] items the user has.
  def get_inventory(user_id, item_type = nil)
    items = USER_INVENTORY.where(owner_user_id: user_id)
    if item_type != nil
      items = items.where{Sequel.&((item_id >= item_type), (item_id < item_type + 0x1000))}
    end

    items = items.all
    inventory = []
    
    items.each do |item|
      inventory.push(InventoryItem.new(item))
    end

    return inventory
  end

  # Get the value of the user's entire inventory.
  # @param [Integer] user_id user id
  # @return [Integer] total value
  def get_inventory_value(user_id)
    value = USER_INVENTORY.where(owner_user_id: user_id).sum(:value)
    return value.nil? ? 0 : value
  end

  # Get list of users that have an inventory.
  # @return [Array<Integer>] Array of user ids.
  #
  # Note: Easy way to iterate over all user's inventories.
  def get_users_with_inventory()
    users = DB["SELECT DISTINCT owner_user_id FROM econ_user_inventory"]

    array = []
    users.all.each do |user|
      array.push(user[:owner_user_id])
    end

    return array
  end
end