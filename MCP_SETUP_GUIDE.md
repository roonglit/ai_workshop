# MCP on Rails - Setup Guide for Thai Ecommerce App

## What is MCP?

**MCP (Model Context Protocol)** lets AI assistants (like Claude) connect to your Rails app and use its data through a standardized protocol. Think of it as giving AI a structured API to your app — with **tools** (actions it can call), **resources** (data it can read), and **prompts** (templates it can use).

Your app already has: Chat with RubyLLM, Products model (71 products), streaming via Turbo. MCP will expose your Products data so external AI clients can query your store.

---

## Reference Repo

- **GitHub**: https://github.com/pstrzalk/mcp-on-rails
- **License**: MIT
- **What it does**: Rails application template that adds MCP support to new or existing Rails apps
- **Two modes**: Plain (open endpoint) or OAuth-protected (Devise + Doorkeeper)

---

## Step-by-Step Implementation

### Step 1: Apply the MCP template to your existing app

```bash
# Clone the template repo
git clone https://github.com/pstrzalk/mcp-on-rails.git /tmp/mcp-on-rails

# Apply to your project (answer "n" for no OAuth — keep it simple first)
cd /Users/mac/developments/ai_workshop
rails app:template LOCATION=/tmp/mcp-on-rails/mcp
```

This will:
- Add the `mcp` gem to your Gemfile
- Create `app/controllers/mcp_controller.rb` — the `/mcp` endpoint
- Create `config/initializers/mcp.rb` — auto-loads tools from `app/tools/`
- Add MCP routes (POST/GET/DELETE/OPTIONS at `/mcp`)
- Extend `ApplicationRecord` with `to_mcp_response`

### Step 2: Generate MCP tools for Products

Since Products already exists (not scaffolded with MCP), generate tools manually:

```bash
rails generate mcp_tool Products::Show id:integer
rails generate mcp_tool Products::Index query:string
```

This creates files in `app/tools/products/`. You'll then customize them.

### Step 3: Customize the tools

**`app/tools/products/index_tool.rb`** — Search like the existing ProductsController:

```ruby
class Products::IndexTool < MCP::Tool
  description "Search and list products from the Thai ecommerce store"

  argument :query, type: "string", description: "Search by name, description, or tags", required: false

  def call(query: nil)
    products = Product.order(:category, :name)
    if query.present?
      products = products.where(
        "name LIKE ? OR description LIKE ? OR tags LIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
    end
    products.map(&:to_mcp_response).join("\n\n")
  end
end
```

**`app/tools/products/show_tool.rb`**:

```ruby
class Products::ShowTool < MCP::Tool
  description "Get details of a specific product by ID"

  argument :id, type: "integer", description: "Product ID", required: true

  def call(id:)
    product = Product.find(id)
    product.to_mcp_response
  end
end
```

### Step 4: Customize `to_mcp_response` on Product

In `app/models/product.rb`, add a method so MCP returns nicely formatted text:

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

### Step 5: Verify routes

After applying the template, `config/routes.rb` should have:

```ruby
match "/mcp", to: "mcp#handle", via: [:get, :post, :delete, :options]
```

### Step 6: Test it

```bash
rails server
```

**Initialize the MCP connection:**

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

**List available tools:**

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

**Call a tool (search products):**

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"products_index","arguments":{"query":"coffee"}}}'
```

**List registered tools via rake:**

```bash
rake mcp:tools
```

### Step 7: Connect an AI client

Add this MCP server config to Claude Desktop or any MCP-compatible client:

```json
{
  "mcpServers": {
    "local-geniusfoundr": {
      "command": "/Users/mac/.nvm/versions/node/v22.9.0/bin/npx",
      "args": [
        "mcp-remote",
        "http://192.168.100.209:3000/mcp",
        "--allow-http",
        "--keep-alive"
      ],
      "env": {
        "PATH": "/Users/mac/.nvm/versions/node/v22.9.0/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

Now Claude can search your products, look up details, etc.

---

## Architecture Overview

```
AI Client  ──StreamableHttp──▶  /mcp endpoint (McpController)
                                      │
                                      ▼
                               MCP gem routes JSON-RPC
                               to the right Tool class
                                      │
                                      ▼
                               Products::IndexTool#call
                                      │
                                      ▼
                               Product.where(...) → response
```

### Project structure after MCP setup

```
app/
├── controllers/
│   ├── chats_controller.rb          # Existing chat
│   ├── products_controller.rb       # Existing products
│   └── mcp_controller.rb            # NEW - MCP endpoint
├── models/
│   ├── product.rb                   # Updated with to_mcp_response
│   └── ...
├── tools/                           # NEW - MCP tools directory
│   └── products/
│       ├── index_tool.rb
│       └── show_tool.rb
config/
├── initializers/
│   ├── ruby_llm.rb                  # Existing
│   └── mcp.rb                       # NEW - tool autoloading
└── routes.rb                        # Updated with /mcp route
```

---

## Optional Next Steps

### More CRUD tools

Generate create/update/delete tools:

```bash
rails generate mcp_tool Products::Create name:string category:string price:number stock:integer
rails generate mcp_tool Products::Update id:integer name:string price:number stock:integer
rails generate mcp_tool Products::Delete id:integer
```

### Custom prompts

```bash
rails generate mcp_prompt product_recommender category:required budget:required
```

This creates `app/prompts/product_recommender.rb` inheriting from `MCP::Prompt`. Prompts are auto-loaded from `app/prompts/`.

### Add OAuth protection

Re-run the template and answer "y" to add Devise + Doorkeeper:

- Bearer token authentication on `/mcp`
- Dynamic client registration (RFC 7591)
- PKCE support (S256)
- Well-known metadata endpoints

### OAuth flow (if enabled)

1. Client fetches `GET /.well-known/oauth-protected-resource`
2. Client fetches `GET /.well-known/oauth-authorization-server`
3. Client registers via `POST /oauth/register`
4. Authorization request with PKCE at `GET /oauth/authorize`
5. Token exchange at `POST /oauth/token`
6. MCP requests with `Authorization: Bearer <token>`

---

## Key MCP Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| **Tool** | An action the AI can call | Search products, create order |
| **Resource** | Data the AI can read | Product catalog, inventory |
| **Prompt** | A template for AI interactions | Product recommender template |
| **Transport** | How AI connects to the server | StreamableHttp at `/mcp` |

## Useful Commands

| Command | Purpose |
|---------|---------|
| `rake mcp:tools` | List all registered MCP tools |
| `rake mcp:prompts` | List all registered MCP prompts |
| `rails generate mcp_tool Name field:type` | Generate a new tool |
| `rails generate mcp_prompt Name field:required` | Generate a new prompt |
