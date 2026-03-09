class ChatStreamJob < ApplicationJob
  def perform(chat_id, assistant_message_id)
    chat = Chat.find(chat_id)
    assistant_message = Message.find(assistant_message_id)

    # Build conversation history from persisted messages (exclude the empty assistant placeholder)
    llm_chat = RubyLLM.chat
    chat.messages.where.not(id: assistant_message.id).order(:created_at).each do |msg|
      llm_chat.add_message(role: msg.role.to_sym, content: msg.content)
    end

    # Stream the response, broadcasting each chunk
    accumulated_content = ""

    llm_chat.complete do |chunk|
      accumulated_content += chunk.content if chunk.content

      Turbo::StreamsChannel.broadcast_update_to(
        chat,
        target: "message_content_#{assistant_message.id}",
        html: accumulated_content
      )
    end

    # Save the final response
    assistant_message.update!(content: accumulated_content)
  end
end
