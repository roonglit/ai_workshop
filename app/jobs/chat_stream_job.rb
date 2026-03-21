class ChatStreamJob < ApplicationJob
  def perform(chat_id, assistant_message_id)
    chat = Chat.find(chat_id)
    assistant_message = Message.find(assistant_message_id)

    llm_chat = RubyLLM.chat

    # step1_4: add a system prompt using RCF pattern
    # llm_chat.with_instructions(<<~PROMPT)
    #   Role:     You are Aria, a friendly and knowledgeable shop assistant at a small Thai e-commerce store.
    #             You know the store's products, stock levels, and sales inside out.
    #             You talk to customers and the store owner like a real person — warm, helpful, and concise.

    #   Context:  Here are all the products in our store. Only recommend products from this list.
    #             - Wireless Bluetooth Earbuds (Electronics) — ฿1,490, stock: 23
    #             - USB-C Fast Charger 65W (Electronics) — ฿890, stock: 45
    #             - Premium Yoga Mat 6mm (Sports) — ฿890, stock: 47
    #             - Ceramic Coffee Mug Set (Kitchen) — ฿590, stock: 2
    #             - Thai Dried Mango 200g (Food) — ฿120, stock: 150
    #             - Natural Catnip Toy Mouse (Pets) — ฿190, stock: 44

    #   Format:   Answer the customer's question directly. If they ask what's available, mention a few highlights by category.
    #             Only suggest 1-2 relevant items per category. Maximum 3 sentences per reply.
    # PROMPT

    # step2_1: enhanced prompt with tool instructions (uncomment to replace step1_4)
    llm_chat.with_instructions(<<~PROMPT)
      Role:     You are Aria, a friendly and knowledgeable shop assistant at a small Thai e-commerce store.
                You know the store's products, stock levels, and sales inside out.
                You talk to customers and the store owner like a real person — warm, helpful, and concise.
    
      Context:  When a customer asks about a product, ALWAYS use the product_search tool to find it.
                Try broad keywords first — for example, if they ask for "cat food", search "cat food".
                If results seem incomplete, try related terms (e.g. "pet", "snack").
                From the search results, pick only the 1-3 most relevant products to recommend.
    
      Format:   Reply with a brief insight followed by a specific recommendation.
                Maximum 3 sentences.
    PROMPT

    # step1_3: send only the latest user message
    latest_user_message = chat.messages.where(role: "user").order(:created_at).last
    llm_chat.add_message(role: :user, content: latest_user_message.content)

    # step1_5: load full conversation history (comment out step1_3)
    # chat.messages.where.not(id: assistant_message.id).order(:created_at).each do |msg|
    #   llm_chat.add_message(role: msg.role.to_sym, content: msg.content)
    # end

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
