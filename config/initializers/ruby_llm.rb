RubyLLM.configure do |config|
  # config.openai_api_key = ENV['OPENAI_API_KEY'] || Rails.application.credentials.dig(:openai_api_key)
  # config.default_model = "gpt-4.1-nano"
  config.default_model = "anthropic/claude-sonnet-4.6"
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY'] || Rails.application.credentials.dig(:openrouter_api_key)

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
