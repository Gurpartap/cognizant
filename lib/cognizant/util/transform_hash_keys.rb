class Hash
  # Destructively convert all keys by using the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes.
  def deep_transform_keys!(&block)
    keys.each do |key|
      value = delete(key)
      self[yield(key)] = value.is_a?(Hash) ? value.deep_transform_keys!(&block) : value
    end
    self
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to `to_sym`. This includes the keys from the root hash and from all
  # nested hashes.
  def deep_symbolize_keys!
    deep_transform_keys!{ |key| key.to_sym rescue key }
  end

  # Destructively convert all dashes in keys to underscores and then
  # the keys to symbols, as long as they respond to `to_sym`.
  # This includes the keys from the root hash and from all nested hashes.
  def deep_flatten_dashes_and_symbolize_keys!
    deep_transform_keys!{ |key| key.gsub("-", "_").to_sym  rescue key }
  end
end
