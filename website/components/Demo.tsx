'use client'

import { motion } from 'framer-motion'
import { useState } from 'react'
import { useInView } from 'framer-motion'
import { useRef } from 'react'

const themes = [
  { name: 'Frosted Glass', color: 'rgba(255, 255, 255, 0.1)' },
  { name: 'Ocean Blue', color: 'rgba(74, 158, 255, 0.9)' },
  { name: 'Sunset', color: 'rgba(255, 153, 102, 0.9)' },
  { name: 'Forest', color: 'rgba(51, 181, 115, 0.9)' },
  { name: 'Purple Dream', color: 'rgba(179, 102, 242, 0.9)' },
]

export default function Demo() {
  const [expanded, setExpanded] = useState(false)
  const [selectedTheme, setSelectedTheme] = useState(0)
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  return (
    <section className="relative py-32 px-6 bg-gradient-to-b from-transparent to-ocean-blue/10">
      <div className="container mx-auto">
        <motion.div
          ref={ref}
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8 }}
          className="text-center mb-16"
        >
          <h2 className="text-5xl md:text-6xl font-bold mb-4">
            <span className="gradient-text">See It In Action</span>
          </h2>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Click the bubble below to see how Floaty Browser works
          </p>
        </motion.div>

        <div className="flex flex-col items-center justify-center">
          {/* Bubble */}
          <motion.div
            className="relative mb-12"
            initial={{ scale: 0.8 }}
            animate={{ scale: expanded ? 0 : 1 }}
            transition={{ duration: 0.5 }}
            style={{ display: expanded ? 'none' : 'block' }}
          >
            <motion.button
              onClick={() => setExpanded(true)}
              className="w-24 h-24 rounded-full bg-gradient-to-br from-ocean-blue to-purple-dream flex items-center justify-center text-4xl shadow-2xl bubble-glow cursor-pointer"
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.95 }}
              animate={{
                y: [0, -10, 0],
              }}
              transition={{
                y: {
                  duration: 3,
                  repeat: Infinity,
                  ease: 'easeInOut',
                },
              }}
            >
              🌐
            </motion.button>
          </motion.div>

          {/* Expanded Panel */}
          <motion.div
            initial={{ opacity: 0, scale: 0.8, y: 50 }}
            animate={{
              opacity: expanded ? 1 : 0,
              scale: expanded ? 1 : 0.8,
              y: expanded ? 0 : 50,
            }}
            transition={{ duration: 0.5 }}
            style={{ display: expanded ? 'block' : 'none' }}
            className="w-full max-w-4xl"
          >
            <div className="glass-strong rounded-2xl overflow-hidden shadow-2xl">
              {/* Toolbar */}
              <div
                className="h-16 flex items-center px-6 gap-4"
                style={{ backgroundColor: themes[selectedTheme].color }}
              >
                <div className="flex gap-2">
                  <div className="w-3 h-3 rounded-full bg-red-500" />
                  <div className="w-3 h-3 rounded-full bg-yellow-500" />
                  <div className="w-3 h-3 rounded-full bg-green-500" />
                </div>
                <div className="flex-1 glass rounded-full px-4 py-2 text-sm text-white/80">
                  https://example.com
                </div>
                <button
                  onClick={() => setExpanded(false)}
                  className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
                >
                  ×
                </button>
              </div>

              {/* Content */}
              <div className="h-96 bg-gradient-to-br from-gray-900 to-gray-800 flex items-center justify-center">
                <div className="text-center">
                  <div className="text-6xl mb-4">🫧</div>
                  <p className="text-white text-xl">Floaty Browser Panel</p>
                  <p className="text-gray-400 mt-2">Click × to collapse back to bubble</p>
                </div>
              </div>
            </div>

            {/* Theme Selector */}
            <div className="mt-8 flex flex-wrap gap-4 justify-center">
              {themes.map((theme, index) => (
                <motion.button
                  key={index}
                  onClick={() => setSelectedTheme(index)}
                  className={`px-6 py-3 rounded-full glass text-white font-medium transition-all ${
                    selectedTheme === index ? 'glass-strong ring-2 ring-ocean-blue' : ''
                  }`}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  {theme.name}
                </motion.button>
              ))}
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}

