require "test_helper"

class ProductSearchTest < ActiveSupport::TestCase
  setup do
    @tool = ProductSearch.new
  end

  # --- Single keyword searches ---

  test "finds products by name" do
    result = @tool.execute(query: "Yoga")
    assert_includes result, "Non-Slip Yoga Mat"
  end

  test "finds products by category" do
    result = @tool.execute(query: "Pets")
    assert_includes result, "Premium Cat Food"
    assert_includes result, "Rubber Dog Ball"
    assert_includes result, "Salmon Cat Treats"
  end

  test "finds products by tag" do
    result = @tool.execute(query: "salmon")
    assert_includes result, "Salmon Cat Treats"
  end

  test "finds products by description keyword" do
    result = @tool.execute(query: "ceramic")
    assert_includes result, "Ceramic Coffee Mug"
  end

  test "search is case-insensitive" do
    result = @tool.execute(query: "cat")
    assert_includes result, "Premium Cat Food"
    assert_includes result, "Salmon Cat Treats"
  end

  # --- Multi-word queries ---

  test "multi-word query matches products containing any keyword" do
    result = @tool.execute(query: "cat food")
    assert_includes result, "Premium Cat Food"
    assert_includes result, "Salmon Cat Treats"  # matches "cat"
  end

  test "multi-word query casts a wide net" do
    result = @tool.execute(query: "wireless charger")
    assert_includes result, "Wireless Phone Charger"
  end

  # --- Category filter ---

  test "filters results by category" do
    result = @tool.execute(query: "fitness", category: "Sports")
    assert_includes result, "Yoga Mat"
    assert_includes result, "Running Shoes"
    refute_includes result, "Cat"
  end

  test "category filter with no matching query returns no products" do
    result = @tool.execute(query: "zzzznotfound", category: "Sports")
    assert_equal "No products found matching 'zzzznotfound'.", result
  end

  # --- No results ---

  test "returns not found message for unmatched query" do
    result = @tool.execute(query: "unicorn")
    assert_equal "No products found matching 'unicorn'.", result
  end

  # --- Result format ---

  test "result includes product ID, name, category, price, stock, and description" do
    result = @tool.execute(query: "Yoga")
    assert_match(/\[ID:\d+\]/, result)
    assert_includes result, "Sports"
    assert_includes result, "฿599"
    assert_includes result, "8 in stock"
  end

  test "result includes found count header" do
    result = @tool.execute(query: "cat")
    assert_match(/Found \d+ products/, result)
  end

  # --- Limit ---

  test "returns at most 20 products" do
    result = @tool.execute(query: "a")  # broad query likely to match many
    product_lines = result.lines.select { |l| l.start_with?("[ID:") }
    assert product_lines.size <= 20
  end

  # --- Edge cases ---

  test "includes out-of-stock products in results" do
    result = @tool.execute(query: "notebook")
    assert_includes result, "Limited Edition Notebook"
    assert_includes result, "0 in stock"
  end

  test "works with partial word match" do
    result = @tool.execute(query: "charg")
    assert_includes result, "Wireless Phone Charger"
  end

  # --- Natural language queries ---

  test "natural question about cat food finds relevant pet products" do
    result = @tool.execute(query: "persia cat good food")
    assert_includes result, "Premium Cat Food"
    assert_includes result, "Salmon Cat Treats"
    refute_includes result, "Rubber Dog Ball"
  end

  test "natural question about gifts for a runner finds sports products" do
    result = @tool.execute(query: "gift for runner")
    assert_includes result, "Lightweight Running Shoes"
  end

  test "natural question about drinks finds kitchen products" do
    result = @tool.execute(query: "something for hot drinks")
    assert_includes result, "Ceramic Coffee Mug"
  end
end
