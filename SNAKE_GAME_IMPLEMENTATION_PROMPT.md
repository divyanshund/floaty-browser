# 🎮 Add Offline Snake Game to Floaty Browser

## Feature Description

Add a fun "Bubble Snake" game that appears automatically when the browser cannot connect to the internet (offline mode or network errors). The game should be a classic snake game with:
- Retro pixel art style with green neon glow
- Play button to start
- Progressive difficulty (speeds up as you score)
- Persistent high score
- Responsive design that fits the browser window
- Arrow key controls
- Space bar to restart after game over

---

## Step 1: Create the Snake Game HTML File

**File:** `FloatyBrowser/snake_game.html`

**Location:** Place this file in the `FloatyBrowser` folder (same level as `WebViewController.swift`)

**Content:** Create a new file named `snake_game.html` with the following complete HTML:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bubble Snake</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            display: flex;
            flex-direction: column;
            justify-content: flex-start;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            font-family: 'Courier New', monospace;
            color: #fff;
            overflow-y: auto;
            overflow-x: hidden;
            padding: 10px;
            box-sizing: border-box;
        }
        
        #gameContainer {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 12px;
            max-width: 100%;
            padding: 10px;
            box-sizing: border-box;
        }
        
        #header {
            text-align: center;
        }
        
        .emoji {
            font-size: 48px;
            display: inline-block;
            animation: float 3s ease-in-out infinite;
        }
        
        @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-10px); }
        }
        
        h1 {
            font-size: 24px;
            margin-bottom: 5px;
            text-shadow: 2px 2px 0px #00ff00;
            letter-spacing: 2px;
        }
        
        #subtitle {
            font-size: 12px;
            color: #888;
            margin-bottom: 5px;
        }
        
        #scoreBoard {
            display: flex;
            gap: 20px;
            font-size: 14px;
            justify-content: center;
        }
        
        .score-item {
            text-align: center;
        }
        
        .score-label {
            font-size: 10px;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .score-value {
            font-size: 18px;
            font-weight: bold;
            color: #00ff00;
            text-shadow: 0 0 10px #00ff00;
        }
        
        #canvasContainer {
            position: relative;
            border: 3px solid #00ff00;
            box-shadow: 0 0 20px rgba(0, 255, 0, 0.3);
            border-radius: 8px;
            overflow: hidden;
        }
        
        canvas {
            display: block;
            background: #000;
        }
        
        #playButton {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            padding: 20px 60px;
            font-size: 28px;
            font-family: 'Courier New', monospace;
            background: #00ff00;
            color: #000;
            border: 3px solid #000;
            cursor: pointer;
            font-weight: bold;
            text-transform: uppercase;
            transition: all 0.2s;
            animation: pulse 2s infinite;
            box-shadow: 0 0 30px rgba(0, 255, 0, 0.6), inset 0 0 20px rgba(255, 255, 255, 0.2);
            z-index: 5;
        }
        
        @keyframes pulse {
            0%, 100% {
                box-shadow: 0 0 30px rgba(0, 255, 0, 0.6), inset 0 0 20px rgba(255, 255, 255, 0.2);
            }
            50% {
                box-shadow: 0 0 50px rgba(0, 255, 0, 0.9), inset 0 0 30px rgba(255, 255, 255, 0.3);
            }
        }
        
        #playButton:hover {
            background: #33ff33;
            transform: translate(-50%, -50%) scale(1.05);
        }
        
        #playButton:active {
            transform: translate(-50%, -50%) scale(0.95);
        }
        
        #gameOver {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.95);
            padding: 40px;
            border-radius: 15px;
            text-align: center;
            display: none;
            border: 3px solid #ff0000;
            box-shadow: 0 0 30px rgba(255, 0, 0, 0.5);
            z-index: 10;
        }
        
        #gameOver h2 {
            font-size: 36px;
            color: #ff0000;
            margin-bottom: 20px;
            text-shadow: 0 0 20px #ff0000;
        }
        
        #gameOver .emoji {
            font-size: 64px;
            margin: 20px 0;
        }
        
        #gameOver p {
            font-size: 18px;
            margin: 10px 0;
        }
        
        #gameOver .highlight {
            color: #00ff00;
            font-size: 32px;
            font-weight: bold;
            text-shadow: 0 0 15px #00ff00;
        }
        
        #gameOver button {
            margin-top: 20px;
            padding: 15px 40px;
            font-size: 18px;
            background: #00ff00;
            color: #000;
            border: 2px solid #000;
            cursor: pointer;
            font-family: 'Courier New', monospace;
            font-weight: bold;
            transition: all 0.2s;
        }
        
        #gameOver button:hover {
            background: #33ff33;
            transform: scale(1.05);
        }
        
        #instructions {
            text-align: center;
            color: #aaa;
            font-size: 11px;
            max-width: 90%;
            margin-top: 8px;
            margin-bottom: 10px;
            line-height: 1.4;
        }
        
        #instructions strong {
            color: #00ff00;
        }
    </style>
