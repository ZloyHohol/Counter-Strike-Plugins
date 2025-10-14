# SkinChooser 5.4 CS-Source

This is a modified version of SkinChooser 5.3, adapted and fixed for Counter-Strike: Source and modern SourceMod versions (1.12+).

## Changes from version 5.3

*   **SourceMod 1.12 Compatibility:** The plugin has been updated to compile and run correctly on SourceMod 1.12 and newer.
*   **Bug Fixes:**
    *   Fixed numerous compilation errors and warnings.
    *   Resolved handle leaks and invalid handle usage that caused instability and crashes.
    *   Corrected an issue that caused models to disappear, especially when using bots, by adding checks for empty model lists.
    *   Fixed a bug in the CS:GO-specific code related to random model selection.
*   **Modernization:**
    *   Updated the code to use modern SourcePawn syntax (e.g., `ConVar` instead of `Handle` for convars).

---

# SkinChooser 5.4 CS-Source

Это модифицированная версия плагина SkinChooser 5.3, адаптированная и исправленная для Counter-Strike: Source и современных версий SourceMod (1.12+).

## Отличия от версии 5.3

*   **Совместимость с SourceMod 1.12:** Плагин был обновлен для корректной компиляции и работы на SourceMod 1.12 и новее.
*   **Исправления ошибок:**
    *   Исправлены многочисленные ошибки и предупреждения при компиляции.
    *   Устранены утечки и неверное использование дескрипторов (handles), которые приводили к нестабильной работе и падениям.
    *   Исправлена проблема, из-за которой модели игроков/ботов пропадали (ошибка `mod_studio: MOVETYPE_FOLLOW with no model.`), особенно при использовании ботов, путем добавления проверок на пустые списки моделей.
    *   Исправлена ошибка в коде, специфичном для CS:GO, связанная с выбором случайной модели.
*   **Модернизация:**
    *   Код плагина был обновлен для использования современного синтаксиса SourcePawn (например, `ConVar` вместо `Handle` для консольных переменных).
