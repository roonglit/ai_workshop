class Product < ApplicationRecord
  def to_mcp_response
    <<~TEXT
      Product ##{id}: #{name}
      Category: #{category}
      Price: ฿#{price}
      Stock: #{stock} units
      Tags: #{tags}
      Description: #{description}
    TEXT
  end
end
