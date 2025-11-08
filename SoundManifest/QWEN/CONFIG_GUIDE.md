# Конфигурация SoundManifest плагина

## Основные настройки (CVAR)

| Имя CVAR | Значение по умолчанию | Описание |
|----------|----------------------|----------|
| `sm_soundmanifest_enabled` | 1 | Включить/выключить плагин (1 - вкл, 0 - выкл) |
| `sm_soundmanifest_join_delay` | 3.0 | Задержка перед воспроизведением приветственного звука (в секундах) |
| `sm_soundmanifest_join_audience` | 0 | Кто слышит приветственный звук (0 - только игрок, 1 - все) |
| `sm_soundmanifest_join_interval` | 10.0 | Минимальный интервал между приветственными звуками (в секундах) |
| `sm_soundmanifest_default_setting` | 1 | Включены ли звуки по умолчанию для новых игроков (1 - да, 0 - нет) |
| `sm_soundmanifest_justicekill_threshold` | 2 | Количество тимкиллов, после которого срабатывает JusticeKill |
| `sm_soundmanifest_combokill_time` | 4.0 | Время в секундах для комбо убийств |
| `sm_soundmanifest_quadkill_threshold` | 4 | Количество убийств для QuadKill |
| `sm_soundmanifest_epicstreak_threshold` | 5 | Порог для эпических серий убийств |
| `sm_soundmanifest_cooldown_interval` | 2.0 | Минимальный интервал между повторениями одного и того же звука |
| `sm_soundmanifest_debug_level` | 0 | Уровень отладки (0=ошибки, 1=предупреждения, 2=информация, 3=отладка) |
| `sm_soundmanifest_max_file_size` | 50 | Максимальный размер звукового файла (в МБ) |
| `sm_soundmanifest_max_sounds_per_event` | 5 | Максимальное количество звуков на событие (1-5) |

## Формат конфигурационного файла звуков (SoundManifest_Sounds.ini)

Конфигурационный файл в формате KeyValues с секциями для каждого типа события:

```
"SoundManifest"
{
    "FirstBlood"
    {
        "message"       "Фраза из translation файла"
        "sound_1"       "путь/к/звуковому/файлу.wav"
        "sound_2"       "путь/к/другому/звуковому/файлу.wav"
        "sound_count"   "2"
        "audience"      "all"
    }
    
    "Headshot"
    {
        "message"       "Фраза из translation файла"
        "sound_1"       "путь/к/звуковому/файлу.wav"
        "audience"      "killer,victim"
    }
    
    "JoinServer"
    {
        "Default"
        {
            "sound_1"   "путь/к/звуковому/файлу.wav"
        }
        "b" 
        {
            "flag"      "b"
            "sound_1"   "путь/к/звуковому/файлу.wav"
        }
    }
}
```

### Возможные типы событий

* `FirstBlood` - первая кровь в раунде
* `Headshot` - убийство в голову
* `DoubleKill`, `TripleKill`, `QuadKill` - серии убийств
* `MultiKill`, `SuperKill`, `UltraKill`, `MegaKill`, `MonsterKill`, `Godlike` - эпические серии убийств
* `Combo` - комбо убийства
* `KnifeKill` - убийство ножом
* `GrenadeKill` - убийство гранатой
* `Suicide` - самоубийство
* `TeamKill` - убийство по команде
* `JusticeKill` - "справедливое" убийство (убийца тимкиллера)
* `SpecialKill` - специальные убийства (для нестандартного оружия)
* `RifleKill`, `SMGKill`, `ShotgunKill`, `SniperKill`, `PistolKill`, `MachineGunKill` - убийства конкретным оружием (не объявляются по умолчанию)
* `PlayerDisconnect`, `PlayerKick`, `PlayerVACBanned` - события отключения игроков

### Возможные аудитории

* `killer` - убийца
* `victim` - жертва
* `killer_team` - команда убийцы
* `victim_team` - команда жертвы
* `all_alive` - все живые игроки
* `all` - все игроки

### Приветственные звуки

В секции `JoinServer` можно настроить разные звуки для разных групп админов:

* `Default` - звуки по умолчанию
* `b` - звуки для админов с флагом b
* Другие флаги могут быть добавлены по необходимости

Файлы звуков должны находиться в папке `sound/` вашего сервера и быть в формате .wav, .mp3 или .ogg.