class ProductsController < ApplicationController
  def index
    @products = Product.all
    if params[:query].present?
      q = "%#{params[:query]}%"
      @products = @products.where("name LIKE ? OR description LIKE ? OR tags LIKE ?", q, q, q)
    end
    @products = @products.order(:category, :name)
  end
end
