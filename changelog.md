# Changelog

All recent updates to Muzo explained in simple terms:

## 🎵 Lyrics & Karaoke Visual Upgrades
- **Smooth Word-by-Word Karaoke Filling**: Words in karaoke mode now fill up with color gradually in real-time as the artist sings them, rather than jumping abruptly. We implemented a high-performance animation system to make this transition look buttery-smooth (running at 60+ frames per second).
- **Line-by-Line Synced Lyrics Sweep**: Standard synced lyrics now also have a progressive coloring effect that sweeps across the text. If multiple consecutive lines share the same time (e.g. repeated chorus blocks), they fill up sequentially one after the other instead of all at once.
- **Active Line Highlighting**: The currently sung lyric line now slides slightly to the right and lights up, making it much easier to track.
- **Clearer Text Visibility**: We made the upcoming and past lyric lines less transparent (boosting visibility to 50%). They are now much easier to read while still clearly distinguishing them from the active line.
- **No More Floating/Jittery Lyrics**: Fixed a bug where words inside the lyrics viewer would jitter or float around as they were highlighted. The text now stays perfectly still and aligned.
- **Removed Ghost Text Shadows**: Fixed a rendering issue where words left a faint visual shadow or "ghost" text on the screen when scrolling or highlighting.
- **Smooth Lyric Scrolling**: Scrolling through lyrics or tapping a lyric line to skip to it now glides smoothly instead of jumping instantly.

## 📱 User Interface & Layout Improvements
- **Complete Light Mode Styling Fix**: Fixed styling issues across all screens (Settings, Library, Search, Album, Playlist, Profile, and Dialogs/Modals) where text, cards, buttons, and borders were completely white and unnoticeable on white backgrounds in Light Mode. They now dynamically switch colors to preserve high contrast and clean aesthetics.
- **Smart Status Bar & Navigation Bar Colors**: The status bar icons and text now automatically invert their colors based on your active theme (dark icons in Light Mode and light icons in Dark Mode) so they are always readable.
- **Thin Avatar Borders**: Added a clean, thin, theme-aware border around your profile picture across all main app areas (Home screen, Library screen, sidebar drawer, and profile dropdown menus) to make it visually pop.
- **Context-Aware Options Menu**: Tapping the three dots next to any song now opens the options menu right next to the song itself instead of popping up in the center of the screen with a blurred background.
- **Sleek iOS-Inspired Upload & Edit Menus**: Rebuilt the music upload and edit forms to use modern, pill-shaped text entries (including the description box), rounded buttons, and circular status badges to match the premium iOS design system.
- **Compact Options Design**: The song options menu is now smaller, cleaner, and positioned so that it never gets hidden behind the bottom navigation bar or the active player banner.
- **Desktop & Big Screen Search Bar**: Added a wide, dedicated search box at the top of the search screen when using the app on a desktop, laptop, or tablet. Previously, desktop users couldn't search because the search input was only on the mobile navigation bar (which is hidden on big screens).
- **New Profile Dropdown Menu**: Clicking your profile picture now opens a sleek, glassmorphic dropdown list with quick navigation to your uploads, settings, about page, and clear indicators showing your login or synchronization status.
- **Community Page Redesign**: Updated the Community screen layout so it has the same standard search bar and song list layout used throughout the rest of the app.
- **Repositioned Notifications**: Shifted the floating pop-up notification bubble (which alerts you about downloads, clearing lists, etc.) further down the screen to float neatly right above the bottom navigation bar.

## 🎧 Music Player & Queue Fixes
- **Light Glassmorphic Player Tint**: The music player screen background now adapts to Light Mode with a gorgeous, semi-transparent white tint (light glassmorphism) instead of remaining pitch black.
- **Theme-Aware Player Controls & Text**: Updated all player controls, progress sliders, volume indicators, lyrics text, queue list items, and navigation buttons to dynamically change to high-contrast colors (e.g. black/dark) in Light Mode, making them completely legible, while preserving the original dark look in Dark Mode.
- **Smart Queue Clearing**: Fixed the "Clear" button in the queue. Previously, if you cleared the queue while "Infinite Mode" (auto-queue) was enabled, the app would immediately fetch new songs and refill it. Now, clearing the queue successfully empties all upcoming songs and stays empty for the duration of the current track.
- **Improved Player Controls**: The "Clear" button is now disabled when there are no upcoming songs left (only the current playing song is in the list), preventing the player from clearing the active song and stopping the music.
- **Correct Song Durations**: Fixed a bug where custom uploaded songs would get stuck showing `0:00` for their track duration.
- **Fixed Black Screen Bug**: Fixed a bug where tapping options like "Play Next" in the song menu would crash the interface and leave the app screen completely black.
