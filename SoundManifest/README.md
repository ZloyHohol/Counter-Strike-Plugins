# SoundManifest Plugin

## English

### Overview

**SM_SoundManifest** is a modern, unified plugin for managing all sound events on the server. It replaces both `Quake Sounds` and `Welcome Sound` plugins, combining their functionality into a single, flexible, and stable system.

The plugin allows you to play sounds for various game events (kills, streaks, headshots, player joins) and gives both the administrator the flexibility to configure these sounds and the players the ability to disable them for themselves.

### Configuration

The main configuration is done in `addons/sourcemod/configs/SoundManifest_Sounds.ini`. This is where you set up all the sounds and events.

**Example structure:**

```ini
"SoundManifest"
{
    "JoinServer"
    {
        "Default"
        {
            "sound_1"       "music/welcome/welcome1.mp3"
            "sound_2"       "music/welcome/welcome2.mp3"
        }
        "Admins"
        {
            "flag"          "b"
            "sound_1"       "music/admin_welcome.mp3"
        }
    }
    "FirstBlood"
    {
        "sound"     "quakesounds/firstblood.wav"
        "message"   "{green}First blood spilled by {red}{1}{default}!"
    }
    // ... and so on for other events
}
```

### CVars (Console Variables)

*   `sm_soundmanifest_enabled` (1/0, default: 1) - Enable/disable the plugin.
*   `sm_soundmanifest_join_delay` (0.0-30.0, default: 3.0) - Delay in seconds before playing the welcome sound.
*   `sm_soundmanifest_join_audience` (0/1, default: 0) - Who hears the welcome sound: `0` = joiner only, `1` = everyone on the server.
*   `sm_soundmanifest_join_interval` (0.0-300.0, default: 10.0) - Minimum interval in seconds between playing welcome sounds (spam protection).
*   `sm_soundmanifest_default_setting` (1/0, default: 1) - Should sounds be enabled by default for new players?
*   `sm_soundmanifest_justicekill_threshold` (2-10, default: 2) - Number of teamkills a victim must have to trigger JusticeKill.
*   `sm_soundmanifest_combokill_time` (0.0-10.0, default: 4.0) - Time in seconds to chain kills for a combo.
*   `sm_soundmanifest_quadkill_threshold` (0-10, default: 4) - Number of kills for a QuadKill.
*   `sm_soundmanifest_epicstreak_threshold` (0-10, default: 5) - Number of kills for an Epic Streak (MultiKill, etc.).
*   `sm_soundmanifest_cooldown_interval` (0.0-10.0, default: 2.0) - Minimum interval in seconds between repetitions of the same sound.

### Known Issues

*   **Killstreak Bug**: The plugin currently only announces killstreaks (e.g., "MultiKill") in the first round. This functionality stops working in subsequent rounds.

### Commands

*   `sm_soundmanifest` (in console)
*   `!soundmanifest` / `/soundmanifest` (in chat)

Opens a personal settings menu for the player, where they can enable or disable all sounds for themselves. The choice is saved in a cookie.

---

## Русский

### Обзор

**SM_SoundManifest** — это единый, современный плагин для управления всеми звуковыми событиями на сервере. Он заменяет собой и `Quake Sounds`, и `Welcome Sound`, объединяя их функционал в одной гибкой и стабильной системе.

Плагин позволяет проигрывать звуки на различные игровые события (убийства, серии, хедшоты, вход игрока) и дает возможность как администратору гибко настраивать эти звуки, так и игрокам отключать их для себя.

### Конфигурация

Основная настройка производится в файле `addons/sourcemod/configs/SoundManifest_Sounds.ini`. Здесь настраиваются все звуки и события.

**Пример структуры:**

```ini
"SoundManifest"
{
    "JoinServer"
    {
        "Default"
        {
            "sound_1"       "music/welcome/welcome1.mp3"
            "sound_2"       "music/welcome/welcome2.mp3"
        }
        "Admins"
        {
            "flag"          "b"
            "sound_1"       "music/admin_welcome.mp3"
        }
    }
    "FirstBlood"
    {
        "sound"     "quakesounds/firstblood.wav"
        "message"   "{green}Первая кровь пролита игроком {red}{1}{default}!"
    }
    // ... и так далее для других событий
}
```

### CVars (консольные переменные)

*   `sm_soundmanifest_enabled` (1/0, по умолчанию: 1) — Включить/выключить плагин.
*   `sm_soundmanifest_join_delay` (0.0-30.0, по умолчанию: 3.0) — Задержка в секундах перед проигрыванием звука приветствия.
*   `sm_soundmanifest_join_audience` (0/1, по умолчанию: 0) — Кто слышит звук приветствия: `0` = только вошедший игрок, `1` = все на сервере.
*   `sm_soundmanifest_join_interval` (0.0-300.0, по умолчанию: 10.0) — Минимальный интервал в секундах между проигрыванием звуков приветствия (защита от спама).
*   `sm_soundmanifest_default_setting` (1/0, по умолчанию: 1) — Включены ли звуки по умолчанию для новых игроков?
*   `sm_soundmanifest_justicekill_threshold` (2-10, по умолчанию: 2) - Количество убийств товарищей по команде, которое должна совершить жертва, чтобы сработало событие JusticeKill.
*   `sm_soundmanifest_combokill_time` (0.0-10.0, по умолчанию: 4.0) - Время в секундах для объединения убийств в комбо.
*   `sm_soundmanifest_quadkill_threshold` (0-10, по умолчанию: 4) - Количество убийств для QuadKill.
*   `sm_soundmanifest_epicstreak_threshold` (0-10, по умолчанию: 5) - Количество убийств для эпической серии (MultiKill и т.д.).
*   `sm_soundmanifest_cooldown_interval` (0.0-10.0, по умолчанию: 2.0) - Минимальный интервал в секундах между повторениями одного и того же звука.

### Известные проблемы

*   **Баг с сериями убийств**: В настоящее время плагин объявляет о сериях убийств (например, "MultiKill") только в первом раунде. В последующих раундах эта функция перестает работать.

### Команды

*   `sm_soundmanifest` (в консоль)
*   `!soundmanifest` / `/soundmanifest` (в чат)

Открывает меню персональных настроек для игрока, где он может включить или выключить проигрывание всех звуков для себя. Выбор сохраняется в cookie.
