# SolarPower

Raid and party **Devotion** manager for **Sun Clerics** on Project Ascension **Conqueror of Azeroth** (CoA).

SolarPower is a PallyPower-style addon for WoW 3.3.5a: assign Devotion of Dawn, Devotion of Grace, and Devotion of Radiance per CoA class, see missing-buff indicators, auto-buff with hotkeys, and sync assignments between Sun Clerics in your group.

## Requirements

- World of Warcraft **3.3.5a** client (Project Ascension)
- **Conqueror of Azeroth** realm
- **Sun Cleric** character with Devotion spells (Blessings specialization)

## Installation

Install from [GitHub Releases](https://github.com/chadrien/SolarPower/releases), not from a git checkout of `main` (the `.toc` on `main` uses `x.x.x`; release tags set the real version in the zip).

1. Download the latest **`SolarPower.zip`** from [GitHub Releases](https://github.com/chadrien/SolarPower/releases).
2. Extract the `SolarPower` folder into `World of Warcraft/Interface/AddOns/`.
3. Restart WoW or `/reload`.

Saved variables use the `SolarPower*` prefix (not `PallyPower*`).

## Usage

| Command | Description |
|---------|-------------|
| `/solarpower` or `/sp` | Open options |
| `/sp test` or `/sp testmode` | Toggle test mode (spawn test players to try hover/UI without a group) |
| `/sp dumpclass` | Print `TOKEN=index` for your target (`/sp dumpclass party1`, etc.) |

**Buff bar:** class grid shows CoA classes present in your group. Colors indicate missing devotions. Click a class to buff; use player popout buttons for individuals.

**Auto-buff:** default keys `,` and `Ctrl+,` (configurable in options).

**Raid sync:** raid leader/assistant assigns which Sun Cleric covers which classes in the config window. Other Sun Clerics need SolarPower installed. Enable **Free assignment** to let non-leaders change your assignments.

## CoA class tokens

Class rows use provisional tokens from the CoA wiki (indices 23–43). If a class row misbehaves, run `/sp dumpclass` on that player and open an issue with the token.

## Devotion spell IDs

Configured in `SolarPower/SpellConfig.lua`. Current setup includes Dawn, Grace, and Radiance.

## Credits

- **SolarPower** by [chadrien](https://github.com/chadrien/SolarPower)
- Based on [PallyPower](https://github.com/AznamirWoW/PallyPower) by Aznamir, Dyaxler, Es, gallantron
- Forked from [PallyPower-Improved-3.3.5](https://github.com/NoM0Re/PallyPower-Improved-3.3.5)

Independent CoA port — not affiliated with the original PallyPower authors.

## License

Inherits the license of the upstream PallyPower-Improved fork.
