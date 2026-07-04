// CONFIGURATION
const DISCORD_INVITE_URL = "https://discord.gg/TnfdNJd9a";

// WIZARD STATE
let selectedPreference = null;
let audioCtx = null;

// Mouse coordinates
let mouseX = -9999;
let mouseY = -9999;

// WEB AUDIO SYNTHESIZER (SIMPLE SYNCHRONOUS BOOTSTRAP)
function initAudio() {
    try {
        if (!audioCtx) {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }
        if (audioCtx.state === 'suspended') {
            audioCtx.resume();
        }
    } catch (e) {
        console.warn("AudioContext initialization failed:", e);
    }
}

// Warm up AudioContext on earliest click to unlock hardware audio thread
window.addEventListener("mousedown", initAudio, { once: true });
window.addEventListener("touchstart", initAudio, { once: true });
window.addEventListener("keydown", initAudio, { once: true });
window.addEventListener("click", initAudio, { once: true });
window.addEventListener("touchend", initAudio, { once: true });

// Snappy mechanical click (warm & responsive)
function playClickSound(volumeMultiplier = 1.0) {
    try {
        initAudio();
        if (!audioCtx) return;
        const time = audioCtx.currentTime;
        
        // Transient snap (fast decay)
        const snapOsc = audioCtx.createOscillator();
        const snapGain = audioCtx.createGain();
        snapOsc.type = "triangle";
        snapOsc.frequency.setValueAtTime(1600, time);
        snapOsc.frequency.exponentialRampToValueAtTime(900, time + 0.01);
        
        snapGain.gain.setValueAtTime(0.02 * volumeMultiplier, time); 
        snapGain.gain.exponentialRampToValueAtTime(0.0001, time + 0.01);
        
        snapOsc.connect(snapGain);
        snapGain.connect(audioCtx.destination);
        
        // Warm casing thump
        const bodyOsc = audioCtx.createOscillator();
        const bodyGain = audioCtx.createGain();
        bodyOsc.type = "sine";
        bodyOsc.frequency.setValueAtTime(140, time);
        bodyOsc.frequency.linearRampToValueAtTime(60, time + 0.03);
        
        bodyGain.gain.setValueAtTime(0.025 * volumeMultiplier, time); 
        bodyGain.gain.exponentialRampToValueAtTime(0.0001, time + 0.03);
        
        bodyOsc.connect(bodyGain);
        bodyGain.connect(audioCtx.destination);
        
        snapOsc.start();
        snapOsc.stop(time + 0.015);
        
        bodyOsc.start();
        bodyOsc.stop(time + 0.035);
    } catch(e) {
        console.log("playClickSound error:", e);
    }
}


// Slider glissando (portamento slide)
let sliderOsc = null;
let sliderGain = null;

function playSliderSound(value) {
    try {
        initAudio();
        if (!audioCtx) return;
        const time = audioCtx.currentTime;
        const freq = 280 + (value - 1) * 35;
        
        if (!sliderOsc) {
            sliderOsc = audioCtx.createOscillator();
            sliderGain = audioCtx.createGain();
            
            sliderOsc.type = "sine";
            sliderOsc.frequency.setValueAtTime(freq, time);
            
            sliderGain.gain.setValueAtTime(0, time);
            
            sliderOsc.connect(sliderGain);
            sliderGain.connect(audioCtx.destination);
            sliderOsc.start();
        }
        
        sliderOsc.frequency.setTargetAtTime(freq, time, 0.005);
        
        sliderGain.gain.cancelScheduledValues(time);
        sliderGain.gain.setValueAtTime(sliderGain.gain.value, time);
        sliderGain.gain.linearRampToValueAtTime(0.015, time + 0.005); 
        sliderGain.gain.exponentialRampToValueAtTime(0.0001, time + 0.12);
    } catch(e) {
        console.log("playSliderSound error:", e);
    }
}

