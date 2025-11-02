# Counter-Strike-Plugins

This repository contains a collection of SourceMod plugins for Counter-Strike: Source.

## PlayerRewardAndDiscipline

This plugin provides a comprehensive system for rewarding players for positive actions and disciplining them for negative ones.

### Features

*   **MVP Rewards:** At the end of each round, players can vote for the Most Valuable Player (MVP). The MVP is determined by a custom logic that prioritizes objective-based wins. The MVP receives a monetary reward based on the number of votes they receive.
*   **Teamkill Punishments:** Players who teamkill are punished. The punishment can be configured to be automatic or based on a vote from the victim.
*   **Anti-Camper System:** Players who remain in the same area for too long are marked as campers and highlighted with a beacon.
*   **In-Game Rules:** Display server rules to players at the beginning of each round.
*   **Admin Menu:** A simple in-game menu for administrators to enable or disable the plugin's features.

### MVP Calculation

The MVP is determined based on the following hierarchy:

1.  **Bomb Defusal:** The player who defuses the bomb is the MVP.
2.  **Last Hostage Rescue:** The player who rescues the last hostage is the MVP.
3.  **Bomb Explosion:** If the bomb explodes, the player who planted it is the MVP.
4.  **Most Kills:** If no objective-based MVP condition is met, the player with the most kills is the MVP. In case of a tie, the player who achieved the kill count first is the MVP.
