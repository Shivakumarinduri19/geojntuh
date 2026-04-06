# 🌍 GeoGuessr JNTUH — Complete Setup Guide

## What You're Building
A real-world GPS scavenger hunt game for JNTUH campus. Players are shown images of campus locations and must physically walk there to score points.

---

## 📂 File Structure
```
geoguessr-jntuh/
├── index.html      ← The ENTIRE application (open this in a browser!)
├── schema.sql      ← Copy-paste into Supabase SQL Editor
└── SETUP.md        ← This guide
```

---

## ⚡ QUICK START (Demo Mode — No Setup Needed!)

1. Open `index.html` in your browser (Chrome recommended for GPS)
2. Click **"Demo Login (No Supabase)"**
3. Click **"START GAME"**
4. ✅ That's it! The app works in demo mode.

> In demo mode: Auth, leaderboard, and data saving are simulated locally.

---

## 🚀 FULL SETUP (With Supabase — For Production)

### Step 1: Create a Supabase Project
1. Go to [https://supabase.com](https://supabase.com)
2. Click **"New Project"**
3. Choose a name: `geoguessr-jntuh`
4. Set a database password (save this!)
5. Choose region: **Southeast Asia (Singapore)**
6. Click **Create Project** and wait ~2 minutes

### Step 2: Set Up the Database
1. In Supabase dashboard → **SQL Editor** → **New Query**
2. Copy the entire contents of `schema.sql`
3. Paste and click **Run**
4. You should see: "Success. 15 rows inserted."

### Step 3: Enable Realtime
1. Go to **Database** → **Replication**
2. Under "Source", enable these tables:
   - ✅ `users`
   - ✅ `scores`
   - ✅ `game_sessions`

### Step 4: Get Your API Keys
1. Go to **Settings** → **API**
2. Copy:
   - **Project URL** → looks like `https://xyzabc.supabase.co`
   - **anon/public key** → long string starting with `eyJ...`

### Step 5: Update index.html
Open `index.html` in a text editor and find these lines at the top of the `<script>` section:

```javascript
const SUPABASE_URL  = 'YOUR_SUPABASE_URL';    // ← Paste your URL here
const SUPABASE_KEY  = 'YOUR_SUPABASE_ANON_KEY'; // ← Paste your key here
const ADMIN_EMAIL   = 'admin@jntuh.ac.in';      // ← Your admin email
```

Replace with your actual values:
```javascript
const SUPABASE_URL  = 'https://xyzabc.supabase.co';
const SUPABASE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
const ADMIN_EMAIL   = 'your-email@jntuh.ac.in';
```

### Step 6: Add Real JNTUH Photos
Replace the placeholder image URLs in `DEFAULT_LOCATIONS` with actual photos:
```javascript
{ order: 1, name: "Main Entrance Gate", ...,
  img: "https://your-photo-host.com/jntuh-gate.jpg" }
```

**Free photo hosting options:**
- Upload to [Imgur](https://imgur.com) and use the direct link
- Use [Cloudinary](https://cloudinary.com) (free tier)
- Upload to Supabase Storage → copy the public URL

---

## 📱 Using the App on Mobile (Important for GPS!)

Since this is a GPS game, players MUST use it on their phones.

**Option A: Open via USB / Local Network**
1. Find your computer's IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
2. Start a local server:
   ```bash
   # Python
   python -m http.server 8080
   # OR Node.js
   npx serve .
   ```
3. Open on phone: `http://192.168.x.x:8080`

**Option B: Deploy to Netlify (Free, 1 minute!)**
1. Go to [https://netlify.com/drop](https://netlify.com/drop)
2. Drag and drop the `geoguessr-jntuh` folder
3. Get a live URL like `https://random-name.netlify.app`
4. Share with players! ✅

**Option C: Deploy to GitHub Pages**
1. Create a GitHub repo
2. Upload `index.html`
3. Settings → Pages → Deploy from branch `main`
4. URL: `https://yourusername.github.io/repo-name`

---

## ⚙️ Admin Panel

After logging in with the admin email:
1. Click **"⚙️ Admin"** in the navbar
2. **Add locations** with real coordinates and photos
3. Click **"🌱 Seed Default JNTUH Locations"** to add all 15 at once
4. Edit any location by clicking it in the list
5. Click the map preview to drop a pin at the exact spot

**How to get exact GPS coordinates:**
1. Open Google Maps on your phone
2. Stand at the exact location
3. Long-press → coordinates appear at the top
4. Copy Latitude and Longitude into Admin panel

---

## 🎮 Game Flow (How to Play)

```
Login → Choose Mode → Start Game
    ↓
[Round 1-15]:
  Show image → Player walks to location
  → Tap "Mark My Location"
  → GPS captured → Haversine distance calculated
  → Points awarded → Show result on map
  → Next round
    ↓
Final Score → Leaderboard
```

---

## 📊 Scoring System

| Distance from Target | Points |
|---------------------|--------|
| ≤ 5 meters          | 10 pts |
| ≤ 10 meters         | 8 pts  |
| ≤ 20 meters         | 5 pts  |
| ≤ 50 meters         | 2 pts  |
| > 50 meters         | 0 pts  |

**Max score: 150 points** (15 rounds × 10 pts)

---

## 🛡️ Anti-Cheat Features

1. **GPS Accuracy Check**: If device reports accuracy > 50m, submission is rejected
2. **Timer**: 60 seconds per location — can't take too long
3. **No manual pin drop**: User cannot manually place a pin; location is taken from device GPS
4. **Server-side validation**: All scores saved with timestamp and GPS accuracy metadata

---

## 🏆 Leaderboard (Realtime)

- Uses **Supabase Realtime** (WebSockets)
- Updates instantly when anyone completes a game
- Shows: Individual scores, Team scores, Daily scores
- Your row is highlighted in the leaderboard

---

## 🗺️ Map Features

- **OpenStreetMap** tiles (free, no API key needed)
- Shows your current GPS location in real-time (blue dot)
- After each round: shows correct location (orange pin) + your position + a line between them
- Admin panel has a clickable map to set location coordinates

---

## 🔧 Customization

### Change Timer
```javascript
const ROUND_TIMER = 60; // Change to 90 or 120 for more time
```

### Change Number of Rounds
```javascript
const TOTAL_ROUNDS = 15; // Change to 10 for a shorter game
```

### Change Scoring
In the `calculatePoints()` function:
```javascript
function calculatePoints(distanceMeters) {
  if (distanceMeters <= 5)  return 10;  // Adjust thresholds here
  if (distanceMeters <= 10) return 8;
  ...
}
```

---

## ❓ Common Issues

| Problem | Solution |
|---------|----------|
| GPS not working | Must use HTTPS (not HTTP) OR localhost. Use Netlify deployment. |
| Map not loading | Check internet connection; OpenStreetMap needs internet |
| Login fails | Check your Supabase URL and key in the config section |
| "GPS accuracy too low" | Go outside or near a window; indoor GPS is poor |
| Admin button missing | Login with the email set in `ADMIN_EMAIL` constant |

---

## 🎯 Hackathon Demo Tips

1. **Use Demo Mode** for the presentation (no Supabase setup needed)
2. **Pre-load the app** on all team phones before demo
3. **Show the leaderboard** updating in real-time across devices
4. **Walk to 1-2 locations** live during the demo for effect
5. Use the **Admin panel** to show how organizers add locations

---

## 📞 Tech Stack Summary

| Component | Technology | Why |
|-----------|-----------|-----|
| Frontend  | Vanilla HTML/CSS/JS | No build step, beginner-friendly |
| Maps      | Leaflet.js + OpenStreetMap | 100% free, no API key |
| Auth      | Supabase Auth | Built-in email/password |
| Database  | Supabase PostgreSQL | Free tier, realtime |
| Distance  | Haversine Formula | Accurate GPS distance |
| Deployment | Netlify/GitHub Pages | Free, instant |

Built for JNTUH Hackathon 2024 🚀