// Wind WHOOSH warp sound (Warm bandpass noise)
function playWarpSound(duration) {
    try {
        initAudio();
        if (!audioCtx) return;
        const time = audioCtx.currentTime;
        
        const bufferSize = audioCtx.sampleRate * duration;
        const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }
        
        const noise = audioCtx.createBufferSource();
        noise.buffer = buffer;
        
        const filter = audioCtx.createBiquadFilter();
        filter.type = "bandpass";
        filter.Q.setValueAtTime(5, time);
        filter.frequency.setValueAtTime(220, time);
        filter.frequency.exponentialRampToValueAtTime(550, time + duration);
        
        const noiseGain = audioCtx.createGain();
        noiseGain.gain.setValueAtTime(0.01, time); 
        noiseGain.gain.linearRampToValueAtTime(0.035, time + duration * 0.5); 
        noiseGain.gain.linearRampToValueAtTime(0.001, time + duration);
        
        noise.connect(filter);
        filter.connect(noiseGain);
        noiseGain.connect(audioCtx.destination);
        
        noise.start();
        noise.stop(time + duration);
    } catch(e) {
        console.log("playWarpSound error:", e);
    }
}

// Celestial harmony sound for assembly phase (Maj3 chord sweeping up)
function playAssembleSound(duration) {
    try {
        initAudio();
        if (!audioCtx) return;
        const time = audioCtx.currentTime;
        
        const osc1 = audioCtx.createOscillator();
        const osc2 = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        
        osc1.type = "sine";
        osc1.frequency.setValueAtTime(220, time); // A3
        osc1.frequency.exponentialRampToValueAtTime(440, time + duration); // A4
        
        osc2.type = "sine";
        osc2.frequency.setValueAtTime(277.18, time); // C#4
        osc2.frequency.exponentialRampToValueAtTime(554.37, time + duration); // C#5
        
        gain.gain.setValueAtTime(0.001, time);
        gain.gain.linearRampToValueAtTime(0.025, time + duration * 0.4); 
        gain.gain.linearRampToValueAtTime(0.01, time + duration * 0.8);
        gain.gain.linearRampToValueAtTime(0.0001, time + duration); 
        
        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(audioCtx.destination);
        
        osc1.start();
        osc2.start();
        
        osc1.stop(time + duration);
        osc2.stop(time + duration);
    } catch(e) {
        console.log("playAssembleSound error:", e);
    }
}

// Pleasant deep explosion boom
function playExplosionSound(duration) {
    try {
        initAudio();
        if (!audioCtx) return;
        const time = audioCtx.currentTime;
        
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        
        osc.type = "sine";
        osc.frequency.setValueAtTime(110, time);
        osc.frequency.exponentialRampToValueAtTime(20, time + duration);
        
        gain.gain.setValueAtTime(0.05, time); 
        gain.gain.exponentialRampToValueAtTime(0.001, time + duration);
        
        const bufferSize = audioCtx.sampleRate * duration;
        const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }
        
        const noise = audioCtx.createBufferSource();
        noise.buffer = buffer;
        
        const filter = audioCtx.createBiquadFilter();
        filter.type = "lowpass";
        filter.frequency.setValueAtTime(300, time);
        filter.frequency.exponentialRampToValueAtTime(30, time + duration);
        
        const noiseGain = audioCtx.createGain();
        noiseGain.gain.setValueAtTime(0.01, time); 
        noiseGain.gain.exponentialRampToValueAtTime(0.001, time + duration);
        
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        
        noise.connect(filter);
        filter.connect(noiseGain);
        noiseGain.connect(audioCtx.destination);
        
        osc.start();
        noise.start();
        
        osc.stop(time + duration);
        noise.stop(time + duration);
    } catch(e) {
        console.log("playExplosionSound error:", e);
    }
}

// UPDATE PROGRESS BAR
function updateProgressBar(step) {
    const bar = document.getElementById("progress-bar-fill");
    if (bar) {
        const percentages = { 1: 25, 2: 50, 3: 75, 4: 100, 5: 100 };
        bar.style.width = `${percentages[step]}%`;
    }
}

