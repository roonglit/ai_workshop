class Mcp::CategorySummaryTool < MCP::Tool
  description "Get a summary of products by category: count, average price, and total stock. Useful for business overview and category analysis."

  input_schema(
    properties: {}
  )

  class << self
    def call(server_context:, **_args)
      summaries = Product.group(:category).select(
        "category",
        "COUNT(*) as product_count",
        "AVG(price) as avg_price",
        "SUM(stock) as total_stock"
      ).order(:category)

      lines = summaries.map { |s|
        "#{s.category}: #{s.product_count} products, avg ฿#{s.avg_price.round(0).to_i}, #{s.total_stock} total stock"
      }

      text = "Category Summary (#{Product.count} total products):\n\n" + lines.join("\n")

      MCP::Tool::Response.new([{ type: "text", text: text }])
    end
  end
end
