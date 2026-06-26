import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/karaoke_view.dart';
import 'package:muzo/providers/player_provider.dart';

class SyncedLyricLine {
  final Duration time;
  final String text;
  SyncedLyricLine({required this.time, required this.text});
}

class LyricsView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final VoidCallback onClose;
  final Stream<Duration> positionStream;
  final Duration totalDuration;
  final bool isEmbedded;
  final bool scrollable;
  final Color? accentColor;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.onClose,
    required this.positionStream,
    required this.totalDuration,
    this.isEmbedded = true,
    this.scrollable = true,
    this.accentColor,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  bool get _isKaraoke => widget.lyrics.karaokeLines != null;
  bool get _isSynced => widget.lyrics.syncedLyrics.trim().isNotEmpty;
  bool get _hasPlainLyrics => widget.lyrics.plainLyrics.trim().isNotEmpty;

  List<SyncedLyricLine> _parsedSyncedLines = [];

  @override
  void initState() {
    super.initState();
    if (!_isKaraoke && _isSynced) {
      _parsedSyncedLines = _parseLrc(widget.lyrics.syncedLyrics);
    }
  }

  List<SyncedLyricLine> _parseLrc(String lrcText) {
    final lines = lrcText.split('\n');
    final regExp = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\](.*)$');
    final list = <SyncedLyricLine>[];
    for (var line in lines) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final secondsDouble = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        final ms = (minutes * 60 * 1000) + (secondsDouble * 1000).toInt();
        list.add(SyncedLyricLine(time: Duration(milliseconds: ms), text: text));
      }
    }
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  Widget _buildFallbackView(BuildContext context, String? fontFamily, {required bool isInstrumental}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isInstrumental ? CupertinoIcons.music_note_2 : CupertinoIcons.text_alignleft,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isInstrumental ? "Instrumental" : "No lyrics available",
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: widget.isEmbedded ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyricsView(BuildContext context, String? fontFamily) {
    final List<String> rawLines = widget.lyrics.plainLyrics.split('\n');
    final double fontSize = widget.isEmbedded ? 22.0 : 26.0;

    return SingleChildScrollView(
      physics: widget.scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: widget.isEmbedded ? 24 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: widget.isEmbedded ? 12 : 24),
          ...rawLines.map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) {
              return const SizedBox(height: 20);
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                trimmed,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
            );
          }),
          SizedBox(height: widget.isEmbedded ? 24 : 48),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return Column(
      children: [
        if (widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Lyrics",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

        Expanded(
          child: _isKaraoke
              ? KaraokeView(
                  lines: widget.lyrics.karaokeLines!,
                  positionStream: widget.positionStream,
                  isEmbedded: widget.isEmbedded,
                  scrollable: widget.scrollable,
                  fontFamily: fontFamily,
                )
              : (widget.lyrics.instrumental || !_hasPlainLyrics
                  ? _buildFallbackView(context, fontFamily, isInstrumental: widget.lyrics.instrumental)
                  : (!_isSynced
                      ? _buildPlainLyricsView(context, fontFamily)
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 14.0),
                          child: SyncedLyricsScroller(
                            lines: _parsedSyncedLines,
                            positionStream: widget.positionStream,
                            totalDuration: widget.totalDuration,
                            isEmbedded: widget.isEmbedded,
                            scrollable: widget.scrollable,
                          ),
                        ))),
        ),
      ],
    );
  }
}

class SyncedLyricsScroller extends ConsumerStatefulWidget {
  final List<SyncedLyricLine> lines;
  final Stream<Duration> positionStream;
  final Duration totalDuration;
  final bool isEmbedded;
  final bool scrollable;

  const SyncedLyricsScroller({
    super.key,
    required this.lines,
    required this.positionStream,
    required this.totalDuration,
    this.isEmbedded = true,
    this.scrollable = true,
  });

  @override
  ConsumerState<SyncedLyricsScroller> createState() => _SyncedLyricsScrollerState();
}

class _SyncedLyricsScrollerState extends ConsumerState<SyncedLyricsScroller> with SingleTickerProviderStateMixin {
  StreamSubscription<Duration>? _positionSubscription;
  Duration _currentPosition = Duration.zero;
  int _activeIndex = -1;
  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _lineKeys;

  bool _isUserScrolling = false;
  Timer? _userScrollTimer;

  Ticker? _ticker;
  DateTime _lastUpdateTime = DateTime.now();
  Duration _lastStreamPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
    _positionSubscription = widget.positionStream.listen((duration) {
      if (!mounted) return;
      _lastStreamPosition = duration;
      _lastUpdateTime = DateTime.now();
      _currentPosition = duration;
      _updateActiveLine();
    });