// NAVIGATION
function nextStep(current, next) {
    if (current === 1) {
        playClickSound(0.15); // Make the first button click sound softer!
    } else {
        playClickSound(1.0);
    }
    
    const currentCard = document.getElementById(`step-${current}`);
    const nextCard = document.getElementById(`step-${next}`);
    
    if (currentCard && nextCard) {
        updateProgressBar(next);
        
        currentCard.style.opacity = "0";
        currentCard.style.transform = "rotateX(-10deg) translateY(-20px)";
        
        setTimeout(() => {
            currentCard.classList.remove('active');
            nextCard.classList.add('active');
            nextCard.offsetHeight;
            nextCard.style.opacity = "1";
            nextCard.style.transform = "rotateX(0) translateY(0)";
        }, 300);
    }
}

// STEP 2: LOVE SLIDER LOGIC
function updateLoveSlider(val) {
    const smiley = document.getElementById("smiley-indicator");
    const label = document.getElementById("slider-val-label");
    const btnNext = document.getElementById("btn-love-next");
    const alertBox = document.getElementById("love-alert");
    const successBox = document.getElementById("love-success");
    
    label.innerText = val;
    
    // Play sound ONLY if this is a user-initiated change (prevValue is already set)
    if (label.dataset.prevValue && label.dataset.prevValue !== val) {
        playSliderSound(val);
    }
    label.dataset.prevValue = val;
    
    if (val <= 2) {
        smiley.innerText = "😢";
        smiley.style.transform = "scale(0.8) rotate(-10deg)";
    } else if (val <= 4) {
        smiley.innerText = "🤨";
        smiley.style.transform = "scale(0.95) rotate(-5deg)";
    } else if (val == 5) {
        smiley.innerText = "😐";
        smiley.style.transform = "scale(1.0) rotate(0deg)";
    } else if (val <= 7) {
        smiley.innerText = "😊";
        smiley.style.transform = "scale(1.15) rotate(5deg)";
    } else if (val <= 9) {
        smiley.innerText = "😍";
        smiley.style.transform = "scale(1.3) rotate(10deg)";
    } else {
        smiley.innerText = "🐐";
        smiley.style.transform = "scale(1.5) rotate(0deg)";
    }

    if (val > 5) {
        btnNext.disabled = false;
        alertBox.style.display = "none";
        successBox.style.display = "block";
    } else {
        btnNext.disabled = true;
        alertBox.style.display = "block";
        successBox.style.display = "none";
    }
}

// STEP 3: PREFERENCE SELECTION
function selectPref(element, prefKey) {
    playClickSound();
    
    const siblings = document.querySelectorAll(".pref-card");
    siblings.forEach(card => card.classList.remove("selected"));
    
    element.classList.add("selected");
    selectedPreference = prefKey;
    
    document.getElementById("btn-pref-next").disabled = false;
}


// --- INTERACTIVE TILT & GLOW ORB & MOUSE SPARKLES ---
const container = document.getElementById("tilt-card-container");
const glow = document.getElementById("cursor-glow");
let sparkles = [];

window.addEventListener("mousemove", (e) => {
    mouseX = e.clientX;
    mouseY = e.clientY;
    
    if (glow) {
        glow.style.left = `${e.clientX}px`;
        glow.style.top = `${e.clientY}px`;
    }
    
    if (container && !isWarping) {
        const rect = container.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width - 0.5;
        const y = (e.clientY - rect.top) / rect.height - 0.5;
        
        const tiltX = (y * 12).toFixed(2);
        const tiltY = (-x * 12).toFixed(2);
        
        container.style.transform = `rotateX(${tiltX}deg) rotateY(${tiltY}deg)`;
    }

    // Generate tiny mouse trail sparkle particles
    if (Math.random() < 0.25) {
        sparkles.push({
            x: e.clientX,
            y: e.clientY,
            vx: (Math.random() - 0.5) * 2,
            vy: (Math.random() - 0.5) * 2 - 1,
            alpha: 1.0,
            size: Math.random() * 2 + 1
        });
    }
});

window.addEventListener("mouseleave", () => {
    mouseX = -9999;
    mouseY = -9999;
    if (container && !isWarping) {
        container.style.transform = "rotateX(0deg) rotateY(0deg)";
    }
});


// --- 3D STARS CANVAS ENGINE & ASSEMBLY & EXPLOSION ---
const canvas = document.getElementById("starfield");
const ctx = canvas.getContext("2d");

let stars = [];
let textPoints = [];
let speed = 0.3;
let targetSpeed = 0.3;
let isWarping = false;
let currentState = "float";
let assemblyProgress = 0;

