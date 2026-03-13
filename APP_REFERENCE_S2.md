# Session 2 — Products, Search & MCP Reference

## 1. Models

### Product (`app/models/product.rb`)

```ruby
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
```

No validations. No associations.

### Schema — `products` table

| Column | Type | Notes |
|--------|------|-------|
| `id` | integer | PK |
| `name` | string | |
| `category` | string | |
| `description` | text | |
| `price` | decimal | Thai baht |
| `stock` | integer | |
| `tags` | string | Comma-separated |
| `image_url` | string | Unsplash URL |
| `created_at` | datetime | |
| `updated_at` | datetime | |

---

## 2. ProductQuery Module (`app/models/product_query.rb`)

```ruby
module ProductQuery
  def self.search(query)
    return Product.none if query.blank?

    keywords = query.strip.split(/\s+/)

    conditions = keywords.map { |kw|
      sanitized = ActiveRecord::Base.sanitize_sql_like(kw)
      pattern = "%#{sanitized}%"
      Product.sanitize_sql_array([
        "name LIKE ? OR description LIKE ? OR tags LIKE ? OR category LIKE ?",
        pattern, pattern, pattern, pattern
      ])
    }

    Product.where(conditions.join(" OR "))
  end
end
```

### Example output

```ruby
ProductQuery.search("cooling")
# => [Cooling Towel (2 Pack)] — 1 result

ProductQuery.search("summer")
# => [Bluetooth Speaker Waterproof, Cooling Towel (2 Pack), Camping Hammock with Mosquito Net,
#     Polarized Sunglasses — Bamboo Frame, Cotton Bucket Hat, Aloe Vera Gel — Organic 250ml,
#     Cold Brew Coffee Concentrate 500ml] — 7 results

ProductQuery.search("I want something for a hot day")
# => 51 results (matches common words like "a", "for" across all descriptions — noisy)
```

---

## 3. Products Page

### URL: `GET /products`

- Shows all 51 products in a 3-column grid
- Each card: image, category badge, stock count, name, truncated description, price, tags
- Search box at top with query param `?query=...`
- Checkbox: "LLM-enhanced search" → adds `&llm=1`
- When LLM mode is on, extracted keywords shown as orange badges

---

## 4. Step 2_1 — Basic Keyword Search

### Controller code (`app/controllers/products_controller.rb`)

```ruby
def index
  @products = Product.all
  @llm_mode = params[:llm] == "1"

  if params[:query].present?
    if @llm_mode
      # step2_2: search with LLM keyword extraction
      @products, @llm_keywords = llm_search(params[:query])
    else
      # step2_1: search with SQL LIKE
      @products = ProductQuery.search(params[:query])
    end
  end

  @products = @products.order(:category, :name)
end
```

### How it works

1. User types a keyword in the search box (e.g., "cooling")
2. `ProductQuery.search("cooling")` runs SQL LIKE across name, description, tags, category
3. Returns matching products — direct keyword match, no LLM

### Test results

| Query | Results |
|-------|---------|
| `cooling` | 1 product: Cooling Towel (2 Pack) |
| `I want something for a hot day` | 51 products (noisy — common words match everything) |

---

## 5. Step 2_2 — LLM-Enhanced Search

### Controller code

```ruby
def llm_search(query)
  response = RubyLLM.chat.ask(<<~PROMPT)
    Extract 2-4 product search keywords from this customer query.
    Query: "#{query}"

    Return ONLY a comma-separated list of single keywords.
    Example: cooling,linen,outdoor,lightweight
    No explanation. No punctuation other than commas.
  PROMPT

  keywords = response.content.split(",").map(&:strip)
  ids = keywords.flat_map { |kw| ProductQuery.search(kw).pluck(:id) }.uniq
  products = ids.empty? ? Product.none : Product.where(id: ids)

  [ products, keywords ]
end
```

### How it works

1. User types a natural language phrase (e.g., "I want something for a hot day")
2. Checkbox "LLM-enhanced search" must be checked (`params[:llm] == "1"`)
3. `RubyLLM.chat.ask(...)` sends the phrase to the LLM with extraction prompt
4. LLM returns keywords like `cooling,refreshing,summer,lightweight`
5. Each keyword is passed to `ProductQuery.search(kw)`
6. Results are merged (unique by ID)
7. Keywords shown as orange badges on the page

