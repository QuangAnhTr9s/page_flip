import 'dart:async';

import 'package:flutter/material.dart';

import '../page_flip.dart';

class PageFlipWidget extends StatefulWidget {
  const PageFlipWidget({
    Key? key,
    this.duration = const Duration(milliseconds: 450),
    this.cutoffForward = 0.8,
    this.cutoffPrevious = 0.1,
    this.backgroundColor = Colors.white,
    required this.children,
    this.initialIndex = 0,
    this.lastPage,
    this.isRightSwipe = false,
    this.onPageChanged,
    this.minScale = 1.0,
    this.maxScale = 2.0,
    this.initScale = 1.0,
  })  : assert(initialIndex < children.length, 'initialIndex cannot be greater than children length'),
        super(key: key);

  final Color backgroundColor;
  final List<Widget> children;
  final Duration duration;
  final int initialIndex;
  final Widget? lastPage;
  final double cutoffForward;
  final double cutoffPrevious;
  final bool isRightSwipe;
  final ValueChanged<int>? onPageChanged;
  final double? minScale;
  final double? maxScale;
  final double? initScale;


  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

class PageFlipWidgetState extends State<PageFlipWidget> with TickerProviderStateMixin {
  int pageNumber = 0;
  List<Widget> pages = [];
  final List<AnimationController> _controllers = [];
  bool? _isForward;
  double scale = 1.0;
  double _minScale = 1.0;
  double _maxScale = 2.0;
  Offset _offset = Offset.zero;
  double _previousScale = 1.0;
  Offset _previousOffset = Offset.zero;


  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    imageData = {};
    currentPage = ValueNotifier(-1);
    currentWidget = ValueNotifier(Container());
    currentPageIndex = ValueNotifier(0);
    scale = widget.initScale ?? 1.0;
    _setUp();
  }

  void _setUp({bool isRefresh = false}) {
    _controllers.clear();
    pages.clear();
    if (widget.lastPage != null) {
      widget.children.add(widget.lastPage!);
    }
    for (var i = 0; i < widget.children.length; i++) {
      final controller = AnimationController(
        value: 1,
        duration: widget.duration,
        vsync: this,
      );
      _controllers.add(controller);
      final child = PageFlipBuilder(
        amount: controller,
        backgroundColor: widget.backgroundColor,
        isRightSwipe: widget.isRightSwipe,
        pageIndex: i,
        key: Key('item$i'),
        child: widget.children[i],
      );
      pages.add(child);
    }
    pages = pages.reversed.toList();
    if (isRefresh) {
      goToPage(pageNumber);
    } else {
      pageNumber = widget.initialIndex;
      lastPageLoad = pages.length < 3 ? 0 : 3;
    }
    if (widget.initialIndex != 0) {
      currentPage = ValueNotifier(widget.initialIndex);
      currentWidget = ValueNotifier(pages[pageNumber]);
      currentPageIndex = ValueNotifier(widget.initialIndex);
    }
  }

  bool get _isLastPage => (pages.length - 1) == pageNumber;

  int lastPageLoad = 0;

  bool get _isFirstPage => pageNumber == 0;

  void _turnPage(DragUpdateDetails details, BoxConstraints dimens) {
    // if ((_isLastPage) || !isFlipForward.value) return;
    currentPage.value = pageNumber;
    currentWidget.value = Container();
    final ratio = details.delta.dx / dimens.maxWidth;
    if (_isForward == null) {
      if (widget.isRightSwipe ? details.delta.dx < 0.0 : details.delta.dx > 0.0) {
        _isForward = false;
      } else if (widget.isRightSwipe ? details.delta.dx > 5 : details.delta.dx < -5) {
        _isForward = true;
      } else {
        _isForward = null;
      }
    }

    if (_isForward == true || pageNumber == 0) {
      final pageLength = pages.length;
      final pageSize = widget.lastPage != null ? pageLength : pageLength - 1;
      if (pageNumber != pageSize && !_isLastPage) {
        widget.isRightSwipe ? _controllers[pageNumber].value -= ratio : _controllers[pageNumber].value += ratio;
      }
    }
  }

