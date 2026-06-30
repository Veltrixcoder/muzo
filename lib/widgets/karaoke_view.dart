import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/providers/player_provider.dart';

class KaraokeGroup {
  final Duration lineStart;
  final String fullText;
  final List<KaraokeSyllable> syllables;
  final String? translation;

  KaraokeGroup({
    required this.lineStart,
    required this.fullText,
    required this.syllables,
    this.translation,
  });
}

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

class _KaraokeViewState extends ConsumerState<KaraokeView> {
  StreamSubscription<Duration>? _sub;
  Duration _position = Duration.zero;
  int _activeLineIndex = -1;

  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _lineKeys;

  bool _isUserScrolling = false;
  Timer? _userScrollTimer;

  int _activeSyllableIndex = -1;
  List<KaraokeGroup> _groupedLines = [];

  @override
  void initState() {
    super.initState();

    // Group lines with the same timestamp (translation/transition support)
    final grouped = <KaraokeGroup>[];
    for (var line in widget.lines) {
      if (grouped.isNotEmpty && grouped.last.lineStart == line.lineStart) {
        final last = grouped.last;
        grouped[grouped.length - 1] = KaraokeGroup(
          lineStart: last.lineStart,
          fullText: last.fullText,
          syllables: last.syllables,
          translation: line.fullText,
        );
      } else {
        grouped.add(KaraokeGroup(
          lineStart: line.lineStart,
          fullText: line.fullText,
          syllables: line.syllables,
        ));
      }
    }
    _groupedLines = grouped;
    _lineKeys = List.generate(_groupedLines.length, (_) => GlobalKey());

    _sub = widget.positionStream.listen((pos) {
      if (!mounted) return;
      _position = pos;
      _updateActiveState();
    });
  }

  void _updateActiveState() {
    int newLineIndex = -1;
    for (int i = _groupedLines.length - 1; i >= 0; i--) {
      if (_position >= _groupedLines[i].lineStart) {
        newLineIndex = i;
        break;
      }
    }

    int newSylIndex = -1;
    if (newLineIndex >= 0 && newLineIndex < _groupedLines.length) {
      final line = _groupedLines[newLineIndex];
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
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          vertical: widget.isEmbedded ? 24 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_groupedLines.length, (index) {
            final line = _groupedLines[index];
            final bool isActive = index == _activeLineIndex;

            final lineContent = line.translation != null && line.translation!.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLineContent(line, isActive),
                      Padding(
                        padding: const EdgeInsets.only(left: 12.5, right: 12.5, top: 2.0, bottom: 18.0),
                        child: Text(
                          line.translation!,
                          style: TextStyle(
                            fontFamily: widget.fontFamily,
                            fontSize: 20.0,
                            fontWeight: FontWeight.w500,
                            color: isActive ? Colors.white.withValues(alpha: 0.70) : Colors.white.withValues(alpha: 0.30),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  )
                : _buildLineContent(line, isActive);

            return GestureDetector(
              onTap: () {
                _userScrollTimer?.cancel();
                setState(() {
                  _isUserScrolling = false;
                });
                ref.read(audioHandlerProvider).player.seek(line.lineStart);
              },
              child: Container(
                key: _lineKeys[index],
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
                color: Colors.transparent,
                child: AnimatedScale(
                  scale: isActive ? 1.0 : 0.98,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    opacity: isActive ? 1.0 : 0.40,
                    child: lineContent,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLineContent(KaraokeGroup line, bool isActive) {
    final TextStyle activeStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: 34.0,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.2,
    );

    final TextStyle inactiveStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: 34.0,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.35),
      height: 1.2,
    );

    if (!isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.5, vertical: 18.0),
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 6.0,
          runSpacing: 4.0,
          children: line.syllables.map((syl) {
            return Text(
              syl.text,
              style: inactiveStyle,
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.5, vertical: 18.0),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 6.0,
        runSpacing: 4.0,
        children: List.generate(line.syllables.length, (i) {
          final syl = line.syllables[i];
          final bool isWordActive = i <= _activeSyllableIndex;

          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: isWordActive ? activeStyle : inactiveStyle,
            child: Text(syl.text),
          );
        }),
      ),
    );
  }
}
