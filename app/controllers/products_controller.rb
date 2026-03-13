class ProductsController < ApplicationController
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

  private

  # step2_2: use LLM to extract keywords, then search with ProductQuery
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
end
