import Cocoa

// MARK: - Physics ball: Clawd curls into a ball you can grab and throw

final class BallState {
    static let radius: CGFloat = 38
    var pos = CGPoint.zero
    var vel = CGPoint.zero
    var angle = 0.0           // radians; the face orbits as it rolls
    var spin = 0.0            // rad/s while airborne
    var held = false
    var lastCenter = CGPoint.zero
    var vEst = CGPoint.zero   // smoothed cursor velocity while held
    var squash = 0            // 1 = squashed against floor, 2 = against a wall
    var squashT = 0.0
    var platforms: [CGRect] = []
    var platT = 0.0
    var pending = false
    var pendingHoops = false
    var lastClick = 0.0
    var lastSound = 0.0
}

extension Pet {
    static let ballCenter = CGPoint(x: 48, y: 46)   // where the ball sits inside Clawd's window

    @objc func toggleBall() { if mode == .ball { endBall() } else { startBall() } }

    func startBall() {
        if mode == .docked { ball.pending = true; undock(); return }
        guard mode == .desk else { return }
        hideTray()
        shelf.hide()
        bubble.hide()
        perch = nil
        redockAt = nil
        ball.pos = CGPoint(x: x + Pet.ballCenter.x, y: y + Pet.ballCenter.y)
        ball.vel = CGPoint(x: 0, y: 420)
        ball.angle = 0
        ball.spin = 0
        ball.held = false
        ball.lastCenter = ball.pos
        ball.vEst = .zero
        ball.platT = 0
        ball.squash = 1
        ball.squashT = 0.2
        mode = .ball
        Sfx.play(.poof)
        say("Wheee! Grab me and throw me. Double-click to unroll.", hold: 3.5, typewriter: false)
    }

    func endBall() {
        if hoop.active { endHoops(finished: false) }
        x = ball.pos.x - Pet.ballCenter.x
        y = max(floorY, ball.pos.y - Pet.ballCenter.y)
        vy = 0
        mode = .falling
        brain.start(.idle, dur: 1)
        Sfx.play(.poof)
        say("Phew, unrolled.", hold: 2)
    }

    func releaseBall() {
        ball.held = false
        var v = ball.vEst
        let speed = hypot(v.x, v.y)
        if speed > 3200 { v = CGPoint(x: v.x / speed * 3200, y: v.y / speed * 3200) }
        if speed < 100 { v = .zero }
        ball.vel = v
        if hoop.active && speed > 300 { hoop.shotFrom = ball.pos; hoop.scored = false; hoop.touchedRim = false }
        ball.spin = Double(-v.x / BallState.radius) * 0.7
        if speed > 500 { Sfx.play(.whoosh, volume: Float(min(0.4, speed / 4000))) }
    }

    func ballImpact(_ speed: CGFloat, axis: Int) {
        guard speed > 220 else { return }
        ball.squash = axis
        ball.squashT = 0.13
        let now = CACurrentMediaTime()
        if now - ball.lastSound > 0.07 {
            ball.lastSound = now
            Sfx.play(axis == 1 ? .land : .drop, volume: Float(min(0.45, 0.1 + speed / 3500)))
        }
    }

