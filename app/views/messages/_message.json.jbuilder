json.extract! message, :id, :content, :role, :created_at, :updated_at
json.url message_url(message, format: :json)
