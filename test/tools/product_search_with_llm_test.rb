require "test_helper"

class ProductSearchWithLLMTest < ActiveSupport::TestCase
  setup do
    ProductSearch.clear_queries!
    @chat = RubyLLM.chat
    @chat.with_tool(ProductSearch)
    @chat.with_instructions(<<~PROMPT)
      Role:     You are a product search assistant for a Thai e-commerce store.

      Context:  You have access to a product search tool. Use it to find products matching
                the user's query. Think about what the user means — not just the exact words.
                Always use the tool — never guess product information.

      Format:   After searching, respond with ONLY the matching product IDs as comma-separated numbers.
                No duplicates. Example: 1,5,12
                If no products found, respond with: NONE
    PROMPT
  end

  test "persian cat food question finds cat food products" do
    ProductSearch.clear_queries!
    response = @chat.ask("I have a persian cat, what is a good food for her?")
    ids = response.content.scan(/\d+/).map(&:to_i)
    products = Product.where(id: ids)
    names = products.pluck(:name)
    queries = ProductSearch.last_queries

    puts "\n  Question: I have a persian cat, what is a good food for her?"
    puts "  LLM tool queries: #{queries.map { |q| q[:query] }.join(', ')}"
    puts "  Products found: #{names.join(', ')}"

    assert queries.any?, "Expected LLM to call the tool, but no queries were recorded"
    assert names.any? { |n| n.include?("Cat") },
      "Expected cat-related products, got: #{names.join(', ')}"
  end

  test "home workout question finds sports products" do
    ProductSearch.clear_queries!
    response = @chat.ask("I want to start working out at home, what do you have?")
    ids = response.content.scan(/\d+/).map(&:to_i)
    products = Product.where(id: ids)
    queries = ProductSearch.last_queries

    puts "\n  Question: I want to start working out at home, what do you have?"
    puts "  LLM tool queries: #{queries.map { |q| q[:query] }.join(', ')}"
    puts "  Products found: #{products.pluck(:name).join(', ')}"

    assert queries.any?, "Expected LLM to call the tool, but no queries were recorded"
    assert products.pluck(:category).include?("Sports"),
      "Expected Sports products, got: #{products.pluck(:name).join(', ')}"
  end

  test "coffee lover question finds mug" do
    ProductSearch.clear_queries!
    response = @chat.ask("I love drinking coffee every morning, anything nice for me?")
    ids = response.content.scan(/\d+/).map(&:to_i)
    products = Product.where(id: ids)
    queries = ProductSearch.last_queries

    puts "\n  Question: I love drinking coffee every morning, anything nice for me?"
    puts "  LLM tool queries: #{queries.map { |q| q[:query] }.join(', ')}"
    puts "  Products found: #{products.pluck(:name).join(', ')}"

    assert queries.any?, "Expected LLM to call the tool, but no queries were recorded"
    assert products.pluck(:name).any? { |n| n.downcase.include?("coffee") || n.downcase.include?("mug") },
      "Expected coffee/mug products, got: #{products.pluck(:name).join(', ')}"
  end

  test "dog owner question does not return cat products" do
    ProductSearch.clear_queries!
    response = @chat.ask("I have a golden retriever, what toys do you have?")
    ids = response.content.scan(/\d+/).map(&:to_i)
    products = Product.where(id: ids)
    queries = ProductSearch.last_queries

    puts "\n  Question: I have a golden retriever, what toys do you have?"
    puts "  LLM tool queries: #{queries.map { |q| q[:query] }.join(', ')}"
    puts "  Products found: #{products.pluck(:name).join(', ')}"

    assert queries.any?, "Expected LLM to call the tool, but no queries were recorded"
    assert products.pluck(:name).any? { |n| n.downcase.include?("dog") },
      "Expected dog products, got: #{products.pluck(:name).join(', ')}"
    refute products.pluck(:name).any? { |n| n.downcase.include?("cat food") },
      "Should not return cat food for dog query, got: #{products.pluck(:name).join(', ')}"
  end

  test "unavailable product returns no product IDs" do
    ProductSearch.clear_queries!
    response = @chat.ask("Do you sell furniture? I need a sofa.")
    ids = response.content.scan(/\d+/).map(&:to_i)
    products = Product.where(id: ids)
    queries = ProductSearch.last_queries

    puts "\n  Question: Do you sell furniture? I need a sofa."
    puts "  LLM tool queries: #{queries.map { |q| q[:query] }.join(', ')}"
    puts "  Products found: #{products.pluck(:name).join(', ').presence || '(none)'}"

    assert products.empty?,
      "Expected no matching products for furniture/sofa, got: #{products.pluck(:name).join(', ')}"
  end
end
