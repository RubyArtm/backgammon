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
    this.stopWinnerFireworks()
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
  checkWinner() {
    const winnerEl = document.getElementById("winner-announcement")
    if (!winnerEl || winnerEl.getAttribute("data-fired") !== "false") return

    winnerEl.setAttribute("data-fired", "true")
    this.startWinnerFireworks()
  }

  startWinnerFireworks() {
    this.stopWinnerFireworks()

    const winnerEl = document.getElementById("winner-announcement")
    if (!winnerEl) return

    const canvas = document.createElement("canvas")
    canvas.className = "winner-fireworks-canvas"
    winnerEl.appendChild(canvas)
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    this.fireworksCanvas = canvas
    this.fireworksCtx = ctx
    this.fireworksRockets = []
    this.fireworksParticles = []
    this.fireworksActive = true

    const resize = () => {
      const ratio = Math.min(window.devicePixelRatio || 1, 2)
      canvas.width = Math.floor(window.innerWidth * ratio)
      canvas.height = Math.floor(window.innerHeight * ratio)
      canvas.style.width = `${window.innerWidth}px`
      canvas.style.height = `${window.innerHeight}px`
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
      ctx.globalCompositeOperation = "lighter"
    }

    this.fireworksResizeHandler = resize
    window.addEventListener("resize", this.fireworksResizeHandler)
    resize()

    const spawnRocket = () => {
      const w = window.innerWidth
      const h = window.innerHeight
      const lane = Math.floor(Math.random() * 3)

      let x
      let y
      if (lane === 0) {
        x = w * (0.2 + Math.random() * 0.6)
        y = -24
      } else if (lane === 1) {
        x = -24
        y = h * (0.3 + Math.random() * 0.5)
      } else {
        x = w + 24
        y = h * (0.3 + Math.random() * 0.5)
      }

      const tx = w * (0.22 + Math.random() * 0.56)
      const ty = h * (0.16 + Math.random() * 0.56)
      const dx = tx - x
      const dy = ty - y
      const dist = Math.max(1, Math.hypot(dx, dy))
      const speed = 8 + Math.random() * 3.5

      this.fireworksRockets.push({
        x,
        y,
        tx,
        ty,
        vx: (dx / dist) * speed,
        vy: (dy / dist) * speed
      })
    }

    this.fireworksSpawnInterval = setInterval(spawnRocket, 85)
    spawnRocket()

    const colors = ["#ffe17a", "#ffffff", "#7dd3fc", "#34d399", "#f9a8d4", "#fb923c"]
    const burst = (x, y) => {
      const count = 42 + Math.floor(Math.random() * 48)
      for (let i = 0; i < count; i += 1) {
        const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.55
        const velocity = 2.3 + Math.random() * 6.8
        this.fireworksParticles.push({
          x,
          y,
          vx: Math.cos(angle) * velocity,
          vy: Math.sin(angle) * velocity,
          life: 0.85 + Math.random() * 0.7,
          age: 0,
          radius: 1.7 + Math.random() * 3.2,
          color: colors[Math.floor(Math.random() * colors.length)]
        })
      }
    }

    const step = () => {
      if (!this.fireworksActive || !this.fireworksCtx || !this.fireworksCanvas) return

      const localCtx = this.fireworksCtx
      const w = window.innerWidth
      const h = window.innerHeight

      localCtx.globalCompositeOperation = "source-over"
      localCtx.fillStyle = "rgba(0, 0, 0, 0.12)"
      localCtx.fillRect(0, 0, w, h)
      localCtx.globalCompositeOperation = "lighter"

      this.fireworksRockets = this.fireworksRockets.filter((r) => {
        r.x += r.vx
        r.y += r.vy

        localCtx.beginPath()
        localCtx.arc(r.x, r.y, 2.8, 0, Math.PI * 2)
        localCtx.fillStyle = "rgba(255, 245, 200, 0.95)"
        localCtx.fill()

        localCtx.beginPath()
        localCtx.moveTo(r.x, r.y)
        localCtx.lineTo(r.x - r.vx * 2.4, r.y - r.vy * 2.4)
        localCtx.strokeStyle = "rgba(255, 233, 145, 0.85)"
        localCtx.lineWidth = 2.1
        localCtx.stroke()

        const arrived = Math.hypot(r.tx - r.x, r.ty - r.y) < 12
        if (arrived) burst(r.x, r.y)
        return !arrived
      })

      this.fireworksParticles = this.fireworksParticles.filter((p) => {
        p.age += 0.016
        p.vx *= 0.986
        p.vy = p.vy * 0.986 + 0.055
        p.x += p.vx
        p.y += p.vy

        const t = Math.max(0, 1 - p.age / p.life)
        if (t <= 0) return false

        localCtx.beginPath()
        localCtx.arc(p.x, p.y, p.radius * t + 0.6, 0, Math.PI * 2)
        localCtx.fillStyle = p.color
        localCtx.globalAlpha = Math.min(1, t * 1.2)
        localCtx.fill()

        return p.x > -40 && p.x < w + 40 && p.y < h + 40
      })

      localCtx.globalAlpha = 1
      this.fireworksAnimationFrame = requestAnimationFrame(step)
    }

    this.fireworksAnimationFrame = requestAnimationFrame(step)
  }

  stopWinnerFireworks() {
    this.fireworksActive = false
    if (this.fireworksSpawnInterval) clearInterval(this.fireworksSpawnInterval)
    if (this.fireworksAnimationFrame) cancelAnimationFrame(this.fireworksAnimationFrame)
    if (this.fireworksResizeHandler) {
      window.removeEventListener("resize", this.fireworksResizeHandler)
    }
    if (this.fireworksCanvas) this.fireworksCanvas.remove()

    this.fireworksSpawnInterval = null
    this.fireworksAnimationFrame = null
    this.fireworksResizeHandler = null
    this.fireworksCanvas = null
    this.fireworksCtx = null
    this.fireworksRockets = []
    this.fireworksParticles = []
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
    if (!document.getElementById("winner-announcement")) this.stopWinnerFireworks()
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
