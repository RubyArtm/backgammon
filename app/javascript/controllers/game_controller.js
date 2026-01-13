import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["point"]

  connect() {
    this.fromPoint = null
    this.autoHideFlash()
    setTimeout(() => this.checkWinner(), 200)
    console.log("Backgammon Pro: Connected")
  }

  // Method of choosing a checker
  selectPoint(event) {
    const el = event.currentTarget
    const pointIndex = el.dataset.pointIndex

    // Check: Does this item contain checkers? (Look for any div with the checker class.)
    const hasCheckers = el.querySelector('.checker') !== null

    if (this.fromPoint === null) {
      if (!hasCheckers) return // Ignore clicking on empty space
      this.fromPoint = pointIndex
      this.highlight(el)
    } else {
      if (this.fromPoint === pointIndex) {
        this.clearHighlights()
        this.fromPoint = null
        return
      }
      this.movePiece(this.fromPoint, pointIndex)
      this.fromPoint = null
      this.clearHighlights()
    }
  }

  async movePiece(from, to) {
    const gameId = this.element.dataset.gameId
    try {
      const response = await fetch(`/games/${gameId}/move`, {
        method: 'POST',
        headers: {
          'Accept': 'text/turbo-stream',
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ from_index: from, to_index: to })
      })

      if (response.ok) {
        const html = await response.text()
        if (window.Turbo) window.Turbo.renderStreamMessage(html)
      } else {
        const data = await response.json()
        this.showMessage(data.error || "Error in the move")
      }
    } catch (error) {
      console.error("Move error:", error)
      window.location.reload()
    }
  }

  async checkWinner() {
    const winnerEl = document.getElementById("winner-announcement")
    if (winnerEl && winnerEl.getAttribute('data-fired') === "false") {
      try {
        // Dynamic library import
        const module = await import("canvas-confetti")
        // We maintain the fireworks function
        const confettiAction = module.default

        // We pass this function to the rendering method
        this.launchSalute(confettiAction)
        winnerEl.setAttribute('data-fired', 'true')
      } catch (e) {
        console.error("Critical fireworks error:", e)
      }
    }
  }

  launchSalute(c) {
    const end = Date.now() + (5 * 1000)

    const frame = () => {
      // We call the passed function 'c'
      c({ particleCount: 3, angle: 60, spread: 55, origin: { x: 0, y: 0.6 }, zIndex: 300 })
      c({ particleCount: 3, angle: 120, spread: 55, origin: { x: 1, y: 0.6 }, zIndex: 300 })

      if (Date.now() < end) {
        requestAnimationFrame(frame)
      }
    }
    frame()
  }

  showMessage(text) {
    const flash = document.getElementById("flash-message")
    const flashText = document.getElementById("flash-text")
    if (!flash || !flashText) return
    flashText.innerText = text
    flash.classList.replace("scale-0", "scale-100")
    flash.classList.replace("opacity-0", "opacity-100")
    setTimeout(() => {
      flash.classList.replace("scale-100", "scale-0")
      flash.classList.replace("opacity-100", "opacity-0")
    }, 3000)
  }

  autoHideFlash() {  const flash = document.getElementById("flash-message")
    if (flash && flash.classList.contains("opacity-100")) {
      setTimeout(() => {
        flash.classList.add("scale-0", "opacity-0")
        flash.classList.remove("scale-100", "opacity-100")
      }, 3000)
    }
  }
  highlight(el) { el.classList.add("ring-4", "ring-yellow-400", "z-30") }
  clearHighlights() { this.pointTargets.forEach(t => t.classList.remove("ring-4", "ring-yellow-400", "z-30")) }
}