  Future _onDragFinish() async {
    if (_isForward != null) {
      if (_isForward == true) {
        if (!_isLastPage && _controllers[pageNumber].value <= (widget.cutoffForward + 0.15)) {
          await nextPage();
        } else {
          if (!_isLastPage) {
            await _controllers[pageNumber].forward();
          }
        }
      } else {
        if (!_isFirstPage && _controllers[pageNumber - 1].value >= widget.cutoffPrevious) {
          await previousPage();
        } else {
          if (_isFirstPage) {
            await _controllers[pageNumber].forward();
          } else {
            await _controllers[pageNumber - 1].reverse();
            if (!_isFirstPage) {
              await previousPage();
            }
          }
        }
      }
    }

    _isForward = null;
    currentPage.value = -1;
  }

  Future nextPage() async {
    await _controllers[pageNumber].reverse();
    if (mounted) {
      setState(() {
        pageNumber++;
      });
    }

    if (pageNumber < pages.length) {
      currentPageIndex.value = pageNumber;
      currentWidget.value = pages[pageNumber];
      if(widget.onPageChanged != null) {
        widget.onPageChanged!(pageNumber);
      }
    }

    if (_isLastPage) {
      currentPageIndex.value = pageNumber;
      currentWidget.value = pages[pageNumber];
      return;
    }
  }

  Future previousPage() async {
    await _controllers[pageNumber - 1].forward();
    if (mounted) {
      setState(() {
        pageNumber--;
      });
    }
    currentPageIndex.value = pageNumber;
    currentWidget.value = pages[pageNumber];
    imageData[pageNumber] = null;
    if(widget.onPageChanged != null) {
      widget.onPageChanged!(pageNumber);
    }
  }

  Future goToPage(int index) async {
    if (mounted) {
      setState(() {
        pageNumber = index;
      });
      if(widget.onPageChanged != null) {
        widget.onPageChanged!(pageNumber);
      }
    }
    for (var i = 0; i < _controllers.length; i++) {
      if (i == index) {
        _controllers[i].forward();
      } else if (i < index) {
        _controllers[i].reverse();
      } else {
        if (_controllers[i].status == AnimationStatus.reverse) {
          _controllers[i].value = 1;
        }
      }
    }
    currentPageIndex.value = pageNumber;
    currentWidget.value = pages[pageNumber];
    currentPage.value = pageNumber;
  }
  void increaseScale() {
    if(scale > (widget.maxScale ?? _maxScale) ) return;
    setState(() {
      scale *= 1.1;
    });
  }

  void decreaseScale() {
    if(scale < (widget.minScale ?? _minScale)) return;
    setState(() {
      scale /= 1.1;
    });
    _adjustOffset();
  }

  void resetScale() {
    setState(() {
      scale = widget.initScale ?? 1.0;
    });
    _adjustOffset();
  }
  void _adjustOffset() {
    final maxOffsetX = (context.size!.width * (scale - 1)) / 2;
    final maxOffsetY = (context.size!.height * (scale - 1)) / 2;

    _offset = Offset(
      _offset.dx.clamp(-maxOffsetX, maxOffsetX),
      _offset.dy.clamp(-maxOffsetY, maxOffsetY),
    );
  }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimens) => GestureDetector(
        onScaleStart: (details) {
          _previousScale = scale;
          _previousOffset = details.focalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            scale = (_previousScale * details.scale).clamp(_minScale, _maxScale);

            // Giới hạn việc di chuyển widget
            final newOffset = _offset + (details.focalPoint - _previousOffset);
            final maxOffsetX = (context.size!.width * (scale - 1)) / 2;
            final maxOffsetY = (context.size!.height * (scale - 1)) / 2;

            _offset = Offset(
              newOffset.dx.clamp(-maxOffsetX, maxOffsetX),
              newOffset.dy.clamp(-maxOffsetY, maxOffsetY),
            );

            _previousOffset = details.focalPoint;
          });
        },
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {},
        onTapUp: (details) {},
        // onPanDown: (details) {},
        // onPanEnd: (details) {},
        onTapCancel: () {},
        onHorizontalDragCancel: () => _isForward = null,
        onHorizontalDragUpdate: (details) => _turnPage(details, dimens),
        onHorizontalDragEnd: (details) => _onDragFinish(),
        child: Transform.translate(
          offset: _offset,
          child: Transform.scale(
            scale: scale,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (widget.lastPage != null) ...[
                  widget.lastPage!,
                ],
                if (pages.isNotEmpty) ...pages else ...[const SizedBox.shrink()],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
