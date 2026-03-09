class ChatsController < ApplicationController
  def show
    @chat = Chat.order(:created_at).last
    @messages = @chat&.messages&.order(created_at: :asc) || []
  end

  def create
    @chat = Chat.first_or_create!

    # step1: basic response, no LLM
    # @user_message = @chat.messages.create!(role: "user", content: chat_params[:content])
    # @assistant_message = @chat.messages.create!(role: "assistant", content: "This is a placeholder response. LLM integration coming soon!")

    # step2: call LLM with RubyLLM (comment out step1)
    @chat.ask(chat_params[:content])
    @user_message      = @chat.messages.second_to_last
    @assistant_message = @chat.messages.last

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to chat_path }
    end
  end

  def clear
    Chat.destroy_all

    respond_to do |format|
      format.turbo_stream { redirect_to chat_path }
      format.html { redirect_to chat_path }
    end
  end

  private

  def chat_params
    params.expect(message: [:content])
  end
end
