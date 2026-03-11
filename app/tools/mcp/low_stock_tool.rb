class Mcp::LowStockTool < MCP::Tool
  description "Get products with low stock (below a threshold). Useful for inventory management and restocking decisions."

  input_schema(
    properties: {
      threshold: { type: "integer", description: "Stock threshold (default: 10). Products with stock below this number are returned." }
    }
  )

  class << self
    def call(server_context:, threshold: 10, **_args)
      products = Product.where("stock < ?", threshold).order(:stock, :name)

      if products.empty?
        return MCP::Tool::Response.new([{
          type: "text",
          text: "All products have stock above #{threshold} units."
        }])
      end

      summary = "Found #{products.count} products with stock below #{threshold}:\n\n"
      summary += products.map { |p|
        "#{p.name} (#{p.category}) — #{p.stock} left, ฿#{p.price.to_i}"
      }.join("\n")

      MCP::Tool::Response.new([{ type: "text", text: summary }])
    end
  end
end
