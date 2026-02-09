'use client'

import { useEffect, useRef } from 'react'

interface BubbleParticlesProps {
  mousePosition: { x: number; y: number }
}

interface Bubble {
  x: number
  y: number
  radius: number
  vx: number
  vy: number
  opacity: number
  color: string
}

export default function BubbleParticles({ mousePosition }: BubbleParticlesProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const bubblesRef = useRef<Bubble[]>([])
  const animationFrameRef = useRef<number>()

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const resizeCanvas = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }
    resizeCanvas()
    window.addEventListener('resize', resizeCanvas)

    // Initialize bubbles
    const colors = [
      'rgba(74, 158, 255, 0.3)',   // Ocean Blue
      'rgba(179, 102, 242, 0.3)',  // Purple Dream
      'rgba(255, 153, 102, 0.3)',  // Sunset
      'rgba(51, 181, 115, 0.3)',   // Forest
    ]

    const createBubble = (): Bubble => ({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      radius: Math.random() * 60 + 20,
      vx: (Math.random() - 0.5) * 0.5,
      vy: (Math.random() - 0.5) * 0.5,
      opacity: Math.random() * 0.5 + 0.2,
      color: colors[Math.floor(Math.random() * colors.length)],
    })

    bubblesRef.current = Array.from({ length: 15 }, createBubble)

    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)

      bubblesRef.current.forEach((bubble, index) => {
        // Update position
        bubble.x += bubble.vx
        bubble.y += bubble.vy

        // Mouse interaction
        const dx = mousePosition.x - bubble.x
        const dy = mousePosition.y - bubble.y
        const distance = Math.sqrt(dx * dx + dy * dy)
        
        if (distance < 200) {
          const force = (200 - distance) / 200
          bubble.vx -= (dx / distance) * force * 0.02
          bubble.vy -= (dy / distance) * force * 0.02
        }

        // Boundary check
        if (bubble.x < -bubble.radius || bubble.x > canvas.width + bubble.radius) {
          bubble.vx *= -1
        }
        if (bubble.y < -bubble.radius || bubble.y > canvas.height + bubble.radius) {
          bubble.vy *= -1
        }

        // Keep bubbles in bounds
        bubble.x = Math.max(bubble.radius, Math.min(canvas.width - bubble.radius, bubble.x))
        bubble.y = Math.max(bubble.radius, Math.min(canvas.height - bubble.radius, bubble.y))

        // Damping
        bubble.vx *= 0.98
        bubble.vy *= 0.98

        // Draw bubble
        ctx.beginPath()
        ctx.arc(bubble.x, bubble.y, bubble.radius, 0, Math.PI * 2)
        
        // Gradient fill
        const gradient = ctx.createRadialGradient(
          bubble.x - bubble.radius * 0.3,
          bubble.y - bubble.radius * 0.3,
          0,
          bubble.x,
          bubble.y,
          bubble.radius
        )
        gradient.addColorStop(0, bubble.color.replace('0.3', '0.6'))
        gradient.addColorStop(1, bubble.color.replace('0.3', '0.1'))
        
        ctx.fillStyle = gradient
        ctx.fill()

        // Glow effect
        ctx.shadowBlur = 20
        ctx.shadowColor = bubble.color
        ctx.strokeStyle = bubble.color.replace('0.3', '0.5')
        ctx.lineWidth = 2
        ctx.stroke()
        ctx.shadowBlur = 0
      })

      animationFrameRef.current = requestAnimationFrame(animate)
    }

    animate()

    return () => {
      window.removeEventListener('resize', resizeCanvas)
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current)
      }
    }
  }, [mousePosition])

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none z-0"
      style={{ background: 'transparent' }}
    />
  )
}

