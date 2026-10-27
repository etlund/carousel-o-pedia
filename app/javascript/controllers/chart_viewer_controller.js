import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["controls", "button", "label", "inline", "chart", "dialog"]

  connect() {
    this.controlsTarget.hidden = false
  }

  toggle() {
    if (this.dialogTarget.open) {
      this.close()
    } else {
      this.dialogTarget.append(this.chartTarget)
      this.labelTarget.textContent = "Close expanded view"
      this.buttonTarget.setAttribute("aria-expanded", "true")
      this.dialogTarget.showModal()
    }
  }

  close() {
    if (!this.dialogTarget.open) return

    this.dialogTarget.close()
    this.restore()
  }

  restore() {
    if (this.dialogTarget.open) return

    this.inlineTarget.append(this.chartTarget)
    this.labelTarget.textContent = "Expand chart"
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.buttonTarget.focus()
  }
}
