# Floaty Browser Website

A stunning, modern website for Floaty Browser built with Next.js, React Three Fiber, and Framer Motion.

## Features

- 🎨 Beautiful bubble-themed design
- 🎭 Smooth animations with Framer Motion
- 🫧 Interactive 3D bubbles with React Three Fiber
- ✨ Glassmorphism effects throughout
- 📱 Fully responsive design
- ⚡ Optimized performance

## Getting Started

### Install Dependencies

```bash
npm install
```

### Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Build for Production

```bash
npm run build
npm start
```

## Tech Stack

- **Next.js 14** - React framework
- **React Three Fiber** - 3D graphics
- **Framer Motion** - Animations
- **Tailwind CSS** - Styling
- **TypeScript** - Type safety

## Project Structure

```
website/
├── app/
│   ├── layout.tsx       # Root layout
│   ├── page.tsx         # Home page
│   └── globals.css      # Global styles
├── components/
│   ├── Hero.tsx         # Hero section
│   ├── Features.tsx     # Features showcase
│   ├── Demo.tsx         # Interactive demo
│   ├── Download.tsx     # Download section
│   ├── Footer.tsx       # Footer
│   ├── BubbleParticles.tsx    # Background particles
│   └── FloatingBubble3D.tsx  # 3D bubble component
└── package.json
```

## Customization

### Colors

Edit `tailwind.config.js` to customize the color palette:

```js
colors: {
  'ocean-blue': '#4A9EFF',
  'purple-dream': '#B366F2',
  // ... more colors
}
```

### Animations

Modify animation timings in component files or `tailwind.config.js` for keyframe animations.

## Deployment

The site can be deployed to:
- **Vercel** (recommended for Next.js)
- **Netlify**
- **Any static hosting service**

## License

MIT