</head>
<body>
    <div id="gameContainer">
        <div id="header">
            <div class="emoji">🫧</div>
            <h1>BUBBLE SNAKE</h1>
            <div id="subtitle">No Internet? Time to play!</div>
        </div>
        
        <div id="scoreBoard">
            <div class="score-item">
                <div class="score-label">SCORE</div>
                <div class="score-value" id="score">0</div>
            </div>
            <div class="score-item">
                <div class="score-label">HIGH SCORE</div>
                <div class="score-value" id="highScore">0</div>
            </div>
        </div>
        
        <div id="canvasContainer">
            <canvas id="canvas"></canvas>
            <button id="playButton" onclick="startGame()">▶ PLAY</button>
        </div>
        
        <div id="instructions">
            🎮 Use <strong>Arrow Keys</strong> (←↑→↓) to move<br>
            🚀 Collect white bubbles to grow • 💀 Avoid walls and yourself<br>
            Press <strong>Space</strong> to restart after game over
        </div>
    </div>
    
    <div id="gameOver">
        <h2>GAME OVER!</h2>
        <div class="emoji">💥</div>
        <p>Your Score: <span class="highlight" id="finalScore">0</span></p>
        <p id="newHighScore" style="display: none; color: #ffff00;">🎉 NEW HIGH SCORE! 🎉</p>
        <button onclick="restartGame()">Play Again</button>
    </div>

    <script>
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        
        // Game settings
        const GRID_SIZE = 20;
        const INITIAL_SPEED = 200; // Slower start (was 150)
        const SPEED_INCREASE = 5;
        const MIN_SPEED = 50;
        
        // Make canvas responsive
        function resizeCanvas() {
            const headerHeight = 150;
            const instructionsHeight = 80;
            const padding = 40;
            const availableHeight = window.innerHeight - headerHeight - instructionsHeight - padding;
            const availableWidth = window.innerWidth - 40;
            
            const size = Math.min(availableHeight, availableWidth, 500);
            const gridCount = Math.floor(size / GRID_SIZE);
            canvas.width = gridCount * GRID_SIZE;
            canvas.height = gridCount * GRID_SIZE;
        }
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);
        
        // Game state
        let snake = [];
        let direction = { x: 1, y: 0 };
        let nextDirection = { x: 1, y: 0 };
        let food = {};
        let score = 0;
        let highScore = parseInt(localStorage.getItem('bubbleSnakeHighScore') || '0');
        let gameLoop = null;
        let speed = INITIAL_SPEED;
        let isGameOver = false;
        let isGameStarted = false;
        
        // Update high score display
        document.getElementById('highScore').textContent = highScore;
        
        // Start game
        function startGame() {
            const playButton = document.getElementById('playButton');
            if (playButton) {
                playButton.style.display = 'none';
            }
            isGameStarted = true;
            init();
        }
        
        // Initialize game
        function init() {
            const gridWidth = Math.floor(canvas.width / GRID_SIZE);
            const gridHeight = Math.floor(canvas.height / GRID_SIZE);
            
            // Create snake in center
            const centerX = Math.floor(gridWidth / 2);
            const centerY = Math.floor(gridHeight / 2);
            snake = [
                { x: centerX, y: centerY },
                { x: centerX - 1, y: centerY },
                { x: centerX - 2, y: centerY }
            ];
            
            direction = { x: 1, y: 0 };
            nextDirection = { x: 1, y: 0 };
            score = 0;
            speed = INITIAL_SPEED;
            isGameOver = false;
            
            document.getElementById('score').textContent = score;
            document.getElementById('gameOver').style.display = 'none';
            
            spawnFood();
            
            if (gameLoop) clearInterval(gameLoop);
            gameLoop = setInterval(update, speed);
        }
        
        // Spawn food
        function spawnFood() {
            const gridWidth = Math.floor(canvas.width / GRID_SIZE);
            const gridHeight = Math.floor(canvas.height / GRID_SIZE);
            
            do {
                food = {
                    x: Math.floor(Math.random() * gridWidth),
                    y: Math.floor(Math.random() * gridHeight)
                };
            } while (snake.some(segment => segment.x === food.x && segment.y === food.y));
        }
        
        // Update game
        function update() {
            if (isGameOver) return;
            
            direction = nextDirection;
            
            // Move snake
            const head = { x: snake[0].x + direction.x, y: snake[0].y + direction.y };
            
            // Check collision with walls
            const gridWidth = Math.floor(canvas.width / GRID_SIZE);
            const gridHeight = Math.floor(canvas.height / GRID_SIZE);
            if (head.x < 0 || head.x >= gridWidth || head.y < 0 || head.y >= gridHeight) {
                gameOver();
                return;
            }
            
            // Check collision with self
            if (snake.some(segment => segment.x === head.x && segment.y === head.y)) {
                gameOver();
                return;
            }
            
            snake.unshift(head);
            
            // Check food collision
            if (head.x === food.x && head.y === food.y) {
                score++;
                document.getElementById('score').textContent = score;
                spawnFood();
                
                // Increase speed every 5 points
                if (score % 5 === 0 && speed > MIN_SPEED) {
                    speed = Math.max(MIN_SPEED, speed - SPEED_INCREASE);
                    clearInterval(gameLoop);
                    gameLoop = setInterval(update, speed);
                }
            } else {
                snake.pop();
            }
            
            draw();
        }
        
        // Draw game
        function draw() {
            // Clear canvas
            ctx.fillStyle = '#000';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw grid
            ctx.strokeStyle = '#111';
            ctx.lineWidth = 1;
            for (let x = 0; x < canvas.width; x += GRID_SIZE) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, canvas.height);
                ctx.stroke();
            }
            for (let y = 0; y < canvas.height; y += GRID_SIZE) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(canvas.width, y);
                ctx.stroke();
            }
            
            // Draw snake
            snake.forEach((segment, index) => {
                if (index === 0) {
                    // Head - brighter green with glow
                    ctx.fillStyle = '#00ff00';
                    ctx.shadowBlur = 10;
                    ctx.shadowColor = '#00ff00';
                } else {
                    // Body - darker green
                    ctx.fillStyle = '#00aa00';
                    ctx.shadowBlur = 5;
                    ctx.shadowColor = '#00aa00';
                }
                ctx.fillRect(
                    segment.x * GRID_SIZE + 1,
                    segment.y * GRID_SIZE + 1,
                    GRID_SIZE - 2,
                    GRID_SIZE - 2
                );
            });
            
            // Draw food
            ctx.fillStyle = '#fff';
            ctx.shadowBlur = 15;
            ctx.shadowColor = '#fff';
            ctx.beginPath();
            ctx.arc(
                food.x * GRID_SIZE + GRID_SIZE / 2,
                food.y * GRID_SIZE + GRID_SIZE / 2,
                GRID_SIZE / 3,
                0,
                Math.PI * 2
            );
            ctx.fill();
            
            ctx.shadowBlur = 0;
        }
        
        // Game over
        function gameOver() {
            isGameOver = true;
            clearInterval(gameLoop);
            
            document.getElementById('finalScore').textContent = score;
            
            if (score > highScore) {
                highScore = score;
                localStorage.setItem('bubbleSnakeHighScore', highScore);
                document.getElementById('highScore').textContent = highScore;
                document.getElementById('newHighScore').style.display = 'block';
            } else {
                document.getElementById('newHighScore').style.display = 'none';
            }
            
            document.getElementById('gameOver').style.display = 'block';
        }
        
        // Restart game
        function restartGame() {
            isGameStarted = true;
            init();
        }
        
        // Keyboard controls
        document.addEventListener('keydown', (e) => {
            // Prevent default for arrow keys and space
            if ([32, 37, 38, 39, 40].includes(e.keyCode)) {
                e.preventDefault();
            }
            
            // Start game with Space on start screen
            if (!isGameStarted && e.key === ' ') {
                startGame();
                return;
            }
            
            // Game controls
            if (isGameStarted) {
                switch(e.key) {
                    case 'ArrowUp':
                        if (direction.y === 0) nextDirection = { x: 0, y: -1 };
                        break;
                    case 'ArrowDown':
                        if (direction.y === 0) nextDirection = { x: 0, y: 1 };
                        break;
                    case 'ArrowLeft':
                        if (direction.x === 0) nextDirection = { x: -1, y: 0 };
                        break;
                    case 'ArrowRight':
                        if (direction.x === 0) nextDirection = { x: 1, y: 0 };
                        break;
                    case ' ':
                        if (isGameOver) restartGame();
                        break;
                }
            }
        });
        
        // Draw initial state
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    </script>
</body>
</html>
```

---

## Step 2: Add the HTML File to Xcode Project

1. **Open Xcode** and locate your FloatyBrowser project
2. **Right-click** on the `FloatyBrowser` folder (blue folder icon)
3. Select **"Add Files to FloatyBrowser..."**
4. Navigate to and select `snake_game.html`
5. **Make sure "Copy items if needed" is checked**
6. Click **"Add"**
7. **Verify** the file appears in the Project Navigator under the FloatyBrowser folder

---

## Step 3: Modify WebViewController.swift

Add network error detection and game loading functionality to `WebViewController.swift`.

### A. Add these two methods to the `WKNavigationDelegate` extension:

```swift
// Add to the WKNavigationDelegate extension
func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    progressIndicator.isHidden = true
    print("❌ Navigation failed: \(error.localizedDescription)")
    if isNetworkError(error) {
        loadSnakeGame()
    }
}

