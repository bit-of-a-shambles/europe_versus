import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu" ]

  toggle(event) {
    const nowOpen = this.menuTarget.classList.toggle("hidden") === false
    this.element.classList.toggle("menu-open", nowOpen)

    const button = event.currentTarget || this.element.querySelector(".nav-toggle")
    if (button) {
      button.setAttribute("aria-expanded", nowOpen.toString())
      button.setAttribute("aria-label", nowOpen ? "Close navigation" : "Open navigation")
    }
  }
}