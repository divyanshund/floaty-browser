'use client'

import { useEffect, useState } from 'react'
import Hero from '@/components/Hero'
import Features from '@/components/Features'
import Demo from '@/components/Demo'
import Download from '@/components/Download'
import Footer from '@/components/Footer'
import BubbleParticles from '@/components/BubbleParticles'

export default function Home() {
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 })

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setMousePosition({ x: e.clientX, y: e.clientY })
    }
    window.addEventListener('mousemove', handleMouseMove)
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [])

  return (
    <main className="relative min-h-screen">
      <BubbleParticles mousePosition={mousePosition} />
      <Hero />
      <Features />
      <Demo />
      <Download />
      <Footer />
    </main>
  )
}

