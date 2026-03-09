class ChatsController < ApplicationController
  def show
    @chat = Chat.order(:created_at).last
    @messages = @chat&.messages&.order(created_at: :asc) || []
  end

  def create
    @chat = Chat.first_or_create!
    @chat.ask(chat_params[:content])

    @user_message = @chat.messages.where(role: "user").order(:created_at).last
    @assistant_message = @chat.messages.where(role: "assistant").order(:created_at).last

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
