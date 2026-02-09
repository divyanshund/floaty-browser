'use client'

import { motion } from 'framer-motion'
import { useInView } from 'framer-motion'
import { useRef } from 'react'

const features = [
  {
    icon: '🫧',
    title: 'Floating Bubbles',
    description: 'Circular, draggable bubbles that float above all other windows. Click to expand into a full browser panel.',
    color: 'from-ocean-blue to-blue-600',
  },
  {
    icon: '🌐',
    title: 'Multi-Bubble Support',
    description: 'Create multiple bubbles, each with its own URL. Keep your favorite sites always accessible.',
    color: 'from-purple-dream to-purple-600',
  },
  {
    icon: '🎨',
    title: 'Beautiful Themes',
    description: 'Choose from Frosted Glass, Ocean Blue, Sunset, Forest, Purple Dream, Rose Gold, and Midnight themes.',
    color: 'from-sunset to-orange-600',
  },
  {
    icon: '🔗',
    title: 'Smart Link Handling',
    description: 'Links that open in new tabs automatically create new bubbles. Seamless browsing experience.',
    color: 'from-forest to-green-600',
  },
  {
    icon: '💾',
    title: 'Persistent State',
    description: 'Bubble positions and URLs are saved between app launches. Your setup survives reboots.',
    color: 'from-rose-gold to-pink-600',
  },
  {
    icon: '⌨️',
    title: 'Global Shortcuts',
    description: 'Use ⌃⌥Space to toggle all panels at once. Full keyboard control for power users.',
    color: 'from-midnight to-indigo-600',
  },
]

export default function Features() {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  return (
    <section id="features" className="relative py-32 px-6">
      <div className="container mx-auto">
        <motion.div
          ref={ref}
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8 }}
          className="text-center mb-16"
        >
          <h2 className="text-5xl md:text-6xl font-bold mb-4">
            <span className="gradient-text">Features</span>
          </h2>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Everything you need for a premium browsing experience
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 30 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.6, delay: index * 0.1 }}
              whileHover={{ y: -10, scale: 1.02 }}
              className="glass rounded-2xl p-8 hover:glass-strong transition-all duration-300 cursor-pointer group"
            >
              <div className={`w-16 h-16 rounded-full bg-gradient-to-br ${feature.color} flex items-center justify-center text-3xl mb-6 group-hover:scale-110 transition-transform duration-300`}>
                {feature.icon}
              </div>
              <h3 className="text-2xl font-bold mb-4 text-white">{feature.title}</h3>
              <p className="text-gray-400 leading-relaxed">{feature.description}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