// Timeline Timestamps & Visuals
let assemblyStartTime = 0;
let explosionStartTime = 0;
let flashAlpha = 0;

// Cosmic Nebula Dust Clouds
let dustClouds = [];
function initDust() {
    dustClouds = [];
    for (let i = 0; i < 5; i++) {
        dustClouds.push({
            x: Math.random() * window.innerWidth,
            y: Math.random() * window.innerHeight,
            vx: (Math.random() - 0.5) * 0.4,
            vy: (Math.random() - 0.5) * 0.4,
            radius: 130 + Math.random() * 110,
            color: i % 2 === 0 ? "rgba(153, 51, 255, 0.025)" : "rgba(255, 0, 127, 0.025)"
        });
    }
}
initDust();
window.addEventListener("resize", initDust);

// Scan text coordinates from off-screen canvas
function generateTextPoints(text) {
    try {
        const tempCanvas = document.createElement("canvas");
        const tempCtx = tempCanvas.getContext("2d");
        if (!tempCtx) return [];
        
        tempCanvas.width = 1000;
        tempCanvas.height = 300;
        
        tempCtx.fillStyle = "#ffffff";
        tempCtx.font = "bold 90px 'Outfit', sans-serif";
        tempCtx.textAlign = "center";
        tempCtx.textBaseline = "middle";
        tempCtx.fillText(text, tempCanvas.width / 2, tempCanvas.height / 2);
        
        const imgData = tempCtx.getImageData(0, 0, tempCanvas.width, tempCanvas.height);
        const data = imgData.data;
        
        const step = 5; 
        const points = [];
        
        for (let y = 0; y < tempCanvas.height; y += step) {
            for (let x = 0; x < tempCanvas.width; x += step) {
                const index = (y * tempCanvas.width + x) * 4;
                const alpha = data[index + 3];
                if (alpha > 128) {
                    points.push({
                        x: x - tempCanvas.width / 2,
                        y: y - tempCanvas.height / 2
                    });
                }
            }
        }
        return points;
    } catch(e) {
        console.error("Text scan failed:", e);
        return [];
    }
}

function resizeCanvas() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}
window.addEventListener("resize", resizeCanvas);
resizeCanvas();

class Star {
    constructor(index) {
        this.index = index;
        this.reset();
        
        this.assembled = false;
        this.exploded = false;
        this.startX = 0;
        this.startY = 0;
        
        this.currentX = 0;
        this.currentY = 0;
        this.size = 1.5;
        this.opacity = 1;
        
        this.vx = 0;
        this.vy = 0;
        
        this.colorGroup = index % 4; 
    }
    
    reset() {
        this.x = (Math.random() - 0.5) * canvas.width * 2;
        this.y = (Math.random() - 0.5) * canvas.height * 2;
        this.z = Math.random() * canvas.width;
    }
    
