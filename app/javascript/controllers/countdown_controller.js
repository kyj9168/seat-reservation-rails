import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = { expiresAt: String }

  connect() {
    this.render()
    this.timer = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const remaining = Math.max(0, new Date(this.expiresAtValue).getTime() - Date.now())
    const seconds = Math.floor(remaining / 1000)
    const minutesPart = String(Math.floor(seconds / 60)).padStart(2, "0")
    const secondsPart = String(seconds % 60).padStart(2, "0")
    this.outputTarget.textContent = `${minutesPart}:${secondsPart}`

    if (remaining === 0) {
      clearInterval(this.timer)
      window.location.reload()
    }
  }
}
