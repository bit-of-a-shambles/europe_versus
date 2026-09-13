import { Controller } from "@hotwired/stimulus"

// Sliding pill indicator for the data-library category nav, after the
// "tabs sliding" transition on transitions.dev: a burgundy underline that
// glides between the active category link. The active link follows both
// clicks and a scrollspy on the category sections, so the pill always
// reflects where the reader actually is.
export default class extends Controller {
  connect() {
    this.links = [...this.element.querySelectorAll("a")]
    if (this.links.length === 0) return

    this.pill = document.createElement("span")
    this.pill.className = "library-nav-pill"
    this.pill.setAttribute("aria-hidden", "true")
    this.element.prepend(this.pill)

    this.active = null
    this.links.forEach((link) => {
      link.addEventListener("click", () => this.setActive(link, false))
    })

    const sections = this.links
      .map((link) => document.querySelector(link.getAttribute("href")))
      .filter(Boolean)

    if (sections.length > 0 && "IntersectionObserver" in window) {
      this.observer = new IntersectionObserver(
        (entries) => {
          const visible = entries
            .filter((entry) => entry.isIntersecting)
            .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0]
          if (!visible) return

          const link = this.links.find(
            (link) => link.getAttribute("href") === `#${visible.target.id}`
          )
          if (link) this.setActive(link, true)
        },
        { rootMargin: "-30% 0px -55% 0px" }
      )
      sections.forEach((section) => this.observer.observe(section))
    }

    this.setActive(this.links[0], false)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.pill) this.pill.remove()
  }

  setActive(link, fromScroll) {
    if (this.active === link) return
    this.active = link
    this.links.forEach((other) => other.removeAttribute("aria-current"))
    link.setAttribute("aria-current", "true")
    this.movePill(link, fromScroll)
  }

  movePill(link, animate) {
    if (!this.pill) return
    if (!animate) this.pill.style.transition = "none"
    this.pill.style.width = `${link.offsetWidth}px`
    this.pill.style.transform = `translateX(${link.offsetLeft}px)`
    if (!animate) {
      requestAnimationFrame(() => { this.pill.style.transition = "" })
    }
  }
}