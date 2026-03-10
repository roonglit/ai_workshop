class Products::IndexTool < MCP::Tool
  description "Search and list products from the Thai ecommerce store"

  input_schema(
    properties: {
      query: { type: "string", description: "Search by name, description, or tags" }
    }
  )

  class << self
    def call(server_context:, query: nil, **_args)
      products = Product.order(:category, :name)
      if query.present?
        q = "%#{query.strip}%"
        products = products.where(
          "LOWER(name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?) OR LOWER(tags) LIKE LOWER(?)",
          q, q, q
        )
      end

      MCP::Tool::Response.new([{
        type: "text",
        text: products.map(&:to_mcp_response).join("\n\n")
      }])
    end
  end
end
