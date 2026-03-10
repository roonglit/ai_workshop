class ProductsController < ApplicationController
  def index
    @products = Product.all.order(:category, :name)
  end
end
