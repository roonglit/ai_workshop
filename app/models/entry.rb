class Entry < ApplicationRecord
  enum :role, { user: 0, assistant: 1 }

  validates :content, presence: true
end
