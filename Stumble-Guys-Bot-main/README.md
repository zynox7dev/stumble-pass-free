# Stumble Guys Bot

made by discord.gg/stumble

## Features

- Automates joining matches, basic in-game movement, leaving after a round, and claiming rewards.
- Includes a control window to start, pause, resume, and stop the bot.
- Press **F9** to pause or resume, and **F10** to stop the bot at any time.
- Set a match limit, a session time limit, or both. A value of `0` means unlimited.
- Checks the game client resolution before sending input. Supported resolutions:
  - 1280x720
  - 1280x800
  - 1440x900
  - 1600x900
  - 1920x1080
  - 2560x1440
- Adjusts visual color-detection tolerance from `-10` to `30`.
- Saves settings to `StumbleBot.ini`.
- Logs events, completed matches, session duration, and resolution issues to `StumbleBot.log`.
- Includes an optional utility that displays screen coordinates and pixel color on right-click. Press **Space** to exit the utility.
