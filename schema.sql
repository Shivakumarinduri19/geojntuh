-- ══════════════════════════════════════════════════════════════
-- GeoGuessr JNTUH – Supabase Database Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ══════════════════════════════════════════════════════════════

-- ─── ENABLE UUID EXTENSION ───
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────
-- TABLE: users
-- Stores player profiles, scores, and team info
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL DEFAULT 'Explorer',
  team          TEXT,                   -- Optional team name
  total_score   INTEGER DEFAULT 0,      -- Cumulative score across all games
  best_score    INTEGER DEFAULT 0,      -- Best single game score
  games_played  INTEGER DEFAULT 0,      -- Total games completed
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Row Level Security: Users can read all, but update only their own row
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read users"  ON public.users FOR SELECT USING (true);
CREATE POLICY "Users update own row"   ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users insert own row"   ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- ─────────────────────────────────────────────
-- TABLE: locations
-- The 15 campus locations used in each game
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.locations (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,             -- e.g. "Main Entrance Gate"
  hint       TEXT NOT NULL,             -- Clue shown to player
  lat        DECIMAL(10,7) NOT NULL,    -- Latitude  (e.g. 17.4954)
  lng        DECIMAL(10,7) NOT NULL,    -- Longitude (e.g. 78.3928)
  image_url  TEXT,                      -- URL of location photo
  "order"    INTEGER DEFAULT 1,         -- Game order (1-15)
  active     BOOLEAN DEFAULT TRUE,      -- Can disable without deleting
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Anyone can read locations; only admins can write (handled in app)
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read locations" ON public.locations FOR SELECT USING (active = true);
CREATE POLICY "Auth users can manage locations" ON public.locations FOR ALL USING (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────
-- TABLE: game_sessions
-- One row per game a user plays
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.game_sessions (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID REFERENCES public.users(id) ON DELETE CASCADE,
  mode         TEXT DEFAULT 'solo' CHECK (mode IN ('solo', 'team')),
  team_name    TEXT,                    -- Team name if mode='team'
  total_score  INTEGER DEFAULT 0,
  completed    BOOLEAN DEFAULT FALSE,
  started_at   TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own sessions" ON public.game_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own sessions" ON public.game_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own sessions" ON public.game_sessions FOR UPDATE USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────
-- TABLE: scores
-- One row per location attempt within a game session
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.scores (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id       UUID REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  user_id          UUID REFERENCES public.users(id) ON DELETE CASCADE,
  location_index   INTEGER NOT NULL,       -- 0-14
  location_name    TEXT,
  points           INTEGER DEFAULT 0,      -- 0, 2, 5, 8, or 10
  distance_meters  DECIMAL(10,2),          -- How far from target (null if skipped)
  time_taken       INTEGER,                -- Seconds taken
  team_name        TEXT,
  submitted_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own scores" ON public.scores FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert scores"  ON public.scores FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────
-- FUNCTION: auto-update best_score and games_played
-- Called after each completed game session
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.completed = TRUE AND OLD.completed = FALSE THEN
    UPDATE public.users SET
      games_played = games_played + 1,
      total_score  = total_score + NEW.total_score,
      best_score   = GREATEST(best_score, NEW.total_score),
      updated_at   = NOW()
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_user_stats
  AFTER UPDATE ON public.game_sessions
  FOR EACH ROW EXECUTE FUNCTION update_user_stats();

-- ─────────────────────────────────────────────
-- VIEW: leaderboard
-- Easy query for rankings
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT
  u.id,
  u.name,
  u.team,
  u.best_score,
  u.total_score,
  u.games_played,
  RANK() OVER (ORDER BY u.best_score DESC) AS rank
FROM public.users u
WHERE u.games_played > 0
ORDER BY u.best_score DESC;

-- VIEW: team_leaderboard
CREATE OR REPLACE VIEW public.team_leaderboard AS
SELECT
  team,
  SUM(best_score) AS team_score,
  COUNT(*) AS member_count,
  RANK() OVER (ORDER BY SUM(best_score) DESC) AS rank
FROM public.users
WHERE team IS NOT NULL AND team != ''
GROUP BY team
ORDER BY team_score DESC;

-- ─────────────────────────────────────────────
-- ENABLE REALTIME (run in Supabase Dashboard)
-- ─────────────────────────────────────────────
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.scores;

-- ─────────────────────────────────────────────
-- SAMPLE DATA: Insert 15 JNTUH Locations
-- (Run after seeding from Admin panel OR manually)
-- ─────────────────────────────────────────────
INSERT INTO public.locations (name, hint, lat, lng, image_url, "order") VALUES
  ('Main Entrance Gate',    'The grand gate you pass through every day.',               17.4954, 78.3928, 'https://picsum.photos/seed/jntuh1/800/500',  1),
  ('University Library',    'Multi-storey building near the center of campus.',         17.4944, 78.3935, 'https://picsum.photos/seed/jntuh2/800/500',  2),
  ('Administrative Block',  'Where all official university work happens.',              17.4948, 78.3922, 'https://picsum.photos/seed/jntuh3/800/500',  3),
  ('Sports Complex',        'Cricket, football, and more! Near the back of campus.',   17.4930, 78.3940, 'https://picsum.photos/seed/jntuh4/800/500',  4),
  ('University Auditorium', 'Hosts convocations and cultural events.',                 17.4950, 78.3918, 'https://picsum.photos/seed/jntuh5/800/500',  5),
  ('Central Canteen',       'The busiest place at lunch time!',                        17.4935, 78.3930, 'https://picsum.photos/seed/jntuh6/800/500',  6),
  ('Boys Hostel Block',     'Multiple buildings near the eastern side.',               17.4925, 78.3945, 'https://picsum.photos/seed/jntuh7/800/500',  7),
  ('Girls Hostel Block',    'Secured hostel on the southern side of campus.',          17.4920, 78.3935, 'https://picsum.photos/seed/jntuh8/800/500',  8),
  ('Mechanical Engg Block', 'Heavy machinery labs inside.',                            17.4942, 78.3925, 'https://picsum.photos/seed/jntuh9/800/500',  9),
  ('Civil Engg Block',      'Home to surveying equipment and concrete labs.',          17.4938, 78.3920, 'https://picsum.photos/seed/jntuh10/800/500', 10),
  ('CSE Department Block',  'The hub of tech. Computer labs everywhere.',              17.4955, 78.3932, 'https://picsum.photos/seed/jntuh11/800/500', 11),
  ('ECE Department Block',  'Electronics and circuits lab.',                           17.4958, 78.3928, 'https://picsum.photos/seed/jntuh12/800/500', 12),
  ('EEE Department Block',  'High voltage area. Near the power substation.',           17.4945, 78.3915, 'https://picsum.photos/seed/jntuh13/800/500', 13),
  ('IT Department Block',   'Newer building with modern computer labs.',               17.4950, 78.3940, 'https://picsum.photos/seed/jntuh14/800/500', 14),
  ('Basketball Court',      'Outdoor court with hoops. Near sports complex.',          17.4928, 78.3950, 'https://picsum.photos/seed/jntuh15/800/500', 15)
ON CONFLICT DO NOTHING;