    update() {
        const cx = canvas.width / 2;
        const cy = canvas.height / 2;
        
        if (currentState === "float" || currentState === "warp") {
            this.z -= speed;
            if (this.z <= 0) {
                this.reset();
            }
            this.currentX = (this.x / this.z) * cx + cx;
            this.currentY = (this.y / this.z) * cy + cy;
            
            // Star Gravity Attraction (pull towards mouse cursor on standard screens)
            if (currentState === "float" && mouseX > -1000) {
                const dx = mouseX - this.currentX;
                const dy = mouseY - this.currentY;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < 180) {
                    const pull = (1 - dist / 180) * 1.5;
                    this.x += (mouseX - cx - this.x) * pull * 0.01;
                    this.y += (mouseY - cy - this.y) * pull * 0.01;
                }
            }
            
            this.size = Math.max(1, (1 - this.z / canvas.width) * (currentState === "warp" ? 4.5 : 3.5));
            this.opacity = Math.min(1, 1 - this.z / canvas.width);
            
        } else if (currentState === "assemble") {
            if (!textPoints || textPoints.length === 0) return; 
            
            const baseWidth = 800;
            const scale = Math.min(1, (canvas.width * 0.85) / baseWidth);
            
            const targetPoint = textPoints[this.index % textPoints.length];
            if (!targetPoint) return; 
            
            const targetX = cx + targetPoint.x * scale;
            const targetY = cy + targetPoint.y * scale;
            
            if (!this.assembled) {
                this.startX = this.currentX;
                this.startY = this.currentY;
                this.assembled = true;
            }
            
            // Dynamic Horizontal Chroma Gradient mapping
            const tx = targetPoint.x;
            if (tx < -120) {
                this.colorGroup = 1; // Pink
            } else if (tx < 0) {
                this.colorGroup = 2; // Purple
            } else if (tx < 120) {
                this.colorGroup = 3; // Blue
            } else {
                this.colorGroup = 0; // Gold
            }
            
            const t = easeOutExpo(assemblyProgress);
            this.currentX = this.startX + (targetX - this.startX) * t;
            this.currentY = this.startY + (targetY - this.startY) * t;
            
            // Sound-reactive pulsing (Size pulses slightly on assembly crescendo!)
            const soundPulse = (currentState === "assemble") ? (1 + Math.sin(assemblyProgress * Math.PI) * 0.15) : 1;
            this.size = 3.0 * scale * soundPulse;
            this.opacity = 1;
            
        } else if (currentState === "still") {
            if (!textPoints || textPoints.length === 0) return;
            const baseWidth = 800;
            const scale = Math.min(1, (canvas.width * 0.85) / baseWidth);
            const targetPoint = textPoints[this.index % textPoints.length];
            if (!targetPoint) return;
            
            // Organic wave breathing motion
            const wave = Math.sin(Date.now() * 0.0035 + targetPoint.x * 0.015) * 5;
            
            this.currentX = cx + targetPoint.x * scale;
            this.currentY = cy + targetPoint.y * scale + wave;
            this.size = 3.0 * scale;
            this.opacity = 1;
            
        } else if (currentState === "explode") {
            if (!this.exploded) {
                const dx = this.currentX - cx;
                const dy = this.currentY - cy;
                const dist = Math.sqrt(dx * dx + dy * dy) || 1;
                
                const speedFactor = 4 + Math.random() * 12;
                this.vx = (dx / dist) * speedFactor;
                this.vy = (dy / dist) * speedFactor;
                this.exploded = true;
            }
            
            this.currentX += this.vx;
            this.currentY += this.vy;
            this.size *= 0.95; 
            
            this.opacity = Math.max(0, 1 - (Date.now() - explosionStartTime) / 1500);
        }
    }
}

function easeOutExpo(x) {
    return x === 1 ? 1 : 1 - Math.pow(2, -10 * x);
}

// Setup stars dynamically, with safety checking for ready state
function initStars() {
    console.log("Generating text points...");
    textPoints = generateTextPoints("KENNSORA");
    const numStars = textPoints.length; 
    
    stars = [];
    for (let i = 0; i < numStars; i++) {
        stars.push(new Star(i));
    }
}

// Bulletproof document ready checking to trigger initialization safely
if (document.readyState === "complete" || document.readyState === "interactive") {
    initStars();
} else {
    window.addEventListener("load", initStars);
}

// Safely bind to fonts load event (checks if fonts API is supported)
if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(() => {
        if (currentState === "float") {
            initStars();
        }
    }).catch(e => {
        console.warn("Fonts ready promise failed:", e);
        initStars();
    });
}

