# AmmoControl_v2 SourceMod Plugin

## English Description

This SourceMod plugin, `AmmoControl_v2`, provides enhanced ammunition management and custom reload mechanics for Counter-Strike: Source.

**Key Features:**

*   **Global Ammunition Limits:** Configurable CVARs (`sm_ammo_*_max`) to set maximum ammunition counts for various weapon types (e.g., AWP, P228, UMP45, Desert Eagle, M249, M4A1, AK47, Glock, USP, M3, XM1014, grenades).
*   **Magazine-Style Shotgun Reload:** Implements a custom magazine-style reload for `weapon_m3` and `weapon_xm1014` shotguns, replacing the default shell-by-shell reload.
*   **Configurable Shotgun Reload:**
    *   Enable/disable the custom reload for each shotgun (`sm_weapon_m3_magazine_reload`, `sm_weapon_xm1014_magazine_reload`).
    *   Set custom clip sizes (`sm_weapon_m3_clip`, `sm_weapon_xm1014_clip`).
    *   Adjust reload times (`sm_weapon_m3_reload_time`, `sm_weapon_xm1014_reload_time`).

**Known Issues / Bugs:**

*   **Shotgun Reload Discrepancy:** If the `clip_size` defined in the game's weapon configuration files (e.g., `weapon_m3.txt`, `weapon_xm1014.txt`) differs from the `sm_weapon_{m3/xm1014}_clip` setting in this plugin, the shotgun may continue to reload until its entire reserve ammunition is depleted, even if the magazine is full according to the plugin's settings. It is recommended to ensure consistency between game configuration and plugin CVARs.

---

## Русское описание

Этот плагин SourceMod, `AmmoControl_v2`, предоставляет расширенное управление боеприпасами и пользовательскую механику перезарядки для Counter-Strike: Source.

**Основные возможности:**

*   **Глобальные лимиты боеприпасов:** Настраиваемые CVAR'ы (`sm_ammo_*_max`) для установки максимального количества боеприпасов для различных типов оружия (например, AWP, P228, UMP45, Desert Eagle, M249, M4A1, AK47, Glock, USP, M3, XM1014, гранаты).
*   **Перезарядка дробовика в стиле магазина:** Реализует пользовательскую перезарядку в стиле магазина для дробовиков `weapon_m3` и `weapon_xm1014`, заменяя стандартную перезарядку по одному патрону.
*   **Настраиваемая перезарядка дробовика:**
    *   Включение/отключение пользовательской перезарядки для каждого дробовика (`sm_weapon_m3_magazine_reload`, `sm_weapon_xm1014_magazine_reload`).
    *   Установка пользовательских размеров магазина (`sm_weapon_m3_clip`, `sm_weapon_xm1014_clip`).
    *   Настройка времени перезарядки (`sm_weapon_m3_reload_time`, `sm_weapon_xm1014_reload_time`).

**Известные проблемы / Баги:**

*   **Несоответствие перезарядки дробовика:** Если `clip_size`, определенный в файлах конфигурации оружия игры (например, `weapon_m3.txt`, `weapon_xm1014.txt`), отличается от настройки `sm_weapon_{m3/xm1014}_clip` в этом плагине, дробовик может продолжать перезаряжаться до тех пор, пока весь запасной боекомплект не опустеет, даже если магазин полон в соответствии с настройками плагина. Рекомендуется обеспечить согласованность между конфигурацией игры и CVAR'ами плагина.