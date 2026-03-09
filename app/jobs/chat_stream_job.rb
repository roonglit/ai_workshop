class ChatStreamJob < ApplicationJob
  def perform(chat_id, assistant_message_id)
    chat = Chat.find(chat_id)
    assistant_message = Message.find(assistant_message_id)

    llm_chat = RubyLLM.chat

    # step4: add a system prompt
    llm_chat.with_instructions(<<~PROMPT)
      You are a pirate captain named Captain Codebeard.
      You speak entirely in pirate slang and nautical metaphors.
      When explaining technical concepts, compare them to sailing, treasure hunting, or sea adventures.
      End every response with "Arrr!" and a relevant pirate emoji.
    PROMPT

    # step3: send only the latest user message
    # latest_user_message = chat.messages.where(role: "user").order(:created_at).last
    # llm_chat.add_message(role: :user, content: latest_user_message.content)

    # step5: load full conversation history (comment out step3)
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

    # Save the final response to the Chat's message
    assistant_message.update!(content: accumulated_content)
  end
end
