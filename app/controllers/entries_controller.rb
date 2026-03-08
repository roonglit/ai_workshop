class EntriesController < ApplicationController
  before_action :set_entry, only: %i[ show edit update destroy ]

  # GET /entries or /entries.json
  def index
    @entries = Entry.order(created_at: :asc)
    @entry = Entry.new
  end

  # GET /entries/1 or /entries/1.json
  def show
  end

  # GET /entries/new
  def new
    @entry = Entry.new
  end

  # GET /entries/1/edit
  def edit
  end

  # POST /entries or /entries.json
  def create
    @entry = Entry.new(entry_params)

    respond_to do |format|
      if @entry.save
        # step1: basic response, no LLM
        # @reply = Entry.create!(role: :assistant, content: "This is a placeholder response. LLM integration coming soon!")

        # step2: basic LLM reponse
        chat = RubyLLM.chat
        response = chat.ask(@entry.content)
        @reply = Entry.create!(role: :assistant, content: response.content)

        format.turbo_stream
        format.html { redirect_to entries_path }
        format.json { render :show, status: :created, location: @entry }
      else
        format.html { redirect_to entries_path }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /entries/1 or /entries/1.json
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        format.html { redirect_to @entry, notice: "Entry was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @entry }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /entries/clear_all
  def clear_all
    Entry.destroy_all

    respond_to do |format|
      format.turbo_stream { redirect_to entries_path }
      format.html { redirect_to entries_path }
    end
  end

  # DELETE /entries/1 or /entries/1.json
  def destroy
    @entry.destroy!

    respond_to do |format|
      format.html { redirect_to entries_path, notice: "Entry was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_entry
      @entry = Entry.find(params.expect(:id))
    end

    def entry_params
      params.expect(entry: [ :content, :role ])
    end
end