// Animation loop
function animate() {
    // Clear with transparency to render motion trails during warp / assembly
    if (currentState === "warp" || currentState === "assemble" || currentState === "still") {
        ctx.fillStyle = "rgba(7, 7, 20, 0.22)"; 
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    } else {
        ctx.fillStyle = "#070714";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    
    drawSpaceNebulas();
    
    speed += (targetSpeed - speed) * 0.1;
    
    stars.forEach(star => star.update());
    
    // Draw Cosmic Constellation Lines during STILL phase!
    if (currentState === "still") {
        ctx.lineWidth = 0.55;
        for (let i = 0; i < stars.length; i += 2) {
            const s1 = stars[i];
            // Connect to neighboring particles of same color group
            for (let j = i + 1; j < Math.min(stars.length, i + 12); j++) {
                const s2 = stars[j];
                if (s1.colorGroup === s2.colorGroup) {
                    const dx = s1.currentX - s2.currentX;
                    const dy = s1.currentY - s2.currentY;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < 23) {
                        ctx.strokeStyle = s1.colorGroup === 0 ? "rgba(255, 215, 0, 0.12)" :
                                          s1.colorGroup === 1 ? "rgba(255, 0, 127, 0.12)" :
                                          s1.colorGroup === 2 ? "rgba(153, 51, 255, 0.12)" :
                                                                "rgba(0, 204, 255, 0.12)";
                        ctx.beginPath();
                        ctx.moveTo(s1.currentX, s1.currentY);
                        ctx.lineTo(s2.currentX, s2.currentY);
                        ctx.stroke();
                    }
                }
            }
        }
    }
    
    if (currentState === "assemble") {
        const elapsed = Date.now() - assemblyStartTime;
        assemblyProgress = Math.min(1.0, elapsed / 3000); 
        
        // Dynamically update the top progress bar from 0% to 100% in sync with assembly!
        const bar = document.getElementById("progress-bar-fill");
        if (bar) {
            bar.style.width = `${assemblyProgress * 100}%`;
        }
        
        if (assemblyProgress >= 1.0) {
            currentState = "still";
            setTimeout(triggerExplosion, 250); 
        }
    }
    
    // DRAW BATCHED SPARKLES TRAIL / SHOCKWAVE BLAST PARTICLES
    if (sparkles.length > 0) {
        sparkles.forEach(s => {
            s.x += s.vx;
            s.y += s.vy;
            if (s.vx !== undefined) s.vx *= 0.98;
            if (s.vy !== undefined) s.vy *= 0.98;
            s.alpha -= 0.018; 
        });
        sparkles = sparkles.filter(s => s.alpha > 0);
        
        sparkles.forEach(s => {
            ctx.fillStyle = s.color || `rgba(0, 204, 255, ${s.alpha})`;
            ctx.fillRect(s.x, s.y, s.size, s.size);
        });
    }
    
    // DRAW BATCHED STARS RENDER PASSES
    if (currentState === "assemble" || currentState === "still" || currentState === "explode") {
        const twinkle = currentState === "still" ? Math.sin(Date.now() * 0.006) * 0.15 : 0;
        
        for (let g = 0; g < 4; g++) {
            const op = Math.max(0.1, 0.55 + twinkle);
            
            ctx.fillStyle = g === 0 ? `rgba(255, 215, 0, ${op})` :
                            g === 1 ? `rgba(255, 0, 127, ${op})` :
                            g === 2 ? `rgba(153, 51, 255, ${op})` :
                                      `rgba(0, 204, 255, ${op})`;
            
            stars.forEach(star => {
                if (star.colorGroup === g && star.opacity > 0) {
                    const s = star.size;
                    ctx.fillRect(star.currentX - s - 1, star.currentY - s - 1, (s * 2) + 2, (s * 2) + 2);
                }
            });
        }
        
        // Pass 2: White cores
        ctx.fillStyle = "#ffffff";
        stars.forEach(star => {
            if (star.opacity > 0) {
                const s = star.size;
                ctx.fillRect(star.currentX - s/2, star.currentY - s/2, s, s);
            }
        });
        
    } else {
        ctx.fillStyle = "rgba(255, 255, 255, 0.9)";
        stars.forEach(star => {
            const s = star.size;
            ctx.fillRect(star.currentX - s/2, star.currentY - s/2, s, s);
        });
    }
    
    // Draw Screen Flash Overlay on explosion
    if (flashAlpha > 0) {
        ctx.fillStyle = `rgba(255, 255, 255, ${flashAlpha})`;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        flashAlpha -= 0.045; // Fade out flash overlay
    }
    
    requestAnimationFrame(animate);
}
animate();

