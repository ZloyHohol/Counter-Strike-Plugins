# SmokeBomb Combo v2

This plugin enhances smoke grenades, allowing them to deal damage and have custom colors. This version (v2) introduces renamed cvars and a new sound feature.

## Features

- **Poison Smoke:** Smoke grenades can deal damage to players inside the smoke cloud.
- **Custom Colors:** Smoke color can be customized based on the team or individual player.
- **Damage Sound:** Plays a coughing sound from players who are taking damage from the smoke, making it audible to nearby players.

## Installation

1. Copy the contents of the `addons` and `cfg` directories to your server's `cstrike` directory.
2. Make sure the sound files (`cough-1.wav` to `cough-4.wav`) are in the `sound/player` directory.

## CVars

- `sm_sbc_enabled` (1/0): Enable or disable the entire plugin.
- `sm_sbc_damage_enabled` (1/0): Enable or disable smoke damage.
- `sm_sbc_damage_amount` (10): Damage dealt per tick.
- `sm_sbc_damage_interval` (1.0): Time in seconds between damage ticks.
- `sm_sbc_teammate_damage` (0/1): Allow smoke to damage teammates.
- `sm_sbc_color_mode` (0/1): Smoke color mode. 0 = Team Colors, 1 = Player-specific colors.
- `sm_sbc_color_t` ("255 0 0"): Smoke color for Terrorists (RGB).
- `sm_sbc_color_ct` ("0 0 255"): Smoke color for Counter-Terrorists (RGB).

## Admin Commands

- `sm_smokecolor <#userid|name> <r> <g> <b> | <disable>`: Sets a custom smoke color for a player.

## Known Issues

- **Damage Interval:** The `sm_sbc_damage_interval` cvar does not work correctly for values below `1.0`.
- **Player-specific Colors:** The `sm_smokecolor` command for setting player-specific colors is not functional in this version.

---

# SmokeBomb Combo v2

Этот плагин улучшает дымовые гранаты, позволяя им наносить урон и иметь настраиваемые цвета. Эта версия (v2) представляет переименованные переменные и новую функцию звука.

## Возможности

- **Ядовитый дым:** Дымовые гранаты могут наносить урон игрокам, находящимся в облаке дыма.
- **Пользовательские цвета:** Цвет дыма можно настроить в зависимости от команды или отдельного игрока.
- **Звук урона:** Воспроизводит звук кашля у игроков, получающих урон от дыма, делая его слышимым для ближайших игроков.

## Установка

1. Скопируйте содержимое каталогов `addons` и `cfg` в каталог `cstrike` вашего сервера.
2. Убедитесь, что звуковые файлы (`cough-1.wav` - `cough-4.wav`) находятся в каталоге `sound/player`.

## CVars

- `sm_sbc_enabled` (1/0): Включить или отключить весь плагин.
- `sm_sbc_damage_enabled` (1/0): Включить или отключить урон от дыма.
- `sm_sbc_damage_amount` (10): Урон, наносимый за один тик.
- `sm_sbc_damage_interval` (1.0): Время в секундах между тиками урона.
- `sm_sbc_teammate_damage` (0/1): Разрешить дыму наносить урон товарищам по команде.
- `sm_sbc_color_mode` (0/1): Режим цвета дыма. 0 = цвета команды, 1 = цвета для конкретного игрока.
- `sm_sbc_color_t` ("255 0 0"): Цвет дыма для террористов (RGB).
- `sm_sbc_color_ct` ("0 0 255"): Цвет дыма для контртеррористов (RGB).

## Команды администратора

- `sm_smokecolor <#userid|name> <r> <g> <b> | <disable>`: Устанавливает пользовательский цвет дыма для игрока.

## Известные проблемы

- **Интервал урона:** Консольная переменная `sm_sbc_damage_interval` не работает корректно при значениях ниже `1.0`.
- **Индивидуальные цвета:** Команда `sm_smokecolor` для установки индивидуального цвета дыма для игрока не функционирует в этой версии.