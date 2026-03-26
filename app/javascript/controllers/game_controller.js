import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["point"]

  connect() {
    this.fromPoint = null
    this.legalMovesMap = {}
    this.uiStorageKey = "backgammon.ui.preferences.v1"
    this.uiDefaults = {
      showHints: true,
      showStats: false,
      statSections: {
        rolled: true,
        used: true,
        doubles: true,
        history: true
      }
    }
    this.uiPreferences = this.loadUiPreferences()
    this.refreshLegalMovesMap()
    this.applyUiPreferences()
    this.installGameAreaObserver()
    this.autoHideFlash()
    setTimeout(() => this.checkWinner(), 200)
    console.log("Backgammon Pro: Connected")
  }

  disconnect() {
    if (this.gameAreaObserver) this.gameAreaObserver.disconnect()
  }

  // Method of choosing a checker
  selectPoint(event) {
    const gameArea = document.getElementById("game_area")
    if (gameArea?.dataset.replayMode === "true") return

    this.refreshLegalMovesMap()
    const el = event.currentTarget
    const pointIndex = String(el.dataset.pointIndex)
    const hasCheckers = el.querySelector(".checker:not(.ghost-hint)") !== null

    if (this.fromPoint === null) {
      if (!hasCheckers) return
      if (!this.isSelectableFrom(pointIndex)) {
        const reason = this.invalidFromReason(el, pointIndex)
        if (reason) this.showMessage(reason)
        return
      }
      this.fromPoint = pointIndex
      this.highlightFromAndTargets()
    } else {
      if (this.fromPoint === pointIndex) {
        this.clearHighlights()
        this.fromPoint = null
        return
      }

      if (this.isSelectableTo(this.fromPoint, pointIndex)) {
        this.movePiece(this.fromPoint, pointIndex)
        this.fromPoint = null
        this.clearHighlights()
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
          'Accept': 'text/vnd.turbo-stream.html, text/html, application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ from_index: from, to_index: to })
      })

      const contentType = response.headers.get("Content-Type") || ""
      const bodyText = await response.text()

      if (contentType.includes("text/vnd.turbo-stream.html")) {
        if (window.Turbo) window.Turbo.renderStreamMessage(bodyText)

        this.syncUiAfterDomUpdate()
        requestAnimationFrame(() => {
          this.scheduleFlashAutoHide()
          this.checkWinner()
        })
        return
      }

      if (response.ok) return

      if (contentType.includes("application/json")) {
        let data = {}
        try { data = JSON.parse(bodyText || "{}") } catch (_error) { data = {} }
        this.showMessage(data.error || "Error")
        return
      }

      if (bodyText.includes("<turbo-stream")) {
        if (window.Turbo) window.Turbo.renderStreamMessage(bodyText)
        this.syncUiAfterDomUpdate()
        requestAnimationFrame(() => this.scheduleFlashAutoHide())
        return
      }

      const parser = new DOMParser()
      const doc = parser.parseFromString(bodyText, "text/html")
      const extracted = (doc.getElementById("flash-text")?.textContent || "").trim()
      if (extracted.length > 0) {
        this.showMessage(extracted)
        return
      }

      this.showMessage("Server error (see Rails log)")
    } catch (error) {
      console.error("Move error:", error)
      window.location.reload()
    }
  }

  showMessage(text) {
    const flash = document.getElementById("flash-message")
    const flashText = document.getElementById("flash-text")
    if (!flash || !flashText) return

    flashText.innerText = text
    flash.classList.replace("scale-0", "scale-100")
    flash.classList.replace("opacity-0", "opacity-100")

    this.scheduleFlashAutoHide()
  }

  scheduleFlashAutoHide() {
    const flash = document.getElementById("flash-message")
    const flashText = document.getElementById("flash-text")
    if (!flash || !flashText) return

    const message = (flashText.textContent || "").trim()
    if (message.length === 0) return

    if (this.flashHideTimer) clearTimeout(this.flashHideTimer)

    this.flashHideTimer = setTimeout(() => {
      flash.classList.add("scale-0", "opacity-0")
      flash.classList.remove("scale-100", "opacity-100")
    }, 3000)
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

  autoHideFlash() {
    const flash = document.getElementById("flash-message")
    if (flash && flash.classList.contains("opacity-100")) {
      this.scheduleFlashAutoHide()
    }
  }
  refreshLegalMovesMap() {
    const gameArea = document.getElementById("game_area")
    const raw = gameArea?.dataset.legalMovesMap
    if (!raw) {
      this.legalMovesMap = {}
      return
    }

    try {
      this.legalMovesMap = JSON.parse(raw)
    } catch (_error) {
      this.legalMovesMap = {}
    }
  }

  isSelectableFrom(pointIndex) {
    const targets = this.legalMovesMap?.[pointIndex]
    return Array.isArray(targets) && targets.length > 0
  }

  isSelectableTo(fromPoint, toPoint) {
    const targets = this.legalMovesMap?.[String(fromPoint)] || []
    return targets.includes(String(toPoint))
  }

  invalidFromReason(pointElement, pointIndex) {
    const gameArea = document.getElementById("game_area")
    if (!gameArea) return null

    const turn = Number(gameArea.dataset.currentTurn || -1)
    const checker = pointElement.querySelector(".checker:not(.ghost-hint)")
    if (!checker) return null

    const isWhiteChecker = checker.classList.contains("bg-white")
    const isBlackChecker = checker.classList.contains("bg-slate-800")
    const opponentMove =
      (turn === 0 && isBlackChecker) ||
      (turn === 1 && isWhiteChecker)
    if (opponentMove) return "Wrong move of the opponent's checker!"

    const headIndex = turn === 0 ? "11" : "23"
    if (String(pointIndex) === headIndex) {
      const headUsed = gameArea.dataset.headUsed === "true"
      const d1 = Number(gameArea.dataset.dice1 || 0)
      const d2 = Number(gameArea.dataset.dice2 || 0)
      const isDouble = d1 > 0 && d1 === d2
      const countInHead = pointElement.querySelectorAll(".checker:not(.ghost-hint)").length
      const isFirstTurnException = isDouble && countInHead === 14

      if (headUsed && !isFirstTurnException) {
        return "You can only take one checker from your head!"
      }
    }

    return "This checker has no legal move."
  }

  highlightFromAndTargets() {
    this.clearHighlights()
    const selected = this.pointTargets.find((target) => target.dataset.pointIndex === String(this.fromPoint))
    if (selected) selected.classList.add("ring-4", "ring-yellow-400", "z-30")

    if (!this.uiPreferences.showHints) return

    const checkerClasses = this.ghostCheckerClassesForPoint(selected)
    const targets = this.legalMovesMap?.[String(this.fromPoint)] || []
    targets.forEach((targetIndex) => {
      const destination = this.pointTargets.find((target) => target.dataset.pointIndex === String(targetIndex))
      if (!destination) return
      this.renderGhostHint(destination, checkerClasses)
    })
  }

  clearHighlights() {
    this.pointTargets.forEach((target) => {
      target.classList.remove("ring-4", "ring-yellow-400", "z-30")
      target.querySelectorAll(".ghost-hint").forEach((ghost) => ghost.remove())
    })
  }

  ghostCheckerClassesForPoint(point) {
    if (!point) return "bg-white/45 border-slate-200/65"

    const checker = point.querySelector(".checker:not(.ghost-hint)")
    if (!checker) return "bg-white/45 border-slate-200/65"

    return checker.classList.contains("bg-slate-800")
      ? "bg-slate-800/25 border-slate-300/55"
      : "bg-white/45 border-slate-200/65"
  }

  renderGhostHint(destination, checkerClasses) {
    const ghost = document.createElement("div")
    const stackSize = destination.querySelectorAll(".checker:not(.ghost-hint)").length
    const hasStack = stackSize > 0
    const isBottomLane = destination.classList.contains("flex-col-reverse")

    const positionClasses = isBottomLane
      ? (hasStack ? "bottom-[18%]" : "bottom-[4%]")
      : (hasStack ? "top-[18%]" : "top-[4%]")

    ghost.className = `ghost-hint checker pointer-events-none absolute left-1/2 -translate-x-1/2 w-[72%] aspect-square rounded-full border shadow-md z-20 ${positionClasses} ${checkerClasses}`
    destination.appendChild(ghost)
  }

  toggleHints() {
    this.uiPreferences.showHints = !this.uiPreferences.showHints
    this.persistUiPreferences()
    this.applyUiPreferences()
    this.highlightFromAndTargets()
  }

  toggleStats() {
    this.uiPreferences.showStats = !this.uiPreferences.showStats
    this.persistUiPreferences()
    this.applyUiPreferences()
  }

  toggleStatSection(event) {
    const section = event.currentTarget.dataset.section
    if (!section) return

    const current = !!this.uiPreferences.statSections?.[section]
    this.uiPreferences.statSections[section] = !current
    this.persistUiPreferences()
    this.applyUiPreferences()
  }

  applyUiPreferences() {
    const gameArea = document.getElementById("game_area")
    if (gameArea?.dataset.replayMode === "true") return

    const hintsButton = document.getElementById("hints-toggle-button")
    if (hintsButton) {
      hintsButton.textContent = `Hints: ${this.uiPreferences.showHints ? "On" : "Off"}`
      hintsButton.classList.toggle("ring-2", this.uiPreferences.showHints)
      hintsButton.classList.toggle("ring-emerald-300/70", this.uiPreferences.showHints)
      hintsButton.classList.toggle("opacity-80", !this.uiPreferences.showHints)
      hintsButton.classList.toggle("opacity-100", this.uiPreferences.showHints)
    }

    const statsButton = document.getElementById("stats-toggle-button")
    const statsPanel = document.getElementById("stats_panel")
    if (statsButton && statsPanel) {
      const showStats = !!this.uiPreferences.showStats
      statsButton.textContent = `Stats: ${showStats ? "On" : "Off"}`
      statsPanel.classList.toggle("hidden", !showStats)
      statsButton.classList.toggle("ring-2", showStats)
      statsButton.classList.toggle("ring-emerald-300/70", showStats)
      statsButton.classList.toggle("opacity-80", !showStats)
      statsButton.classList.toggle("opacity-100", showStats)
    }

    const sectionVisibility = this.uiPreferences.statSections || {}
    document.querySelectorAll("[data-stat-section]").forEach((element) => {
      const section = element.dataset.statSection
      const visible = sectionVisibility[section] !== false
      element.classList.toggle("hidden", !visible)
    })

    document.querySelectorAll(".stat-section-toggle").forEach((button) => {
      const section = button.dataset.section
      const visible = sectionVisibility[section] !== false
      button.classList.toggle("bg-emerald-700/60", visible)
      button.classList.toggle("border-emerald-300/70", visible)
      button.classList.toggle("bg-black/20", !visible)
      button.classList.toggle("border-white/20", !visible)
    })
  }

  loadUiPreferences() {
    try {
      const raw = window.localStorage.getItem(this.uiStorageKey)
      if (!raw) return JSON.parse(JSON.stringify(this.uiDefaults))

      const parsed = JSON.parse(raw)
      return {
        showHints: parsed.showHints !== false,
        showStats: parsed.showStats === true,
        statSections: {
          rolled: parsed?.statSections?.rolled !== false,
          used: parsed?.statSections?.used !== false,
          doubles: parsed?.statSections?.doubles !== false,
          history: parsed?.statSections?.history !== false
        }
      }
    } catch (_error) {
      return JSON.parse(JSON.stringify(this.uiDefaults))
    }
  }

  persistUiPreferences() {
    try {
      window.localStorage.setItem(this.uiStorageKey, JSON.stringify(this.uiPreferences))
    } catch (_error) {
      // no-op
    }
  }

  syncUiAfterDomUpdate() {
    this.refreshLegalMovesMap()
    this.applyUiPreferences()
    this.clearHighlights()
    this.fromPoint = null
    this.autoHideFlash()
  }

  installGameAreaObserver() {
    if (this.gameAreaObserver) this.gameAreaObserver.disconnect()

    this.lastGameAreaNode = document.getElementById("game_area")
    this.gameAreaObserver = new MutationObserver(() => {
      const current = document.getElementById("game_area")
      if (!current || current === this.lastGameAreaNode) return

      this.lastGameAreaNode = current
      this.syncUiAfterDomUpdate()
      requestAnimationFrame(() => {
        this.checkWinner()
      })
    })

    this.gameAreaObserver.observe(this.element, { childList: true, subtree: true })
  }
}