function drawSpaceNebulas() {
    const time = Date.now() * 0.0003;
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    
    // Draw drifting Space Dust clouds (Nebula fog)
    dustClouds.forEach(c => {
        c.x += c.vx;
        c.y += c.vy;
        if (c.x < -c.radius) c.x = canvas.width + c.radius;
        if (c.x > canvas.width + c.radius) c.x = -c.radius;
        if (c.y < -c.radius) c.y = canvas.height + c.radius;
        if (c.y > canvas.height + c.radius) c.y = -c.radius;

        const grad = ctx.createRadialGradient(c.x, c.y, 10, c.x, c.y, c.radius);
        grad.addColorStop(0, c.color);
        grad.addColorStop(1, "transparent");
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    });
    
    const x1 = cx + Math.sin(time) * 100;
    const y1 = cy + Math.cos(time) * 50;
    const grad1 = ctx.createRadialGradient(x1, y1, 10, x1, y1, 400);
    grad1.addColorStop(0, "rgba(153, 51, 255, 0.07)");
    grad1.addColorStop(1, "transparent");
    ctx.fillStyle = grad1;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const x2 = cx - Math.sin(time * 0.8) * 120;
    const y2 = cy - Math.cos(time * 0.8) * 60;
    const grad2 = ctx.createRadialGradient(x2, y2, 10, x2, y2, 350);
    grad2.addColorStop(0, "rgba(255, 0, 127, 0.05)");
    grad2.addColorStop(1, "transparent");
    ctx.fillStyle = grad2;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Soft pulsing nebula glow behind the assembled text
    if (currentState === "assemble" || currentState === "still") {
        const baseWidth = 800;
        const scale = Math.min(1, (canvas.width * 0.85) / baseWidth);
        const pulse = 0.5 + Math.sin(Date.now() * 0.003) * 0.15;
        
        const grad = ctx.createRadialGradient(cx, cy, 10, cx, cy, 320 * scale);
        grad.addColorStop(0, `rgba(153, 51, 255, ${0.18 * pulse})`);
        grad.addColorStop(0.5, `rgba(255, 0, 127, ${0.08 * pulse})`);
        grad.addColorStop(1, "transparent");
        
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
}

function triggerExplosion() {
    currentState = "explode";
    explosionStartTime = Date.now();
    flashAlpha = 0.75; // Set full-screen flash alpha!
    playExplosionSound(1.5);
    
    // Hide the entire tilt-card-container so the explosion is unobstructed!
    const containerEl = document.getElementById("tilt-card-container");
    if (containerEl) {
        containerEl.style.opacity = "0";
        containerEl.style.transition = "opacity 0.3s ease";
    }
    
    // Generate circular neon shockwave blast ring
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    for (let a = 0; a < 80; a++) {
        const angle = (a / 80) * Math.PI * 2;
        const blastSpeed = 8 + Math.random() * 5;
        sparkles.push({
            x: cx,
            y: cy,
            vx: Math.cos(angle) * blastSpeed,
            vy: Math.sin(angle) * blastSpeed,
            alpha: 1.0,
            size: Math.random() * 3 + 2,
            color: a % 2 === 0 ? "rgba(0, 204, 255, 0.95)" : "rgba(255, 0, 127, 0.95)"
        });
    }
    
    setTimeout(() => {
        window.location.href = DISCORD_INVITE_URL;
    }, 1500);
}

function triggerWarpSpeed() {
    isWarping = true;
    
    playWarpSound(1.5);
    
    if (container) {
        container.style.transform = "rotateX(0deg) rotateY(0deg)";
    }
    if (glow) {
        glow.style.display = "none";
    }
    
    nextStep(4, 5);
    
    currentState = "warp";
    targetSpeed = 6.0;
    
    setTimeout(() => {
        currentState = "assemble";
        assemblyStartTime = Date.now();
        playAssembleSound(3.0); 
        
        // Reset progress bar to 0% to start the fill-up animation!
        const bar = document.getElementById("progress-bar-fill");
        if (bar) {
            bar.style.width = "0%";
        }
        
        const card5 = document.getElementById("step-5");
        if (card5) {
            card5.style.opacity = "0";
            card5.style.transition = "opacity 0.5s ease";
        }
    }, 1500);
}

// Initialize default views (Prevents playing sound and block AudioContext on load!)
const sliderLabel = document.getElementById("slider-val-label");
if (sliderLabel) {
    sliderLabel.dataset.prevValue = "3";
}
updateLoveSlider(3);
updateProgressBar(1);
