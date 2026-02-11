import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

// -----------------------------------------------------------------------------
// DATA MODELS
// -----------------------------------------------------------------------------

class Song {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final int? localId;
  final int? albumId;
  bool isLiked;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.localId,
    this.albumId,
    this.isLiked = false,
  });

  bool get isLocal => localId != null;
}

class Playlist {
  final String id;
  final String name;
  final List<Song> songs;
  final bool isDefault; // To protect "Liked Songs"

  Playlist({
    required this.id,
    required this.name,
    required this.songs,
    this.isDefault = false,
  });
}

// -----------------------------------------------------------------------------
// STATE MANAGEMENT (PROVIDER)
// -----------------------------------------------------------------------------

class MusicProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  
  Playlist get likedSongsPlaylist => _playlists.firstWhere((p) => p.id == 'liked_songs');

  Song? _currentSong;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasPermission = false;

  List<Song> get songs => _songs;
  List<Playlist> get playlists => _playlists;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  AudioPlayer get audioPlayer => _audioPlayer; 

  MusicProvider() {
    _initPlaylists();
    _initAudioPlayer();
    fetchLocalSongs();
  }

  void _initPlaylists() {
    _playlists.add(Playlist(
      id: 'liked_songs', 
      name: 'Liked Songs', 
      songs: [], 
      isDefault: true
    ));
  }

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      bool playing = state.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
      if (state.processingState == ProcessingState.completed) {
         playNext();
      }
    });
  }

  Future<void> fetchLocalSongs() async {
    _isLoading = true;
    notifyListeners();

    PermissionStatus status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }
    
    _hasPermission = status.isGranted;

    if (_hasPermission) {
      List<SongModel> localSongs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      _songs = localSongs
          .where((s) => (s.duration ?? 0) > 15000) 
          .map((model) {
        return Song(
          id: model.id.toString(),
          title: model.title,
          artist: model.artist ?? 'Unknown Artist',
          audioUrl: model.data,
          localId: model.id,
          albumId: model.albumId,
        );
      }).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    if (_currentSong?.id == song.id) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } else {
      try {
        _currentSong = song;
        if (song.isLocal) {
           await _audioPlayer.setFilePath(song.audioUrl);
        } else {
           await _audioPlayer.setUrl(song.audioUrl);
        }
        await _audioPlayer.play();
      } catch (e) {
        print("Error playing: $e");
      }
    }
    notifyListeners();
  }
  
  void playNext() {
    if (_currentSong == null) return;
    int currentIndex = _songs.indexOf(_currentSong!);
    if (currentIndex < _songs.length - 1) {
      playSong(_songs[currentIndex + 1]);
    }
  }

  void playPrevious() {
    if (_currentSong == null) return;
    int currentIndex = _songs.indexOf(_currentSong!);
    if (currentIndex > 0) {
      playSong(_songs[currentIndex - 1]);
    }
  }

  Future<void> togglePlay() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void toggleLike(Song song) {
    song.isLiked = !song.isLiked;
    if (song.isLiked) {
      if (!likedSongsPlaylist.songs.contains(song)) {
        likedSongsPlaylist.songs.add(song);
      }
    } else {
      likedSongsPlaylist.songs.removeWhere((s) => s.id == song.id);
    }
    notifyListeners();
  }

  void createPlaylist(String name) {
    _playlists.add(Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name, 
      songs: []
    ));
    notifyListeners();
  }
  
  void deletePlaylist(Playlist playlist) {
    if (playlist.isDefault) return;
    _playlists.remove(playlist);
    notifyListeners();
  }

  void addSongToPlaylist(Song song, Playlist playlist) {
    if (!playlist.songs.contains(song)) {
      playlist.songs.add(song);
      notifyListeners();
    }
  }

  void removeSongFromPlaylist(Song song, Playlist playlist) {
    playlist.songs.removeWhere((s) => s.id == song.id);
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// MAIN APP WIDGET
// -----------------------------------------------------------------------------

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
      ],
      child: const TheMusicApp(),
    ),
  );
}

