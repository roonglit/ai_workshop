class Message < ApplicationRecord
  # step1: basic associations
  belongs_to :chat

  # step2: integrate RubyLLM (comment out step1)
  # acts_as_message tool_calls_foreign_key: :message_id
  # has_many_attached :attachments
end
