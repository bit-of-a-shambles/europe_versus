import { Controller } from "@hotwired/stimulus"

// Scroll-triggered staggered reveal, after the "texts reveal" transition
// on transitions.dev: rows rise into place as they enter the viewport,
// each a little later than the one before. Elements are visible by default
// and only animate under prefers-reduced-motion: no-preference, so nothing
// is ever hidden from readers or search engines without JavaScript.
export default class extends Controller {
  static targets = [ "item" ]

  connect() {
    if (this.itemTargets.length === 0) return
    if (!("IntersectionObserver" in window)) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.itemTargets.forEach((item, index) => {
      item.style.setProperty("--reveal-index", Math.min(index, 6))
      item.classList.add("scroll-reveal")
    })

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-revealed")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { rootMargin: "0px 0px -12% 0px" }
    )

    this.itemTargets.forEach((item) => this.observer.observe(item))
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}