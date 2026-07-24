# Family Schedule 🗓️

A single-file family activity & carpool scheduler. Track multiple kids across multiple
extracurriculars, assign drop-off / pick-up drivers, and catch scheduling conflicts before
they happen. Share one link with grandparents, other parents, or sitters — no accounts.

**Live:** https://rustygator5.github.io/schedule/

## Features
- Weekly grid + agenda views, color-coded per child
- Assign a drop-off and pick-up driver to each activity
- Filter to any driver to get their personal "my rides" list
- Conflict detection: child double-booked · driver double-booked · transport crunch (two cars needed at once) · unassigned rides
- Live shared sync via Supabase (capability-based share link — the `#s=` id in the URL is the secret)
- Works offline (localStorage) and falls back gracefully

## Files
- `schedule.html` — editable source
- `index.html` — copy served by GitHub Pages (keep in sync: `cp schedule.html index.html`)
- `supabase-setup.sql` — run once in the Supabase SQL Editor to enable live sync

## Local dev
```
python -m http.server 8773 --directory .
# then open http://localhost:8773/schedule.html
```