class TheMusicApp extends StatelessWidget {
  const TheMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TheMusic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF1DB954),
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          secondary: Colors.white,
          surface: Color(0xFF121212),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (provider.currentSong != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 10,
              child: MiniPlayer(song: provider.currentSong!),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI: HOME SCREEN
// -----------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2a2a2a), Color(0xFF121212)],
          stops: [0.0, 0.3],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Welcome', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Icon(Icons.notifications_outlined),
                ],
              ),
              const SizedBox(height: 20),
              Text('Your Songs', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: provider.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : provider.songs.isEmpty 
                      ? const Center(child: Text("No songs found"))
                      : ListView.builder(
                          itemCount: provider.songs.length,
                          itemBuilder: (context, index) => SongTile(song: provider.songs[index]),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI: SEARCH SCREEN
// -----------------------------------------------------------------------------

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);
    
    final filteredSongs = provider.songs.where((song) {
      final titleLower = song.title.toLowerCase();
      final artistLower = song.artist.toLowerCase();
      final queryLower = _query.toLowerCase();
      return titleLower.contains(queryLower) || artistLower.contains(queryLower);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => _query = val),
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'What do you want to listen to?',
                hintStyle: TextStyle(color: Colors.grey[800]),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredSongs.isEmpty 
                  ? Center(child: Text(_query.isEmpty ? "Search for a song" : "No results found"))
                  : ListView.builder(
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) => SongTile(song: filteredSongs[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI: LIBRARY SCREEN
// -----------------------------------------------------------------------------

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text('T', style: TextStyle(color: Colors.black)),
                ),
                const SizedBox(width: 12),
                Text('Your Library', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showCreatePlaylistDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: provider.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = provider.playlists[index];
                  return ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: playlist.isDefault ? const Color(0xFF450af5) : Colors.grey[800],
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Icon(
                        playlist.isDefault ? Icons.favorite : Icons.music_note, 
                        color: Colors.white
                      ),
                    ),
                    title: Text(playlist.name),
                    subtitle: Text('Playlist • ${playlist.songs.length} songs'),
                    trailing: playlist.isDefault 
                      ? null 
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => provider.deletePlaylist(playlist),
                        ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: playlist)
                      ));
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            child: const Text('Create', style: TextStyle(color: Color(0xFF1DB954))),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<MusicProvider>(context, listen: false).createPlaylist(controller.text);
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI: PLAYLIST DETAIL SCREEN
// -----------------------------------------------------------------------------

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    // Watch provider so if a song is removed, the UI updates immediately
    final provider = Provider.of<MusicProvider>(context);
    // Find the latest version of this playlist from the provider (to get updated song list)
    final currentPlaylist = provider.playlists.firstWhere((p) => p.id == playlist.id, orElse: () => playlist);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(currentPlaylist.name),
      ),
      body: currentPlaylist.songs.isEmpty
          ? const Center(child: Text("No songs in this playlist."))
          : ListView.builder(
              itemCount: currentPlaylist.songs.length,
              // Pass the current playlist to SongTile so it knows to show "Remove" option
              itemBuilder: (context, index) => SongTile(
                song: currentPlaylist.songs[index], 
                currentPlaylist: currentPlaylist
              ),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI: COMPONENTS
// -----------------------------------------------------------------------------

class SongArtwork extends StatelessWidget {
  final Song song;
  final double size;
  final double radius;

  const SongArtwork({super.key, required this.song, required this.size, this.radius = 4});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: song.isLocal
            ? QueryArtworkWidget(
                id: song.localId!,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              )
            : Container(color: Colors.grey),
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  final Song song;
  final Playlist? currentPlaylist; // NEW: To know if we are inside a playlist

  const SongTile({super.key, required this.song, this.currentPlaylist});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context, listen: false);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SongArtwork(song: song, size: 50),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<MusicProvider>(
            builder: (context, music, _) {
               return IconButton(
                icon: Icon(
                  song.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: song.isLiked ? const Color(0xFF1DB954) : Colors.grey,
                ),
                onPressed: () => music.toggleLike(song),
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptions(context, song),
          ),
        ],
      ),
      onTap: () {
        provider.playSong(song);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => FullPlayerScreen(song: song),
        );
      },
    );
  }

  void _showOptions(BuildContext context, Song song) {
    final provider = Provider.of<MusicProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option to Remove from Playlist (if we are in one)
            if (currentPlaylist != null && !currentPlaylist!.isDefault) ...[
               ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                title: const Text('Remove from this Playlist', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  provider.removeSongFromPlaylist(song, currentPlaylist!);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from playlist')),
                  );
                },
              ),
              const Divider(color: Colors.grey),
            ],

            Text('Add to Playlist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...provider.playlists.where((p) => !p.isDefault).map((playlist) => ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(playlist.name),
              onTap: () {
                provider.addSongToPlaylist(song, playlist);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to ${playlist.name}')),
                );
              },
            )),
            ListTile(
               leading: const Icon(Icons.add),
               title: const Text("Create New Playlist"),
               onTap: () {
                 Navigator.pop(ctx);
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Go to Library to create new playlists')),
                 );
               },
            )
          ],
        ),
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final Song song;
  const MiniPlayer({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: const Color(0xFF121212),
          builder: (context) => FullPlayerScreen(song: song),
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SongArtwork(song: song, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(song.isLiked ? Icons.favorite : Icons.favorite_border, color: song.isLiked ? const Color(0xFF1DB954) : Colors.grey, size: 20),
              onPressed: () => provider.toggleLike(song),
            ),
            IconButton(
              icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
              onPressed: () => provider.togglePlay(),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI: FULL PLAYER
// -----------------------------------------------------------------------------

class FullPlayerScreen extends StatelessWidget {
  final Song song;
  const FullPlayerScreen({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context, listen: false); 

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(song.artist.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1)),
        centerTitle: true,
        actions: [
          // 3-Dots Menu in Full Player
          IconButton(
            icon: const Icon(Icons.more_vert), 
            onPressed: () => _showPlayerOptions(context, song, provider)
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Spacer(),
            Container(
              height: 320,
              width: 320,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: SongArtwork(song: song, size: 320, radius: 8),
            ),
            const SizedBox(height: 40),
            
            // Title & Like
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                ),
                Consumer<MusicProvider>(
                  builder: (ctx, music, _) => IconButton(
                    icon: Icon(song.isLiked ? Icons.favorite : Icons.favorite_border, color: song.isLiked ? const Color(0xFF1DB954) : Colors.grey, size: 28),
                    onPressed: () => music.toggleLike(song),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress Bar
            StreamBuilder<Duration>(
              stream: provider.audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = provider.audioPlayer.duration ?? Duration.zero;
                
                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 4,
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.grey[800],
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble()),
                        max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1,
                        onChanged: (value) {
                          provider.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                );
              }
            ),
            
            const SizedBox(height: 10),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.shuffle, color: Colors.grey), onPressed: () {}),
                IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: () => provider.playPrevious()),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Consumer<MusicProvider>( 
                    builder: (ctx, music, _) => IconButton(
                      icon: Icon(music.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 32),
                      onPressed: () => music.togglePlay(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: () => provider.playNext()),
                IconButton(icon: const Icon(Icons.repeat, color: Colors.grey), onPressed: () {}),
              ],
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  void _showPlayerOptions(BuildContext context, Song song, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share"),
              onTap: () {
                Navigator.pop(ctx);
                // Placeholder for sharing
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sharing song link...")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text("Add to Playlist"),
              onTap: () {
                 Navigator.pop(ctx);
                 _showAddToPlaylistDialog(context, song, provider);
              },
            ),
          ],
        ),
      )
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text('Add to Playlist', style: Theme.of(context).textTheme.titleMedium),
             const Divider(color: Colors.grey),
             ...provider.playlists.where((p) => !p.isDefault).map((playlist) => ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(playlist.name),
                onTap: () {
                  provider.addSongToPlaylist(song, playlist);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to ${playlist.name}')),
                  );
                },
              )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$min:$sec";
  }
}