    _ticker = createTicker((elapsed) {
      final player = ref.read(audioHandlerProvider).player;
      if (player.playing && mounted) {
        final now = DateTime.now();
        final delta = now.difference(_lastUpdateTime);
        final speed = player.speed;
        final newPos = _lastStreamPosition + delta * speed;
        setState(() {
          _currentPosition = newPos;
          _updateActiveLine();
        });
      }
    });
    _ticker!.start();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _userScrollTimer?.cancel();
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateActiveLine() {
    if (widget.lines.isEmpty) return;

    // 1. Find the timestamp T of the active block
    int baseIndex = -1;
    for (int i = widget.lines.length - 1; i >= 0; i--) {
      if (_currentPosition >= widget.lines[i].time) {
        baseIndex = i;
        break;
      }
    }

    if (baseIndex == -1) {
      if (_activeIndex != -1) {
        setState(() {
          _activeIndex = -1;
        });
      }
      return;
    }

    final T = widget.lines[baseIndex].time;

    // 2. Find the start index of this block sharing the same timestamp T
    int blockStartIndex = baseIndex;
    while (blockStartIndex > 0 && widget.lines[blockStartIndex - 1].time == T) {
      blockStartIndex--;
    }

    // 3. Find the length of this block
    int blockLength = 0;
    while (blockStartIndex + blockLength < widget.lines.length &&
        widget.lines[blockStartIndex + blockLength].time == T) {
      blockLength++;
    }

    // 4. Calculate block start and end times
    final nextDiffIndex = blockStartIndex + blockLength;
    final end = nextDiffIndex < widget.lines.length
        ? widget.lines[nextDiffIndex].time
        : widget.totalDuration;

    final blockDurationMs = end.inMilliseconds - T.inMilliseconds;

    int activeOffset = 0;
    if (blockLength > 1 && blockDurationMs > 0) {
      final elapsedMs = _currentPosition.inMilliseconds - T.inMilliseconds;
      final segmentMs = blockDurationMs / blockLength;
      activeOffset = (elapsedMs / segmentMs).floor().clamp(0, blockLength - 1);
    }

    int newIndex = blockStartIndex + activeOffset;

    if (newIndex != _activeIndex) {
      setState(() {
        _activeIndex = newIndex;
      });
      _scrollToActiveLine();
    }
  }

  void _scrollToActiveLine() {
    if (_activeIndex < 0 || _isUserScrolling) return;
    final key = _lineKeys[_activeIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        final renderObj = ctx.findRenderObject();
        final scrollable = Scrollable.maybeOf(ctx);
        if (renderObj != null && scrollable != null) {
          scrollable.position.ensureVisible(
            renderObj,
            alignment: 0.3,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final double fontSize = widget.isEmbedded ? 24.0 : 28.0;

    final TextStyle lineStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.4,
      shadows: const [
        Shadow(
          offset: Offset(0, 2),
          blurRadius: 8,
          color: Colors.black38,
        ),
      ],
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle) {
            _userScrollTimer?.cancel();
            if (!_isUserScrolling) {
              setState(() {
                _isUserScrolling = true;
              });
            }
            _userScrollTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _isUserScrolling = false;
                  _scrollToActiveLine();
                });
              }
            });
          } else {
            if (_isUserScrolling) {
              _userScrollTimer?.cancel();
              _userScrollTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _isUserScrolling = false;
                    _scrollToActiveLine();
                  });
                }
              });
            }
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: widget.scrollable
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: widget.isEmbedded ? 24 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(widget.lines.length, (index) {
            final line = widget.lines[index];
            final bool isActive = index == _activeIndex;

            return GestureDetector(
              onTap: () {
                _userScrollTimer?.cancel();
                setState(() {
                  _isUserScrolling = false;
                });
                ref.read(audioHandlerProvider).player.seek(line.time);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                key: _lineKeys[index],
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: 10.0,
                  bottom: 10.0,
                  left: isActive ? 16.0 : 0.0,
                ),
                color: Colors.transparent,
                transform: isActive
                    ? Matrix4.translationValues(0.0, -4.0, 0.0)
                    : Matrix4.identity(),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  opacity: isActive ? 1.0 : 0.50,
                  child: Text(
                    line.text,
                    style: isActive
                        ? lineStyle
                        : lineStyle.copyWith(
                            color: Colors.white.withValues(alpha: 0.50),
                          ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
