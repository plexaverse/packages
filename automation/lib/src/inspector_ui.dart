import 'package:flutter/material.dart';
import 'dart:ui';
import 'test_registry.dart';
import 'interaction_engine.dart';
import 'reporter.dart';

class AutomationInspectorOverlay extends StatefulWidget {
  const AutomationInspectorOverlay({super.key});

  @override
  State<AutomationInspectorOverlay> createState() => _AutomationInspectorOverlayState();
}

class _AutomationInspectorOverlayState extends State<AutomationInspectorOverlay> with TickerProviderStateMixin {
  bool _isExpanded = false;
  TestCase? _runningTest;
  int _currentStepIndex = -1;
  Offset? _highlightPosition;

  // Minimization state for testing box
  bool _isTestBoxMinimized = false;

  // Position for the moveable button
  Offset _buttonPosition = const Offset(20, 20); // Default bottom-left
  bool _isDragging = false;
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    // This is a prototype hack to allow the engine to trigger highlights in the UI
    AutomationEngine.instance.onInteraction = (Offset position) {
      if (mounted) {
        setState(() => _highlightPosition = position);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _highlightPosition = null);
        });
      }
    };
  }

  void _snapToPosition(Size screenSize) {
    const double margin = 20.0;
    const double buttonSize = 42.0;

    // Allow horizontal movement anywhere, but keep vertical in the bottom 40%
    final double maxDy = screenSize.height * 0.4;
    double targetDy = _buttonPosition.dy.clamp(margin, maxDy);

    // Snap horizontally to nearest side if not dragging
    double targetDx;
    if (_buttonPosition.dx + buttonSize / 2 < screenSize.width / 2) {
      targetDx = margin;
    } else {
      targetDx = screenSize.width - buttonSize - margin;
    }

    setState(() {
      _buttonPosition = Offset(targetDx, targetDy);
    });
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    final bool isLeft = _buttonPosition.dx < _screenSize!.width / 2;

    return Stack(
      children: [
        _buildHighlightRipple(),
        AnimatedPositioned(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          // Dynamically anchor to left or right based on position
          left: isLeft ? _buttonPosition.dx : null,
          right: isLeft ? null : _screenSize!.width - _buttonPosition.dx - 42.0,
          bottom: _buttonPosition.dy,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  // Limit vertical movement to bottom 40% of screen
                  final double newDy = _buttonPosition.dy - details.delta.dy;
                  if (newDy < _screenSize!.height * 0.4) {
                    _buttonPosition = Offset(
                      (_buttonPosition.dx + details.delta.dx).clamp(0.0, _screenSize!.width - 42.0),
                      newDy.clamp(0.0, _screenSize!.height * 0.4),
                    );
                  }
                });
              },
              onPanEnd: (_) {
                setState(() => _isDragging = false);
                _snapToPosition(_screenSize!);
              },
              child: Column(
                crossAxisAlignment: _buttonPosition.dx < _screenSize!.width / 2
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isExpanded ? _buildExpandedMenu() : const SizedBox.shrink(),
                  ),
                  if (_runningTest != null) _buildRunningTestStatus(),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: _isDragging ? 25 : 15,
                            spreadRadius: _isDragging ? 5 : 2,
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: Icon(
                        _isExpanded ? Icons.close_rounded : Icons.bug_report_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightRipple() {
    if (_highlightPosition == null) return const SizedBox.shrink();

    return Positioned(
      left: _highlightPosition!.dx - 30,
      top: _highlightPosition!.dy - 30,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Opacity(
            opacity: 1.0 - value,
            child: Container(
              width: 60 * value,
              height: 60 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 4 * (1.0 - value)),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.5 * (1.0 - value)), blurRadius: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _selectedTabIndex = 0; // 0: Tests, 1: History

  Widget _buildExpandedMenu() {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderTabs(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: _selectedTabIndex == 0 ? _buildTestsList() : _buildHistoryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabItem('Test Cases', 0),
          _buildTabItem('History', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestsList() {
    final tests = AutomationRegistry.instance.tests;
    if (tests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text('No tests found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tests.length,
      itemBuilder: (context, index) => _buildTestItem(tests[index]),
    );
  }

  Widget _buildHistoryList() {
    final results = TestReporter.instance.results; // Make sure reporter.dart exposes this!
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text('No history yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      reverse: true, // Show newest first
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.cancel,
                color: result.success ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.testName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      '${result.durationMs}ms • ${result.timestamp.split("T").last.split(".").first}',
                      style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestItem(TestCase test) {
    return InkWell(
      onTap: () => _runTest(test),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${test.steps.length} steps', style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningTestStatus() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      child: Container(
        width: _isTestBoxMinimized ? 150 : 300,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_bottom_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _runningTest!.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isTestBoxMinimized ? Icons.unfold_more_rounded : Icons.unfold_less_rounded, size: 18),
                        onPressed: () => setState(() => _isTestBoxMinimized = !_isTestBoxMinimized),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_currentStepIndex + 1) / _runningTest!.steps.length,
                      backgroundColor: Colors.green.withOpacity(0.1),
                      color: Colors.green,
                      minHeight: 8,
                    ),
                  ),
                  if (!_isTestBoxMinimized) ...[
                    const SizedBox(height: 16),
                    ..._runningTest!.steps.map((step) => _buildStepRow(step)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(TestStep step) {
    bool isRunning = step.status == TestStatus.running;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: step.status == TestStatus.pending ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (isRunning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
              )
            else
              Icon(
                step.status == TestStatus.passed ? Icons.check_circle_rounded : 
                step.status == TestStatus.failed ? Icons.error_rounded : Icons.circle_outlined,
                color: step.status == TestStatus.passed ? Colors.green : 
                       step.status == TestStatus.failed ? Colors.red : Colors.grey,
                size: 18,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.description,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isRunning ? FontWeight.w800 : FontWeight.w500,
                  color: isRunning ? Colors.green : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTest(TestCase test) async {
    setState(() {
      _runningTest = test;
      _currentStepIndex = 0;
      _isExpanded = false;
      _isTestBoxMinimized = false;
      _highlightPosition = null;
      for (var s in test.steps) s.status = TestStatus.pending;
    });

    final stopwatch = Stopwatch()..start();
    TestReporter.instance.onTestStart(test);

    bool allPassed = true;
    for (int i = 0; i < test.steps.length; i++) {
      if (!mounted) { allPassed = false; break; }
      
      final step = test.steps[i];
      setState(() {
        _currentStepIndex = i;
        step.status = TestStatus.running;
      });

      final stepWatch = Stopwatch()..start();
      try {
        await step.action();
        stepWatch.stop();
        if (mounted) setState(() => step.status = TestStatus.passed);
        TestReporter.instance.onTestStepPassed(test, step, stepWatch.elapsed);
      } catch (e, stack) {
        stepWatch.stop();
        if (mounted) setState(() => step.status = TestStatus.failed);
        TestReporter.instance.onTestStepFailed(test, step, e, stack);
        allPassed = false;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 2500));
    }

    stopwatch.stop();
    TestReporter.instance.onTestComplete(test, allPassed, stopwatch.elapsed);

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _runningTest = null;
        _currentStepIndex = -1;
      });
    }
  }
}

