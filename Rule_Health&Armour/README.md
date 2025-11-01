# Ruler Health & Armour (RHA)

This plugin allows server administrators to configure custom health and armor values for players based on their admin flags. It also includes configurable immortality features and settings for bots.

## Installation

1.  Copy `ruler_health_armour.smx` to your server's `addons/sourcemod/plugins/` directory.
2.  The configuration file will be automatically generated at `addons/sourcemod/configs/RHA.cfg` on the first run.

## Commands

The plugin's functions are managed through the admin menu.

*   **`sm_admin`** -> **`Player Commands`** -> **`RHA Settings`**
    *   This opens the main menu for the RHA plugin. Access is granted to admins who are part of a group with `"CanUseImmortality" "1"` in the configuration.
    *   **Plugin Status: [Enabled/Disabled]**: A master switch to turn the entire plugin on or off. When disabled, all players will have default health/armor.
    *   **Set Immortality Mode**: Opens a submenu to set the global immortality mode for all eligible admins.
        *   `0`: Disabled
        *   `1`: Invincible (takes no damage)
    *   **Reset Player HP/Armor**: Opens a menu to select any player on the server and reset their Health and Armor to 100.

## CVars (Console Variables)

*   **`sm_rha_enabled`** (Default: 1)
    *   The master switch for the plugin. `1` = On, `0` = Off.

*   **`sm_rha_admin_immortality_mode`** (Default: 0)
    *   Sets the global immortality mode for eligible admins (0: Disabled, 1: Invincible). Can be changed via the admin menu.

*   **`sm_rha_enable_logging`** (Default: 0)
    *   Enable/Disable logging for RHA plugin actions. `0` = Off, `1` = On. Logs are saved to `addons/sourcemod/logs/rha-YYYY-MM-DD.log`.

*   **`sm_rha_version`**
    *   The current version of the plugin (read-only).

## Configuration (`addons/sourcemod/configs/RHA.cfg`)

The plugin is configured using a `KeyValues` file. You can define different groups and a special section for bots.

### Example Structure

```
// Note: This is the root of the file. There is no single parent section.

"Human-gamers"
{
    "Guest"
    {
        "Flags"         ""
        "Team_T"
        {
            "health"        "100"
            "armor"         "0"
        }
        "Team_CT"
        {
            "health"        "100"
            "armor"         "0"
        }
    }

    "Admin_z"
    {
        "Flags"                 "z"
        "CanUseImmortality"     "1"
        "Team_T"
        {
            "health"        "120"
            "armor"         "100"
        }
        "Team_CT"
        {
            "health"        "120"
            "armor"         "100"
        }
    }
    // ... other groups for humans
}

"bots"
{
    "Team_T"
    {
        "health"        "90"
        "armor"         "50"
    }
    "Team_CT"
    {
        "health"        "90"
        "armor"         "50"
    }
}
```

### Key Explanations

*   **`Bots`**: A special section that applies only to bots (fake clients). It does not have `Flags` or `CanUseImmortality`.
*   **Group Name** (e.g., "Guest", "Admin_z"): A custom name for your group.
*   **`Flags`**: The set of admin flags a player must have to be in this group. An empty string `""` is for the default group (guests). The plugin will assign players to the group with the most matching flags.
*   **`CanUseImmortality`**: If set to `"1"`, players in this group can access the `RHA Settings` menu and will be affected by the global immortality mode.
*   **`Team_T` / `Team_CT`**: Sub-sections for Terrorist and Counter-Terrorist teams.
*   **`Health` / `Armor`**: The health and armor values to apply to players in that group and on that team.

## Compilation

This plugin was last compiled with SourcePawn Compiler 1.11 or newer. The following dependencies are required:

*   `sourcemod.inc`
*   `sdktools.inc`
*   `sdkhooks.inc`
*   `cstrike.inc`
*   `keyvalues.inc`
*   `multicolors.inc`
*   `adminmenu.inc`
*   `topmenus.inc` (included by `adminmenu.inc`)

All required include files are provided in the `scripting` directory alongside the source code.

The original code was written using an older SourceMod API. The main compilation errors were due to:

1.  **Outdated `KeyValues` API**: The script was updated to use the modern `KeyValues` methodmap API (e.g., `JumpToKey` instead of `FindKey`, `new KeyValues()` instead of `CreateNewKey`).
2.  **Incorrect `TopMenu` Usage**: The method for adding an item to the admin menu was updated to use a `TopMenuHandler` as required by the `topmenus` API.
3.  **Incorrect `SDKHook` Signature**: The function signature for the `OnTakeDamage` hook was updated to match the modern `sdkhooks` API.

//новая вставка
:

🔑 KeyValues API В старых версиях использовались KvGet*, KvSet*, KvJumpToKey и т.п. В 1.13 всё переведено на methodmap KeyValues (new KeyValues("Groups"), JumpToKey, GetNum, SetNum, Clone, ImportFromFile, ExportToFile). Именно из‑за этого у тебя изначально сыпались ошибки «cannot find method or property». README отмечает, что код был переписан под новый API.

📋 TopMenu / AdminMenu Раньше можно было просто hMenu.AddItem("sm_rha", "RHA Settings", ADMFLAG_GENERIC). В актуальном API требуется полноценный TopMenuHandler (функция‑обработчик с TopMenuAction_DisplayOption и TopMenuAction_SelectOption). Поэтому в твоём последнем варианте появился AdminMenu_RHA_SelectItem — это и есть правильный способ.

