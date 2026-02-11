🎵 TheMusic - Offline Music Player
TheMusic is a beautiful, Spotify-inspired offline music player built with Flutter. It scans your device for local audio files and organizes them into a sleek, dark-themed interface. Features include playlist management, a "Liked Songs" system, and a robust audio player with background playback capabilities.

✨ Features
Local Audio Scanning: Automatically fetches songs from device storage using on_audio_query.

Spotify-like UI: Modern dark theme with green accents (#1DB954) and a clean layout.

Smart Player:

Full-screen player with album art, seek bar, and playback controls.

Mini-player: Persistent bottom bar to control music while browsing.

Flicker-Free: Optimized UI updates using Streams to prevent screen stuttering.

Playlist Management:

Create custom playlists.

Add/Remove songs via the context menu (3-dots).

Dedicated "Liked Songs" playlist (Favorites).

Search: Real-time search by song title or artist.

Smart Filtering: Automatically filters out short audio clips (under 15s) like ringtones or notifications.

🛠️ Tech Stack
Framework: Flutter (Dart)

State Management: Provider

Audio Engine: just_audio

File Fetching: on_audio_query

Permissions: permission_handler

Icons: flutter_launcher_icons

🚀 Installation & Setup
1. Clone the Repository
Bash
git clone https://github.com/your-username/the_music.git
cd the_music
2. Install Dependencies
Bash
flutter pub get
3. Android Configuration (Important)
Since this app accesses local storage, specific permissions and Gradle configurations are required.

A. Permissions Ensure your android/app/src/main/AndroidManifest.xml includes the following lines before the <application> tag:

XML
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
B. Min SDK Version In android/app/build.gradle, ensure the minSdkVersion is at least 21:

Gradle
defaultConfig {
    // ...
    minSdkVersion 21
    // ...
}
4. Build and Run
Connect your Android device or emulator and run:

Bash
flutter run
📱 Usage Guide
Grant Permissions: Upon first launch, allow the app to access photos/audio/media.

Play Music: Tap any song in the "Home" or "Search" tab to start playing.

Like a Song: Tap the heart icon on the Mini Player or Full Player to add it to your "Liked Songs".

Create Playlists:

Go to Library > Tap + (or "Create New Playlist").

To add songs: Tap the 3-dots on any song > "Add to Playlist".

Search: Use the Search tab to filter your local library.

🔧 Troubleshooting Common Build Errors
If you encounter build errors related to Kotlin/Java versions or Namespace, follow these steps:

1. Java/Kotlin Mismatch Error: If the build fails with "Inconsistent JVM-target compatibility", run:

Bash
flutter clean
flutter run
Note: The project's android/build.gradle.kts has been configured to handle the version mismatch between the App (Java 17) and Plugins (Java 1.8).

2. Stuck "Deleting build..." If flutter clean fails because a file is in use:

Stop the running app.

Run taskkill /F /IM java.exe (Windows) or pkill -f java (Mac/Linux).

Try flutter clean again.