func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    progressIndicator.isHidden = true
    print("❌ Provisional navigation failed: \(error.localizedDescription)")
    if isNetworkError(error) {
        loadSnakeGame()
    }
}
```

### B. Add these helper methods to the WebViewController class:

```swift
// Add these methods to WebViewController class
private func isNetworkError(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorDNSLookupFailed, NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost, NSURLErrorTimedOut:
            return true
        default:
            return false
        }
    }
    return false
}

private func loadSnakeGame() {
    guard let gameURL = Bundle.main.url(forResource: "snake_game", withExtension: "html") else {
        print("❌ Could not find snake_game.html")
        return
    }
    webView.loadFileURL(gameURL, allowingReadAccessTo: gameURL.deletingLastPathComponent())
    print("🎮 FloatyBrowser: Loading Snake Game - no internet detected")
}
```

---

## Step 4: Test the Implementation

### Method 1: Turn off Wi-Fi (Recommended)
1. Run FloatyBrowser from Xcode (⌘R)
2. Turn off your Mac's Wi-Fi
3. Click any bubble to expand
4. Type a URL (e.g., `google.com`) and press Enter
5. The Snake game should appear!

### Method 2: Use a Non-Existent URL
1. Run FloatyBrowser from Xcode (⌘R)
2. Click any bubble to expand
3. Type `http://this-website-does-not-exist-12345.com` and press Enter
4. The Snake game should appear!

