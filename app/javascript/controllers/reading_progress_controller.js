import { Controller } from "@hotwired/stimulus"

// Fills a thin passport-burgundy rule at the top of the viewport as the
// reader progresses through a canonical edition. Pure scroll feedback:
// the bar tracks scroll position directly, with no easing or looping
// animation, and does nothing when the article is shorter than the viewport.
export default class extends Controller {
  static targets = [ "bar" ]

  connect() {
    this.update = this.update.bind(this)
    window.addEventListener("scroll", this.update, { passive: true })
    window.addEventListener("resize", this.update, { passive: true })
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.update)
    window.removeEventListener("resize", this.update)
  }

  update() {
    const documentElement = document.documentElement
    const scrollable = documentElement.scrollHeight - window.innerHeight

    if (scrollable <= 0) {
      this.barTarget.style.transform = "scaleX(0)"
      return
    }

    const progress = Math.min(window.scrollY / scrollable, 1)
    this.barTarget.style.transform = `scaleX(${progress})`
  }
}