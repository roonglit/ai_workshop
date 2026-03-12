class ProductSearch < RubyLLM::Tool
  description "Search for products in the store by name, category, or keyword. Use this to help customers find products."

  param :query, desc: "Search keywords — can be a product name, type, use case, or multiple words (e.g. 'cat food', 'wireless charger', 'gift for runner')"
  param :category, desc: "Filter by category: Electronics, Sports, Kitchen, Home, Fashion, Beauty, Stationery, Food, Pets", required: false

  def execute(query:, category: nil)
    keywords = query.split(/\s+/)

    conditions = keywords.map do |kw|
      "name LIKE :#{kw_param(kw)} OR category LIKE :#{kw_param(kw)} OR tags LIKE :#{kw_param(kw)} OR description LIKE :#{kw_param(kw)}"
    end

    params = keywords.each_with_object({}) do |kw, h|
      h[kw_param(kw).to_sym] = "%#{kw}%"
    end

    products = Product.where(conditions.join(" OR "), **params)
    products = products.where(category: category) if category.present?
    products = products.limit(20)

    return "No products found matching '#{query}'." if products.empty?

    result = products.map do |p|
      "[ID:#{p.id}] #{p.name} (#{p.category}) — ฿#{p.price.to_i}, #{p.stock} in stock: #{p.description}"
    end.join("\n")

    "Found #{products.size} products. Review ALL results below and recommend only the most relevant ones to the customer.\n\n#{result}"
  end

  private

  def kw_param(keyword)
    "kw_#{keyword.gsub(/[^a-zA-Z0-9]/, '')}"
  end
end