---

## Expected Behavior

✅ Game appears automatically on network errors  
✅ "BUBBLE SNAKE" header with bubble emoji  
✅ Score and High Score displayed  
✅ "PLAY" button to start  
✅ Arrow keys control the snake  
✅ Snake grows when eating white bubbles  
✅ Game speeds up every 5 points  
✅ High score persists across sessions  
✅ "Game Over" screen with restart option  
✅ Responsive to window resizing  

---

## Troubleshooting

**Game doesn't appear:**
- Check Xcode console for error messages
- Verify `snake_game.html` is in the "Copy Bundle Resources" build phase:
  1. Click on project in Xcode
  2. Select FloatyBrowser target
  3. Go to "Build Phases" tab
  4. Expand "Copy Bundle Resources"
  5. Ensure `snake_game.html` is listed

**Controls don't work:**
- Make sure the panel is the active window (click on it)
- Press **Space** or click **PLAY** to start the game first

---

## Game Controls

| Key | Action |
|-----|--------|
| **←** | Move Left |
| **→** | Move Right |
| **↑** | Move Up |
| **↓** | Move Down |
| **Space** | Start / Restart |

---

## That's It! 🎉

After following these steps, your Floaty Browser will have a fully functional offline Snake game that appears automatically when there's no internet connection!

