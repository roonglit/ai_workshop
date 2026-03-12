class ProductsController < ApplicationController
  def index
    @products = Product.all

    if params[:query].present?
      # step2_1: search with SQL LIKE
      # q = "%#{params[:query]}%"
      # @products = @products.where("name LIKE ? OR description LIKE ? OR tags LIKE ?", q, q, q)

      # step2_2: search with LLM tool
      @products, @llm_queries = llm_search(params[:query])

    end

    @products = @products.order(:category, :name)
  end

  private

  # step2_2: use LLM to interpret the search query and find matching products
  def llm_search(query)
    chat = RubyLLM.chat
    chat.with_tool(ProductSearch)
    chat.with_instructions(<<~PROMPT)
      Role:     You are a product search assistant for a Thai e-commerce store.

      Context:  You have access to a product search tool. Use it to find products matching
                the user's query. Think about what the user means — not just the exact words.
                For example, "kitchenware" should search for "knife", then "cooking", then "kitchen".
                IMPORTANT: Search with ONE word at a time. The tool uses text matching,
                so single keywords work best (e.g. "knife" not "kitchen knife").
                You may call the tool up to 3 times with different single-word terms to cover
                synonyms, related categories, or broader/narrower terms.
                Always use the tool — never guess product information.

      Format:   After searching, respond with ONLY the matching product IDs as comma-separated numbers.
                Combine results from all searches. No duplicates.
                Example: 1,5,12
                If no products found, respond with: NONE
    PROMPT

    queries = []
    chat.on_tool_call do |tool_call|
      queries << tool_call.arguments if tool_call.name == "product_search"
    end

    response = chat.ask(query)
    ids = response.content.scan(/\d+/).map(&:to_i)

    products = ids.empty? ? Product.none : Product.where(id: ids)
    [ products, queries ]
  end
end
