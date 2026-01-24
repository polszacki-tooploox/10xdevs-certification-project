### Main problem
Home coffee brewing is inconsistent because users struggle to translate a recipe into correct grind size, dose, water temperature, timing, and technique for a given brewer and coffee.

### Smallest functional set (MVP)
- Brew mode selection: **V60**, **AeroPress**, **Espresso**
- Recipe library with a small set of **starter recipes per method** (editable defaults)
- Step-by-step guided brewing flow:
  - Inputs: coffee amount, target yield, grind setting (coarse scale), water temperature
  - Timer-based instructions (e.g., bloom + pours for V60; steep + plunge for AeroPress; shot timer for espresso)
  - Simple progress UI with start/pause/resume and “next step”
- Basic scaling:
  - Adjust recipe quantities automatically when user changes dose or yield (within method constraints)
- Brew log (very lightweight):
  - Save brew summary: method, recipe used, key parameters, timestamp, optional rating (1–5) and short note

### Out of MVP scope
- Grinder-specific calibration, advanced grind guidance, or machine-specific espresso profiles
- AI-based personalization or automatic recipe recommendations
- Advanced espresso features (pressure profiling, flow curves, shot diagnostics, puck prep coaching)
- Inventory management (beans, roast dates), shopping lists, or subscription features
- Social/sharing, community recipes, cloud sync across devices, or multi-user accounts
- Integrations with smart scales, Bluetooth thermometers, or espresso machine connectivity

### Success criteria
- At least **60%** of users who start a brew flow complete it to the end (per method)
- At least **40%** of completed brews are saved to the log with a rating or note
- Users report improved consistency: **≥3.5/5 average rating** across logged brews after the first week of usage