    func ballTick(_ dt: Double, now: Double) {
        let R = BallState.radius
        let scr = screen
        let vis = scr.visibleFrame, fr = scr.frame
        ball.platT -= dt
        if ball.platT <= 0 {
            ball.platT = 0.2
            ball.platforms = windowRects().map { $0.rect }.filter {
                $0.width > 120 && $0.height > 60 && $0.maxY > vis.minY + 40 && $0.maxY < fr.maxY - 30
            }
        }
        if ball.squashT > 0 { ball.squashT -= dt }

        var resting = false
        if ball.held {
            let c = CGPoint(x: panel.frame.origin.x + Pet.ballCenter.x, y: panel.frame.origin.y + Pet.ballCenter.y)
            if dt > 0 {
                let inst = CGPoint(x: (c.x - ball.lastCenter.x) / CGFloat(dt), y: (c.y - ball.lastCenter.y) / CGFloat(dt))
                ball.vEst = CGPoint(x: ball.vEst.x * 0.6 + inst.x * 0.4, y: ball.vEst.y * 0.6 + inst.y * 0.4)
            }
            ball.lastCenter = c
            ball.pos = c
            ball.vel = .zero
            ball.spin = 0
        } else {
            let steps = 3
            let h = CGFloat(dt) / CGFloat(steps)
            var onSurface = false
            for _ in 0..<steps {
                let prevY = ball.pos.y
                ball.vel.y -= 1900 * h
                ball.vel.x *= 1 - 0.03 * h
                ball.pos.x += ball.vel.x * h
                ball.pos.y += ball.vel.y * h
                if ball.pos.y < vis.minY + R {
                    ball.pos.y = vis.minY + R
                    if ball.vel.y < 0 { ballImpact(-ball.vel.y, axis: 1); ball.vel.y = -ball.vel.y > 130 ? -ball.vel.y * 0.72 : 0 }
                    onSurface = true
                }
                if ball.pos.y > vis.maxY - R {
                    ball.pos.y = vis.maxY - R
                    if ball.vel.y > 0 { ballImpact(ball.vel.y, axis: 1); ball.vel.y = -ball.vel.y * 0.6 }
                }
                if ball.pos.x < fr.minX + R {
                    ball.pos.x = fr.minX + R
                    if ball.vel.x < 0 { ballImpact(-ball.vel.x, axis: 2); ball.spin += Double(ball.vel.y / R) * 0.3; ball.vel.x = -ball.vel.x * 0.75 }
                }
                if ball.pos.x > fr.maxX - R {
                    ball.pos.x = fr.maxX - R
                    if ball.vel.x > 0 { ballImpact(ball.vel.x, axis: 2); ball.spin -= Double(ball.vel.y / R) * 0.3; ball.vel.x = -ball.vel.x * 0.75 }
                }
                if hoop.active { hoopCollide(prevY: prevY) }
                if ball.vel.y <= 0 {
                    for r in ball.platforms {
                        let top = r.maxY
                        if prevY - R >= top - 2 && ball.pos.y - R < top && ball.pos.x > r.minX - 8 && ball.pos.x < r.maxX + 8 {
                            ball.pos.y = top + R
                            ballImpact(-ball.vel.y, axis: 1)
                            ball.vel.y = -ball.vel.y > 130 ? -ball.vel.y * 0.72 : 0
                            onSurface = true
                            break
                        }
                    }
                }
            }
            if onSurface && abs(ball.vel.y) < 8 {
                ball.vel.x *= CGFloat(exp(-0.35 * dt))          // rolling friction
                ball.angle -= Double(ball.vel.x / R) * dt        // rolling without slipping
                ball.spin = Double(-ball.vel.x / R)
                if abs(ball.vel.x) < 5 { ball.vel.x = 0; resting = true }
            } else {
                ball.angle += ball.spin * dt
                ball.spin *= 1 - 0.08 * dt
            }
        }

        if resting {   // sit there and look at the cursor
            let m = NSEvent.mouseLocation
            let want = Double(atan2(m.y - ball.pos.y, m.x - ball.pos.x)) - .pi / 2
            var diff = (want - ball.angle).truncatingRemainder(dividingBy: 2 * .pi)
            if diff > .pi { diff -= 2 * .pi } else if diff < -.pi { diff += 2 * .pi }
            ball.angle += diff * min(1, dt * 5)
        }

        if hoop.active { hoopsTick(dt, now: now) }

        let step = Int((ball.angle / (.pi / 16)).rounded())
        var p = Pose()
        p.ball = true
        p.ballStep = ((step % 32) + 32) % 32
        p.ballSquash = ball.squashT > 0 ? ball.squash : 0
        view.pose = p
        x = ball.pos.x - Pet.ballCenter.x
        y = ball.pos.y - Pet.ballCenter.y
        moveWindow()
    }
}
