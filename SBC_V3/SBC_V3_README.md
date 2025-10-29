# SmokeBomb Combo Plugin (Version 3.5)

This document provides an overview of the SmokeBomb Combo plugin, version 3.5.

## Русский

### Обзор
Плагин SmokeBomb Combo (версия 3.5) предназначен для управления дымовыми гранатами в Counter-Strike: Source, добавляя функциональность урона и визуальных эффектов. Эта версия включает улучшения стабильности, читаемости кода и новые возможности.

### Основные изменения и улучшения:
*   **Исправлены ошибки компиляции:** Устранены синтаксические ошибки, такие как отсутствующая точка с запятой после `enum struct` и некорректное объявление глобальной переменной `g_hLogQueue`.
*   **Улучшена читаемость кода:** "Магические числа" заменены на именованные константы (`LOG_TIMER_INTERVAL`, `RECOLOR_TIMER_INTERVAL`, `SMOKE_DAMAGE_RADIUS`, `SMOKE_LIFETIME`) для лучшего понимания и удобства поддержки.
*   **Добавлены звуковые эффекты:** При получении урона от дыма игроки теперь слышат случайный звук кашля, что повышает погружение в игровой процесс.
*   **Оптимизация таймеров:** Хотя в предыдущих версиях могли быть неэффективные таймеры, текущая реализация использует таймеры для каждой дымовой гранаты, что является более управляемым подходом.
*   **Улучшенная обработка ресурсов:** Управление `ArrayList` и `DataPack` было пересмотрено для предотвращения потенциальных утечек памяти.

## English

### Overview
The SmokeBomb Combo plugin (version 3.5) is designed to manage smoke grenades in Counter-Strike: Source, adding damage functionality and visual effects. This version includes improvements in stability, code readability, and new features.

### Key Changes and Improvements:
*   **Compilation Errors Fixed:** Syntax errors, such as a missing semicolon after `enum struct` and incorrect global variable declaration for `g_hLogQueue`, have been resolved.
*   **Improved Code Readability:** "Magic numbers" have been replaced with named constants (`LOG_TIMER_INTERVAL`, `RECOLOR_TIMER_INTERVAL`, `SMOKE_DAMAGE_RADIUS`, `SMOKE_LIFETIME`) for better understanding and easier maintenance.
*   **Added Sound Effects:** When taking damage from smoke, players now hear a random coughing sound, enhancing immersion in the gameplay.
*   **Timer Optimization:** While previous versions might have had inefficient timers, the current implementation uses timers per smoke grenade, which is a more manageable approach.
*   **Enhanced Resource Handling:** `ArrayList` and `DataPack` management has been reviewed to prevent potential memory leaks.
