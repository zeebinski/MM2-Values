# MM2 Traderie Values — prototype

Upload `main.lua` and `values.json` to the `main` branch of a **public** GitHub repository.

1. In `main.lua`, replace `REPLACE_USER/REPLACE_REPO` with your GitHub username and repository.
2. Populate `values.json` with **verified Traderie values**, e.g. `"Item Name": 12.5`. The file deliberately ships empty rather than claiming unverified values.
3. In an environment that supports HTTP requests and `loadstring`, run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/main.lua"))()
```

Do **not** run unknown third-party loaders. Check your executor and Roblox platform rules.

## Current limitations

- This does **not** scrape Traderie: there is no verified, permitted automated Traderie value API integrated. A separate authorized updater is required.
- This is **not** a universal MM2 icon recognizer: it labels only visible inventory/trade `ImageButton` slots with an exact item name available in GUI text, slot name, or attributes. Actual MM2 slots may expose only image asset IDs and require a maintained ID-to-name mapping.
- The displayed subtotal covers recognized visible slots only, NOT a complete inventory and NOT separate trade sides. No Win/Lose assessment is made until both sides can be distinguished reliably.
- The script only touches client GUI, on a 2-second interval. The `×` button removes overlay tags and stops scanning.
- The UI hierarchy is unverified in live MM2. This is a starter for adapting to actual UI.