### Full prompt sent to the LLM

```
Extract 2-4 product search keywords from this customer query.
Query: "I want something for a hot day"

Return ONLY a comma-separated list of single keywords.
Example: cooling,linen,outdoor,lightweight
No explanation. No punctuation other than commas.
```

### Test results

| Query (LLM mode) | LLM Keywords | Results |
|-------------------|-------------|---------|
| `I want something for a hot day` | `cooling, refreshing, summer, lightweight` | 9 products: Aloe Vera Gel, Bluetooth Speaker Waterproof, Cotton Bucket Hat, Polarized Sunglasses, Cold Brew Coffee, Camping Hammock, Cooling Towel, Hiking Backpack, Jump Rope |

### Comparison: basic vs LLM search

| Query | Basic search | LLM search |
|-------|-------------|------------|
| `cooling` | 1 result (exact match) | N/A — use basic for exact keywords |
| `I want something for a hot day` | 51 results (noisy) | 9 results (relevant: cooling, summer, outdoor items) |

---

## 6. MCP Tools

### Configuration

MCP endpoint: `POST /mcp` (JSON-RPC 2.0)

```ruby
# app/controllers/mcp_controller.rb
class McpController < ActionController::API
  def handle
    if params[:method] == "notifications/initialized"
      head :accepted
    else
      render json: mcp_server.handle_json(request.body.read)
    end
  end

  private

  def mcp_server
    MCP::Server.new(
      name: "ai_workshop_mcp_server",
      version: "1.0.0",
      tools: [
        Mcp::ProductSearchTool,
        Mcp::LowStockTool,
        Mcp::CategorySummaryTool
      ],
      prompts: MCP::Prompt.descendants
    )
  end
end
```

### Tool 1: `product_search_tool`

**Class**: `Mcp::ProductSearchTool` (`app/tools/mcp/product_search_tool.rb`)

**Description**: Search and list products from the Thai ecommerce store

**Input schema**:
```json
{
  "properties": {
    "query": { "type": "string", "description": "Search by name, description, or tags" }
  },
  "type": "object"
}
```

**curl test**:
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"product_search_tool","arguments":{"query":"hot weather"}}}'
```

**Example output**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [{
      "type": "text",
      "text": "Product #63: Cooling Towel (2 Pack)\nCategory: Sports\nPrice: ฿199.0\nStock: 120 units\nTags: cooling, outdoor, summer, gym, running, heat relief\nDescription: Instant cooling towel that activates when wet. UPF 50 sun protection. Perfect for workouts, running, and hot weather.\n"
    }],
    "isError": false
  }
}
```

### Tool 2: `low_stock_tool`

**Class**: `Mcp::LowStockTool` (`app/tools/mcp/low_stock_tool.rb`)

**Description**: Get products with low stock (below a threshold). Useful for inventory management and restocking decisions.

**Input schema**:
```json
{
  "properties": {
    "threshold": { "type": "integer", "description": "Stock threshold (default: 10). Products with stock below this number are returned." }
  },
  "type": "object"
}
```

**curl test**:
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"low_stock_tool","arguments":{}}}'
```

**Example output**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [{
      "type": "text",
      "text": "Found 8 products with stock below 10:\n\nCold Brew Coffee Concentrate 500ml (Food) — 1 left, ฿280\nCeramic Coffee Mug Set (4 Pack) (Kitchen) — 2 left, ฿590\nBluetooth Speaker Waterproof (Electronics) — 3 left, ฿990\nPolarized Sunglasses — Bamboo Frame (Fashion) — 4 left, ฿590\nCamping Hammock with Mosquito Net (Sports) — 5 left, ฿790\nHandwoven Silk Scarf (Fashion) — 7 left, ฿1290\niPhone 15 Silicone Case (Electronics) — 8 left, ฿299\nJapanese Chef Knife 8 inch (Kitchen) — 9 left, ฿1890"
    }],
    "isError": false
  }
}
```

### Tool 3: `category_summary_tool`

