import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JT My Music Player',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: MusicHomePage(),
    );
  }
}

class MusicHomePage extends StatefulWidget {
  @override
  _MusicHomePageState createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final TextEditingController _urlController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<String> _savedUrls = [];
  YoutubePlayerController? _youtubePlayerController;
  String _currentVideoId = ''; // 현재 동영상 ID
  bool _isPlayerReady = false; // 플레이어 준비 상태 체크
  int _currentVideoIndex = 0; // 현재 재생 중인 비디오 인덱스

  @override
  void initState() {
    super.initState();
    _initializeYoutubePlayer();
    _loadSavedUrls();
  }

  @override
  void dispose() {
    _youtubePlayerController?.dispose();
    super.dispose();
  }

  // YouTubePlayerController 초기화
  void _initializeYoutubePlayer() {
    if (_currentVideoId.isNotEmpty) {
      _youtubePlayerController = YoutubePlayerController(
        initialVideoId: _currentVideoId, // 현재 비디오 ID로 초기화
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          showLiveFullscreenButton: true,
        ),
      )
        ..addListener(() {
          if (_youtubePlayerController!.value.isReady && !_isPlayerReady) {
            setState(() {
              _isPlayerReady = true;
            });
          }
        })
        ..addListener(_onVideoEnded); // 비디오 끝났을 때 호출
    }
  }

  // 비디오가 끝났을 때 호출되는 함수
  void _onVideoEnded() {
    if (_youtubePlayerController != null &&
        _youtubePlayerController!.value.playerState == PlayerState.ended) {
      // 다음 비디오 로드
      _playNextVideo();
    }
  }

  // 다음 비디오 재생
  void _playNextVideo() {
    if (_savedUrls.isNotEmpty) {
      setState(() {
        _currentVideoIndex =
            (_currentVideoIndex + 1) % _savedUrls.length; // 순차적으로 반복 재생
        _loadNewVideo(_savedUrls[_currentVideoIndex]);
      });
    }
  }

  // URL 목록 불러오기
  _loadSavedUrls() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedUrls = prefs.getStringList('youtube_urls') ?? [];
    });
  }

  // URL 저장하기
  _saveUrl(String url) async {
    if (url.isNotEmpty && Uri.parse(url).isAbsolute) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedUrls.add(url);
      });
      await prefs.setStringList('youtube_urls', _savedUrls);
      _urlController.clear();
      _showSnackbar('URL saved successfully!');
    } else {
      _showSnackbar('Invalid URL. Please enter a valid YouTube URL.');
    }
  }

  // YouTube 비디오 ID 파싱
  String? _parseUtubeID(String url) {
    if (!url.startsWith('https://')) {
      url = 'https://$url'; // https가 없으면 추가
    }
    return YoutubePlayer.convertUrlToId(url); // 비디오 ID 얻기
  }

  // Snackbar 표시
  _showSnackbar(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // 새로운 비디오를 로드하는 함수
  void _loadNewVideo(String url) {
    String? videoId = _parseUtubeID(url);
    if (videoId != null) {
      _loadNewVideo(videoId); // 새로운 동영상 로드
    } else {
      _showSnackbar('Invalid YouTube URL');
      return;
    }

    if (_youtubePlayerController != null) {
      _youtubePlayerController!.load(videoId);
    } else {
      _youtubePlayerController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
        ),
      )..addListener(() {
          if (_youtubePlayerController!.value.isReady && !_isPlayerReady) {
            setState(() {
              _isPlayerReady = true;
            });
          }
        });
    }
    setState(() {
      _currentVideoId = videoId; // 현재 비디오 ID 업데이트
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JT Music Player'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSavedUrls,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'YouTube URL',
                  hintText: 'Input youtube URL',
                  hintStyle: TextStyle(
                    color: Colors.grey[300], // 옅은 회색으로 설정
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _urlController.clear();
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Column(
                children: [
                  // 동영상 로드 상태 처리
                  if (_youtubePlayerController != null)
                    YoutubePlayer(
                      controller: _youtubePlayerController!,
                      showVideoProgressIndicator: true,
                      onReady: () {
                        print('Player is ready.');
                      },
                    )
                  else
                    Container(
                      height: 0,
                    ),
                  SizedBox(height: 20),
                  Expanded(
                    child: _savedUrls.isEmpty
                        ? Center(
                            child: Text(
                              'No saved URLs',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _savedUrls.length,
                            itemBuilder: (context, index) {
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                                child: ListTile(
                                  contentPadding: EdgeInsets.all(16),
                                  title: Text(
                                    _savedUrls[index],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    _currentVideoIndex = index;
                                    _loadNewVideo(_savedUrls[index]);
                                  },
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _savedUrls.removeAt(index);
                                      });
                                      _saveUpdatedUrls();
                                      _showSnackbar(
                                          'URL removed successfully!');
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _saveUrl(_urlController.text);
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.purple,
      ),
    );
  }

  // URL 목록 업데이트
  _saveUpdatedUrls() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('youtube_urls', _savedUrls);
  }
}
