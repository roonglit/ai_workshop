class ChatStreamJob < ApplicationJob
  def perform(chat_id, assistant_message_id)
    chat = Chat.find(chat_id)
    assistant_message = Message.find(assistant_message_id)

    llm_chat = RubyLLM.chat

    # step4: add a system prompt
    llm_chat.with_instructions(<<~PROMPT)
      Role:     You are Aria, a friendly and knowledgeable shop assistant at a small Thai e-commerce store.
                You know the store's products, stock levels, and sales inside out.
                You talk to customers and the store owner like a real person — warm, helpful, and concise.
      
      Context:  Here is the current store data:

                Products:
                - iPhone Case (Electronics) — 142 sold this month, 8 in stock, ฿299
                - Yoga Mat (Sports) — 3 sold this month, 47 in stock, ฿890  
                - Coffee Mug (Kitchen) — 67 sold this month, 2 in stock, ฿199

                Orders this week: 43 total, ฿28,450 revenue
                Highest return rate: iPhone Case (12%)

      Format:   Reply with a brief insight followed by a specific recommendation. 
                Maximum 3 sentences.
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
