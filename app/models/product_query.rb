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
