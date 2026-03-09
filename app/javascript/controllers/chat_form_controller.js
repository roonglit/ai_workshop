import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "messagesContainer"]

  connect() {
    this.scrollToBottom()

    // Hook into turbo:before-stream-render to run code AFTER the stream renders
    this.handleStreamRender = (event) => {
      const originalRender = event.detail.render
      event.detail.render = (streamElement) => {
        originalRender(streamElement)
        // Now the DOM is updated — scroll and reset
        requestAnimationFrame(() => {
          this.scrollToBottom()
          this.resetForm()
        })
      }
    }

    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)

    // step3: observe DOM changes for streaming updates and auto-scroll
    this.observer = new MutationObserver(() => this.scrollToBottom())
    const messagesEl = document.getElementById("messages")
    if (messagesEl) {
      this.observer.observe(messagesEl, { childList: true, subtree: true, characterData: true })
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)
    if (this.observer) this.observer.disconnect()
  }

  autoResize() {
    const textarea = this.textareaTarget
    textarea.style.height = "auto"
    textarea.style.height = Math.min(textarea.scrollHeight, 200) + "px"
  }

  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      const content = this.textareaTarget.value.trim()
      if (content.length > 0) {
        this.textareaTarget.closest("form").requestSubmit()
      }
    }
  }

  resetForm() {
    const textarea = this.element.querySelector("textarea[data-chat-form-target='textarea']")
    if (textarea) {
      textarea.value = ""
      textarea.style.height = "auto"
      textarea.focus()
    }
  }

  scrollToBottom() {
    const container = this.hasMessagesContainerTarget
      ? this.messagesContainerTarget
      : document.getElementById("messages-container")

    if (container) {
      container.scrollTop = container.scrollHeight
    }
  }
}
