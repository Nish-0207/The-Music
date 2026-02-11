🎵 TheMusic - Offline Music Player

TheMusic is a beautiful, Spotify-inspired offline music player built with Flutter. It scans your device's local storage for audio files and organizes them into a sleek, dark-themed interface.

It features robust playlist management, a "Liked Songs" system, search functionality, and a seamless audio experience powered by just_audio.

✨ Features

Local Audio Scanning: Automatically fetches songs from device storage using on_audio_query.

Spotify-like UI: Modern dark theme with green accents (#1DB954) and a clean layout.

Smart Player: * Full-screen player with album art, seek bar, and playback controls.

Mini-player: Persistent bottom bar to control music while browsing.

Flicker-Free: Optimized UI updates using Streams to prevent screen stuttering.

Playlist Management:

Create custom playlists.

Add/Remove songs via the context menu (3-dots).

Dedicated "Liked Songs" playlist (Favorites) that cannot be deleted.

Search: Real-time search by song title or artist.

Smart Filtering: Automatically filters out short audio clips (under 15s) like ringtones or notifications.

🛠️ Tech Stack

Framework: Flutter (Dart)

State Management: Provider

Audio Engine: just_audio

File Fetching: on_audio_query

Permissions: permission_handler

🚀 Installation & Setup

1. Clone the Repository

git clone [https://github.com/your-username/the_music.git](https://github.com/your-username/the_music.git)
cd the_music


2. Install Dependencies

flutter pub get


3. Generate App Icons (Optional)

If you want to update the app icon using the included configuration:

dart run flutter_launcher_icons


4. Android Configuration (Crucial)

This app requires specific permissions to read local files.

AndroidManifest.xml
Ensure android/app/src/main/AndroidManifest.xml has these permissions before <application>:

<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>


build.gradle Fixes
The project includes a custom android/build.gradle script to handle compatibility between modern Android build tools (Java 17) and older plugins (Java 1.8). Do not remove the logic at the bottom of android/build.gradle.kts, as it fixes:

Namespace Errors: Automatically assigns namespaces to plugins that lack them.

JVM Target Mismatch: Forces the App to use Java 17 and Plugins to use Java 1.8.

5. Run the App

Connect your Android device or emulator and run:

flutter run


📖 Usage Guide

Grant Permissions: Upon first launch, allow the app to access audio files.

Play Music: Tap any song in the "Home" or "Search" tab to start playing.

Like a Song: Tap the heart icon on the Mini Player or Full Player to add it to your "Liked Songs".

Create Playlists: * Go to Library > Tap + (or the Add icon).

To add songs: Tap the 3-dots on any song > "Add to Playlist".

To remove songs: Go to the playlist > Tap 3-dots on the song > "Remove from this Playlist".

🔧 Troubleshooting

Issue: "Inconsistent JVM-target compatibility"

Solution: Run flutter clean and then flutter run. The custom build script in android/build.gradle.kts handles this automatically.

Issue: flutter clean hangs or fails to delete build folder

Cause: A Java process (Gradle daemon) is holding onto the files.

Solution: 1.  Open your terminal.
2.  Run taskkill /F /IM java.exe (Windows) or pkill -f java (Mac/Linux).
3.  Run flutter clean again.

📄 License

This project is open-source and available under the MIT License.
