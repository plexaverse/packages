import 'package:flutter/material.dart';
import 'dart:ui';
import 'test_registry.dart';
import 'interaction_engine.dart';

class RealtimeInspectorOverlay extends StatefulWidget {
  const RealtimeInspectorOverlay({super.key});

  @override
  State<RealtimeInspectorOverlay> createState() => _RealtimeInspectorOverlayState();
}

class _RealtimeInspectorOverlayState extends State<RealtimeInspectorOverlay> {
  bool _isExpanded = false;
  TestCase? _runningTest;
  int _currentStepIndex = -1;
  Offset? _highlightPosition;

  @override
  void initState() {
    super.initState();
    // This is a prototype hack to allow the engine to trigger highlights in the UI
    RealtimeInteractionEngine.instance.onInteraction = (Offset position) {
      if (mounted) {
        setState(() => _highlightPosition = position);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _highlightPosition = null);
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildHighlightRipple(),
        Positioned(
          bottom: 20,
          left: 20,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isExpanded) _buildExpandedMenu(),
                if (_runningTest != null) _buildRunningTestStatus(),
                FloatingActionButton(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  child: Icon(_isExpanded ? Icons.close : Icons.bug_report),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightRipple() {
    if (_highlightPosition == null) return const SizedBox.shrink();

    return Positioned(
      left: _highlightPosition!.dx - 25,
      top: _highlightPosition!.dy - 25,
      child: IgnorePointer(
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 5)
            ],
            border: Border.all(color: Colors.red, width: 3),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 320,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700.withOpacity(0.8), Colors.green.shade500.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Realtime Inspector',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: RealtimeTesterRegistry.instance.tests.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.green.withOpacity(0.1)),
                  itemBuilder: (context, index) {
                    final test = RealtimeTesterRegistry.instance.tests[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(test.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${test.steps.length} steps', style: TextStyle(color: Colors.black.withOpacity(0.5))),
                      trailing: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.green),
                      ),
                      onTap: () => _runTest(test),
                    );
                  },
                ),
              ),
              if (RealtimeTesterRegistry.instance.tests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('No tests registered.', style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunningTestStatus() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 320,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _runningTest!.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStepIndex + 1) / _runningTest!.steps.length,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  color: Colors.green,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
              ..._runningTest!.steps.map((step) => _buildStepRow(step)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(TestStep step) {
    IconData icon;
    Color color;
    switch (step.status) {
      case TestStatus.pending:
        icon = Icons.circle_outlined;
        color = Colors.grey;
        break;
      case TestStatus.running:
        icon = Icons.sync;
        color = Colors.green;
        break;
      case TestStatus.passed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TestStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.description,
              style: TextStyle(
                color: step.status == TestStatus.running ? Colors.green : Colors.black87,
                fontWeight: step.status == TestStatus.running ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runTest(TestCase test) async {
    setState(() {
      _runningTest = test;
      _currentStepIndex = 0;
      _isExpanded = false;
      _highlightPosition = null;
      for (var s in test.steps) {
        s.status = TestStatus.pending;
      }
    });

    for (int i = 0; i < test.steps.length; i++) {
      if (!mounted) break;
      setState(() {
        _currentStepIndex = i;
        test.steps[i].status = TestStatus.running;
      });
      
      try {
        await test.steps[i].action();
        if (mounted) {
          setState(() {
            test.steps[i].status = TestStatus.passed;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            test.steps[i].status = TestStatus.failed;
          });
        }
        break;
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _runningTest = null;
        _currentStepIndex = -1;
        _highlightPosition = null;
      });
    }
  }
}
