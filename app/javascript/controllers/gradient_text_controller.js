import { Controller } from "@hotwired/stimulus"

// Gradient text, recreated from transitions.dev's "pro gradient text":
// one element whose glyphs are filled by a large rainbow colour field
// orbiting in two dimensions (see .gradient-text in application.css).
//
// Values:
//   active   (default true)  — animated gradient text vs plain foreground
//   duration (default 10)    — seconds per orbit cycle
//   colours  (optional)      — full CSS gradient stop list, e.g.
//                              "#f0f 0%, #0ff 50%, #f0f 100%"
//                              overrides the default rainbow
//
// Actions:
//   gradient-text#toggle — flips the active state (layout never shifts)
export default class extends Controller {
  static values = {
    active: { type: Boolean, default: true },
    duration: { type: Number, default: 10 },
    colours: String
  }

  connect() {
    this.apply()
  }

  activeValueChanged() { this.apply() }
  durationValueChanged() { this.apply() }
  coloursValueChanged() { this.apply() }

  toggle() {
    this.activeValue = !this.activeValue
  }

  apply() {
    const el = this.element
    el.classList.add("gradient-text")
    el.classList.toggle("is-active", this.activeValue)
    el.style.setProperty("--gradient-duration", `${this.durationValue}s`)
    if (this.coloursValue) {
      el.style.setProperty("--gradient-stops", this.coloursValue)
    } else {
      el.style.removeProperty("--gradient-stops")
    }
  }
}