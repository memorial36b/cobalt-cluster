# Module: Tags

# Friendly wrapper for Tag entries.
class UserTag
  # Construct a new UserTag.
  def initialize(hash)
    @tag_name      = hash[:tag_name]
    @item_entry_id = hash[:item_entry_id]
    @owner_user_id = hash[:owner_user_id]
    @tag_content   = hash[:tag_content]
  end

  # Get the tag's name/invocation identifier.
  def tag_name
    return @tag_name
  end

  # Get the item entry id.
  def item_entry_id
    return @item_entry_id
  end

  # Get the tags's owner's user id.
  def owner_user_id
    return @owner_user_id
  end

  # Get the tag's message content.
  def tag_content
    return @tag_content
  end
end

# Helper functions for tag management
# Note: Not defined in lib because DB must already be init'ed.
module Bot::Tags
  extend Convenience
  include Constants
    
  # User created tags
  # { tag_name, item_entry_id, owner_user_id, tag_content }
  USER_TAGS = DB[:econ_user_tags]

  # Path to economy data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze

  # Converts tag hashes to paginator fields. 
  TAG_HASH_TO_PAGINATOR_FIELD_LAMBDA = lambda do |hash|
    field_name  = hash[:tag_name] 
    field_value = hash[:tag_content]

    field_name = "_ERROR_" if field_name.nil? or field_name.empty?
    field_value = "_ERROR_" if field_value.nil? or field_value.empty?

    return PaginatorField.new(field_name, field_value)
  end
  
  module_function

  # Get the max tag name length.
  # @return [Integer] max tag name length
  def GetMaxTagNameLength()
    limits_yaml = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")
    return limits_yaml['tag_name_max_length']
  end 

  # Get max tag content length.
  # @return [Integer] max tag content length
  def GetMaxTagContentLength()
    limits_yaml = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")
    return limits_yaml['tag_content_max_length']
  end

  # Get how long to wait in seconds before the configuration message times out.
  # @return [Integer] number of seconds to wait before timing out.
  def GetTagResponseTimeout()
    limits_yaml = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")
    return limits_yaml['tag_response_timeout']
  end

  # Add a user created tag.
  # @param [String]  tag_name      the unique name used to invoke the tag
  # @param [Integer] item_entry_id unique identifier of the associated item.
  # @param [Integer] owner_user_id owner user's id
  # @param [String]  tag_content   the message to send when invoked
  # @return [bool] Success? Returns false if tag already exists or name is invalid
  # Note: Must link to a created item.
  def AddTag(tag_name, item_entry_id, owner_user_id, tag_content)
    tag_name = tag_name.downcase #enforce lowercase names
    return false if tag_name.length <= 0 or tag_name.length > GetMaxTagNameLength() or tag_content.length > GetMaxTagContentLength()
    return false if tag_name =~ /\s/ # no spaces allowed
    return false if USER_TAGS.where(tag_name: tag_name).count() > 0
    
    # will raise error on invalid content
    USER_TAGS << { item_entry_id: item_entry_id, owner_user_id: owner_user_id, tag_name: tag_name, tag_content: tag_content }
    return true
  end

  # Edit the specified tag's content.
  # @param [String]  tag_name        tag's unique name
  # @param [Integer] owner_user_id   tag owner's id, used for verification to prevent other users from editing it
  # @param [String]  new_tag_content new tag content
  # @return [bool] Success? Returns false if not found or doesn't belong to the specified user.
  def EditTag(tag_name, owner_user_id, new_tag_content)
    return false if new_tag_content.length > GetMaxTagContentLength()
    tags = USER_TAGS.where{Sequel.&({owner_user_id: owner_user_id}, {tag_name: tag_name})}
    return false if tags.count() <= 0

    tags.update(tag_content: new_tag_content)
    return true
  end

  # Remove the tag with the given name
  # @param [String]  tag_name      tag's unique name
  # @param [Integer] owner_user_id the owner to validate against
  # @return [bool] Success? Returns false if not found or not owned by specified user
  def RemoveTag(tag_name, owner_user_id)
    tags = USER_TAGS.where{Sequel.&({owner_user_id: owner_user_id}, {tag_name: tag_name})}
    return false if tags.count() <= 0

    tags.delete
    return true
  end

  # Remove the tag associated with the given item_entry_id.
  # @param [Integer] item_entry_id associated item entry id
  # @return [bool] Success? Returns false if not found
  def RemoveTagByItemEntryID(item_entry_id)
    tags = USER_TAGS.where(item_entry_id: item_entry_id)
    return false if tags == nil || tags.count <= 0

    tags.delete
    return true
  end

  # Check if a tag with the specified name exists.
  # @param [String] tag_name tag name
  # @return [bool] does the tag exist?
  def HasTag(tag_name)
    tag = USER_TAGS[tag_name: tag_name]
    return tag != nil
  end

  # Get tag with the specified name.
  # @param [String] tag_name tag name
  # @return [UserTag] The tag or nil if not found.
  def GetTag(tag_name)
    tag = USER_TAGS[tag_name: tag_name]
    return nil if tag == nil

    # create tag
    return UserTag.new(tag)
  end

  # Get a tag by its associated item.
  # @param [Integer] item_entry_id item's unique idenifier.
  # @return [UserTag] The tag or nil if not found.
  def GetTagByItemEntryID(item_entry_id)
    tag = USER_TAGS[item_entry_id: item_entry_id]
    return nil if tag == nil

    # create tag
    return UserTag.new(tag)
  end

  # Get the full list of all valid tags.
  # @return [Array<UserTag>] All known tags.
  def GetAllTags()
    tag_hashes = USER_TAGS.order(:tag_name).all

    tags = []
    tag_hashes.each do |tag|
      tags.push(UserTag.new(tag))
    end

    return tags
  end

  # Get the number of tags owned by the specified user.
  # @param [Integer] owner_user_id user to filter by
  # @return [Integer] number of owned tags
  def GetUserTagCount(owner_user_id)
    count = USER_TAGS.where(owner_user_id: owner_user_id).count
    return count.nil? ? 0 : count
  end

  # Get all of the tags owned by the specified user.
  # @param [Integer] owner_user_id user to filter by
  # @return [Array<UserTag>] All tags owned by the specified user.
  def GetAllUserTags(owner_user_id)
    tag_hashes = USER_TAGS.where(owner_user_id: owner_user_id).order(:tag_name).all

    tags = []
    tag_hashes.each do |tag|
      tags.push(UserTag.new(tag))
    end

    return tags
  end
end