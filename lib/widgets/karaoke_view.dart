import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/providers/player_provider.dart';

/// Karaoke-style lyrics view.
/// Shows the full line; only the *current* word is bright white.
/// Past and future words render as liquid-glass (translucent).
class KaraokeView extends ConsumerStatefulWidget {
  final List<KaraokeLine> lines;
  final Stream<Duration> positionStream;
  final bool isEmbedded;
  final bool scrollable;
  final String? fontFamily;

  const KaraokeView({
    super.key,
    required this.lines,
    required this.positionStream,
    this.isEmbedded = true,
    this.scrollable = true,
    this.fontFamily,
  });

  @override
  ConsumerState<KaraokeView> createState() => _KaraokeViewState();
}

class _KaraokeViewState extends ConsumerState<KaraokeView> with SingleTickerProviderStateMixin {
  StreamSubscription<Duration>? _sub;
  Duration _position = Duration.zero;
  int _activeLineIndex = -1;

  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _lineKeys;

  bool _isUserScrolling = false;
  Timer? _userScrollTimer;

  int _activeSyllableIndex = -1;

  Ticker? _ticker;
  DateTime _lastUpdateTime = DateTime.now();
  Duration _lastStreamPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
    _sub = widget.positionStream.listen((pos) {
      if (!mounted) return;
      _lastStreamPosition = pos;
      _lastUpdateTime = DateTime.now();
      _position = pos;
      _updateActiveState();
    });

    _ticker = createTicker((elapsed) {
      final player = ref.read(audioHandlerProvider).player;
      if (player.playing && mounted) {
        final now = DateTime.now();
        final delta = now.difference(_lastUpdateTime);
        final speed = player.speed;
        final newPos = _lastStreamPosition + delta * speed;
        setState(() {
          _position = newPos;
          _updateActiveState();
        });
      }
    });
    _ticker!.start();
  }

  void _updateActiveState() {
    int newLineIndex = -1;
    for (int i = widget.lines.length - 1; i >= 0; i--) {
      if (_position >= widget.lines[i].lineStart) {
        newLineIndex = i;
        break;
      }
    }

    int newSylIndex = -1;
    if (newLineIndex >= 0 && newLineIndex < widget.lines.length) {
      final line = widget.lines[newLineIndex];
      for (int i = line.syllables.length - 1; i >= 0; i--) {
        final syl = line.syllables[i];
        if (_position >= syl.time) {
          final Duration end = i < line.syllables.length - 1
              ? line.syllables[i + 1].time
              : syl.time + syl.duration;
          if (_position < end) {
            newSylIndex = i;
          }
          break;
        }
      }
    }

    if (newLineIndex != _activeLineIndex || newSylIndex != _activeSyllableIndex) {
      final bool lineChanged = newLineIndex != _activeLineIndex;
      setState(() {
        _activeLineIndex = newLineIndex;
        _activeSyllableIndex = newSylIndex;
      });
      if (lineChanged) {
        _scrollToActiveLine();
      }
    }
  }

  void _scrollToActiveLine() {
    if (_activeLineIndex < 0 || _isUserScrolling) return;
    final key = _lineKeys[_activeLineIndex];
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
  void dispose() {
    _sub?.cancel();
    _userScrollTimer?.cancel();
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = widget.isEmbedded ? 24.0 : 28.0;

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
            final bool isActive = index == _activeLineIndex;

            return GestureDetector(
              onTap: () {
                _userScrollTimer?.cancel();
                setState(() {
                  _isUserScrolling = false;
                });
                ref.read(audioHandlerProvider).player.seek(line.lineStart);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                key: _lineKeys[index],
                padding: EdgeInsets.only(
                  top: 10,
                  bottom: 10,
                  left: isActive ? 16.0 : 0.0,
                ),
                color: Colors.transparent,
                width: double.infinity,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  opacity: isActive ? 1.0 : 0.50,
                  child: _buildLineContent(line, fontSize, isActive),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Builds the text content of the line. Always returns Text.rich (RenderParagraph)
  /// so that widget tree structures are identical between active and inactive lines.
  Widget _buildLineContent(KaraokeLine line, double fontSize, bool isActive) {
    final TextStyle baseStyle = TextStyle(
      fontFamily: widget.fontFamily,
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

    if (!isActive) {
      return Text.rich(
        TextSpan(
          text: line.fullText,
          style: baseStyle,
        ),
        textAlign: TextAlign.left,
      );
    }

    final List<InlineSpan> spans = [];
    for (int i = 0; i < line.syllables.length; i++) {
      final syl = line.syllables[i];
      final start = syl.time;
      final end = i < line.syllables.length - 1
          ? line.syllables[i + 1].time
          : syl.time + syl.duration;

      double progress = 0.0;
      if (_position >= end) {
        progress = 1.0;
      } else if (_position >= start) {
        final durationMs = end.inMilliseconds - start.inMilliseconds;
        if (durationMs > 0) {
          progress = (_position.inMilliseconds - start.inMilliseconds) / durationMs;
        } else {
          progress = 1.0;
        }
      }
      progress = progress.clamp(0.0, 1.0);

      if (progress == 1.0) {
        spans.add(TextSpan(
          text: syl.text,
          style: baseStyle,
        ));
      } else if (progress == 0.0) {
        spans.add(TextSpan(
          text: syl.text,
          style: baseStyle.copyWith(
            color: Colors.white.withValues(alpha: 0.50),
          ),
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.50),
                ],
                stops: [progress, progress],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            child: Text(
              syl.text,
              style: baseStyle.copyWith(
                shadows: null,
              ),
            ),
          ),
        ));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.left,
    );
  }
}