⚔️ SDKHook_OnTakeDamage Сигнатуры в sdkhooks менялись. Старый вариант принимал 5 параметров, новый — 8 (victim, attacker, inflictor, damage, damagetype, weapon, damageForce[3], damagePosition[3]).
1. OnRoundStart
sourcepawn
public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // ApplyHealthArmorToClient is already called in OnPlayerSpawn, so no need to call it here.
    // This prevents duplicate messages at the start of a round.
}
Сейчас функция пустая.

Но: в CS:S/CS:GO иногда игроки появляются без события player_spawn (например, при рестарте раунда).

Рекомендация: всё же пройтись по всем клиентам и вызвать ApplyHealthArmorToClient(i) для надёжности, но без сообщений (чтобы не дублировались). Можно добавить флаг silent.
//на самом деле хорошо работает событие OnPlayerSpawn - отпадает нужда в "дублировани" назначении ефекта от OnRoundStart, не важно игрок по средине боя подключился на сервер, или вместе со всеми появился в новом раунде, это должно работать

2. Reset Menu
sourcepawn
SetEntProp(target, Prop_Send, "m_ArmorValue", 100);
SetEntProp(target, Prop_Send, "m_iAccount", GetEntProp(target, Prop_Send, "m_iAccount"));
Вторая строка бессмысленна: ты читаешь m_iAccount и тут же записываешь то же самое.

Это лишний вызов и потенциальный источник ошибок.

Рекомендация: удалить.

3. Immortality Hook
sourcepawn
public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
Ты обрабатываешь только режимы 1 (Invincible) и 2 (Godmode).

Режим 3 (Noclip) у тебя выставляется через UpdateClientImmortalityMode, но урон при этом не блокируется.

В итоге игрок в noclip получает урон.

Рекомендация: добавить else if (immortalityMode == 3) { damage = 0.0; return Plugin_Handled; }.
лучше вообще обойтись только Boolean 0/1 режимом, функцию с плагина In Development\SourceMod\Legacy\Rule_Health&Armour\VIP_GOD.sp подсмотреть

4. KeyValues Clone
sourcepawn
kvBestGroup = new KeyValues(sGroupName);
KvCopySubkeys(g_kvConfig, kvBestGroup);
Это рабочий способ, но он копирует все поддеревья.

Более чисто: использовать Clone() на найденном сабкейе.

Но раз уж ты используешь KvCopySubkeys, то хотя бы убедись, что всегда делаешь delete kvBestGroup после использования (у тебя это есть, но стоит проверить все ветки).

5. CS_OnBuyCommand
sourcepawn
public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if (StrEqual(weapon, "vest") || StrEqual(weapon, "vesthelm"))
    {
        CreateTimer(0.1, Timer_ReapplySettings, GetClientUserId(client));
    }
    return Plugin_Continue;
}
Хорошая идея — пересчитать броню после покупки.

Но: игрок может купить броню и каску по разным командам (vest, vesthelm).

Рекомендация: добавить проверку на kevlar и assaultsuit (в CS:S/CS:GO это тоже варианты).
логика CS:Source  такая что- ЕСЛИ очки бронежилета (без каски) <=100 можно докупить каску за 350, но от плагина In Development\SourceMod\Legacy\Rule_Health&Armour\spawn_health_armor.sp игра немного "ломается" и когда просто броня >100 - каска не докупается. Делать упор на том, что от этого плагина игрокам не нужно будет докупать бронежилеты и каски, ведь плагин должен им создавать в начале их появления (OnPlayerSpawn) предписанную ИМ по группе ОЖ и ОБ (ОчкиЖизни и Очки Брони)

6. Мелочи
В ApplyHealthArmorToClient ты делаешь delete kvGroup даже для ботов. Но для ботов ты создаёшь new KeyValues("Bots") и копируешь сабкейи — это корректно. Просто убедись, что нигде не остаётся утечек.

В Timer_DisplayMessage ты создаёшь новый KeyValues через GetClientGroupSettings и удаляешь — это правильно.
7. файл конфигурации
должен иметь структуру с 2мя! верхними записями Ю для людей и для ботов:
вот с таким файлом конфигурации игра должна работать! 1 в 1 !!! и при его отсутствии генерировать его аналог как по-умолчанию (просто секция для БОТов и для Игроков, но пустые, админы сами смогут дописать группы  в их под-уровни).
## Development Notes

A simplified plugin, `VIP_GOD.sp`, located in the `In Development/SourceMod/Legacy` directory, was used as a conceptual reference during development. It demonstrated a basic implementation of applying a status effect (invincibility) to a player based on certain conditions (VIP status). This served as an analogy for how this plugin applies custom health and armor values based on a player's admin flags.

**Armor Assignment Requirements:**
As a core requirement, the plugin must ensure that the correct armor value for a player's group is applied at the following times:
1.  When a player connects to the server (`OnPlayerSpawn`).
2.  At the start of every new round (`OnRoundStart`).

### Spawn Logic and Notifications

*   **Notification on Every Spawn**: To ensure the player is always aware of their status, the notification informing them of their group, health, and armor now appears on **every spawn**.
*   **Event Logic**:
    *   `OnPlayerSpawn`: This is the primary event for applying health/armor and displaying the notification.
    *   `OnRoundStart`: This event handler is intentionally left empty. Since `OnPlayerSpawn` reliably handles all players at the start of a round, any logic here would be redundant.
*   **Color Scheme**: The notification message uses a violet-blue base color (`{blueviolet}`) to be more distinct in the chat. The health and armor values retain their unique colors (`{darkgreen}` and `{brown}`) for readability.