class Chat < ApplicationRecord
  # step1: basic associations
  has_many :messages, dependent: :destroy

  # step2: integrate RubyLLM (comment out step1)
  # acts_as_chat messages_foreign_key: :chat_id
end