**Class**: `Mcp::CategorySummaryTool` (`app/tools/mcp/category_summary_tool.rb`)

**Description**: Get a summary of products by category: count, average price, and total stock. Useful for business overview and category analysis.

**Input schema**:
```json
{
  "properties": {},
  "type": "object"
}
```

**curl test**:
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"category_summary_tool","arguments":{}}}'
```

**Example output**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [{
      "type": "text",
      "text": "Category Summary (51 total products):\n\nBeauty: 5 products, avg ฿234, 480 total stock\nElectronics: 8 products, avg ฿1111, 167 total stock\nFashion: 5 products, avg ฿642, 183 total stock\nFood: 6 products, avg ฿180, 461 total stock\nHome: 6 products, avg ฿443, 230 total stock\nKitchen: 7 products, avg ฿750, 202 total stock\nPets: 3 products, avg ฿323, 101 total stock\nSports: 7 products, avg ฿666, 406 total stock\nStationery: 4 products, avg ฿355, 204 total stock"
    }],
    "isError": false
  }
}
```

---

## 7. Routes

```ruby
# config/routes.rb
resources :products, only: [:index]

resource :chat, only: [:show, :create] do
  delete :clear, on: :member
end

match "/mcp", to: "mcp#handle", via: [:get, :post, :delete, :options]

root "chats#show"
```

| HTTP Method | Path | Action | Purpose |
|-------------|------|--------|---------|
| GET | `/products` | `products#index` | Products page with search |
| GET, POST, DELETE, OPTIONS | `/mcp` | `mcp#handle` | MCP JSON-RPC endpoint |
| GET | `/` | `chats#show` | Chat page (root) |
| GET | `/chat` | `chats#show` | Chat page |
| POST | `/chat` | `chats#create` | Send message |
| DELETE | `/chat/clear` | `chats#clear` | Clear chat |

---

## 8. Seeds (`db/seeds.rb`)

51 products across 9 categories:

| Category | Count | Price range | Stock pattern |
|----------|-------|-------------|---------------|
| Electronics | 8 | ฿299–2,490 | 3–45 (Speaker at 3 = low stock) |
| Sports | 7 | ฿199–1,690 | 5–120 (Hammock at 5 = low stock) |
| Kitchen | 7 | ฿350–1,890 | 2–56 (Mug Set at 2 = critical) |
| Home | 6 | ฿250–690 | 16–67 |
| Fashion | 5 | ฿290–1,290 | 4–91 (Sunglasses at 4 = low stock) |
| Beauty | 5 | ฿150–320 | 36–200 |
| Stationery | 4 | ฿190–590 | 19–88 |
| Food | 6 | ฿89–280 | 1–150 (Cold Brew at 1 = critical) |
| Pets | 3 | ฿190–490 | 26–44 |

**Planted patterns for learners**:
- 8 products below stock 10 (inventory alerts)
- Tags are comma-separated strings enabling keyword search
- Categories span different price tiers
- Some products tagged "summer", "outdoor", "cooling" — good for LLM search demos

---

## 9. How to Reset for Class

```bash
# 1. Reset database
bin/rails db:reset          # drops, creates, migrates, seeds

# 2. Clear chat history (if needed)
bin/rails runner "Chat.destroy_all"

# 3. Verify product count
bin/rails runner "puts Product.count"   # Should be 51

# 4. Start server
bin/rails server

# 5. Verify endpoints
curl http://localhost:3000/products          # Products page
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'   # MCP tools list
```

---

## 10. Claude Desktop / MCP Inspector Config

### MCP endpoint URL

```
http://localhost:3000/mcp
```

### Claude Desktop config (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "ai_workshop": {
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

### MCP Inspector

1. Open MCP Inspector
2. Set transport type: **Streamable HTTP**
3. URL: `http://localhost:3000/mcp`
4. Click Connect
5. Go to Tools tab to see all 3 tools
6. Test each tool with the arguments shown in Section 6

### Available MCP tools (as seen by Claude Desktop)

| Tool name | Description |
|-----------|-------------|
| `product_search_tool` | Search and list products from the Thai ecommerce store |
| `low_stock_tool` | Get products with low stock (below a threshold) |
| `category_summary_tool` | Get a summary of products by category |
