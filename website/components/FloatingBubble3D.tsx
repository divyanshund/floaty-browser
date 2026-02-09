'use client'

import { useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Mesh, MeshStandardMaterial } from 'three'
import { OrbitControls, Sphere } from '@react-three/drei'

function AnimatedBubble() {
  const meshRef = useRef<Mesh>(null)
  const materialRef = useRef<MeshStandardMaterial>(null)

  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += 0.005
      meshRef.current.position.y = Math.sin(state.clock.elapsedTime) * 0.3
    }
    if (materialRef.current) {
      materialRef.current.opacity = 0.7 + Math.sin(state.clock.elapsedTime * 2) * 0.1
    }
  })

  return (
    <Sphere ref={meshRef} args={[2, 64, 64]}>
      <meshStandardMaterial
        ref={materialRef}
        color="#4A9EFF"
        transparent
        opacity={0.7}
        roughness={0.1}
        metalness={0.3}
        emissive="#4A9EFF"
        emissiveIntensity={0.3}
      />
    </Sphere>
  )
}

export default function FloatingBubble3D() {
  return (
    <div className="w-full h-96 md:h-[500px]">
      <Canvas camera={{ position: [0, 0, 8], fov: 50 }}>
        <ambientLight intensity={0.5} />
        <pointLight position={[10, 10, 10]} intensity={1} />
        <pointLight position={[-10, -10, -10]} intensity={0.5} color="#B366F2" />
        <AnimatedBubble />
        <OrbitControls
          enableZoom={false}
          enablePan={false}
          autoRotate
          autoRotateSpeed={1}
          minPolarAngle={Math.PI / 3}
          maxPolarAngle={Math.PI / 1.5}
        />
      </Canvas>
    </div>
  )
}

