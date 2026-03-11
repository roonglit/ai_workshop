class ProductSearch < RubyLLM::Tool
  description "Search for products in the store by name, category, or keyword. Use this to help customers find products."

  param :query, desc: "A single keyword to search for (e.g. 'coffee', 'knife', 'outdoor'). Use ONE word at a time for best results."
  param :category, desc: "Filter by category: Electronics, Sports, Kitchen, Home, Fashion, Beauty, Stationery, Food, Pets", required: false

  def execute(query:, category: nil)
    products = Product.where(
      "name LIKE :q OR category LIKE :q OR tags LIKE :q OR description LIKE :q",
      q: "%#{query}%"
    )

    products = products.where(category: category) if category.present?
    products = products.limit(5)

    return "No products found matching '#{query}'." if products.empty?

    products.map do |p|
      "[ID:#{p.id}] #{p.name} (#{p.category}) — ฿#{p.price.to_i}, #{p.stock} in stock: #{p.description}"
    end.join("\n")
  end
end
