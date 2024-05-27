// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Example creating a modal bottom sheet in an app with mixed transitions. This
/// example is mostly a POC for route transition mixing, and the actual example
/// for routes will be simpler.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bug: Stealing other`s transitions',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(
        title: 'Zoom Transition',
      ),
    );
  }
}

enum PageLevel {
  first,
  second,
  third,
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({
    super.key,
    required this.title,
    this.pageLevel = PageLevel.first,
  });

  final String title;

  final PageLevel pageLevel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            switch (pageLevel) {
              PageLevel.first => TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MBSPageRoute<void>(
                        color: Colors.red,
                        pageBuilder: (BuildContext buildContext) {
                          return const MyHomePage(
                            title: 'MBS 1',
                            pageLevel: PageLevel.second,
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Push first route'),
                ),
              PageLevel.second => TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MBSPageRoute<void>(
                        color: Colors.green,
                        pageBuilder: (BuildContext buildContext) {
                          return const MyHomePage(
                            title: 'MBS 2',
                            pageLevel: PageLevel.third,
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Push second route'),
                ),
              PageLevel.third => TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true)
                      ..pop()
                      ..pop();
                  },
                  child: const Text('Pop all'),
                ),
            },
          ],
        ),
      ),
    );
  }
}

// Offset from offscreen below to stopping below the top of the screen.
final Animatable<Offset> _kBottomUpTween = Tween<Offset>(
  begin: const Offset(0.0, 1.0),
  end: const Offset(0.0, 0.1),
);

final Animatable<Offset> _kFullBottomUpTween = Tween<Offset>(
  begin: const Offset(0.0, 1.0),
  end: Offset.zero,
);

// Offset from offscreen below to stopping below the top of the screen.
final Animatable<Offset> _kMidUpTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(0.0, -0.05),
);

class MBSTransition extends StatelessWidget {
  MBSTransition({
    super.key,
    required Animation<double> primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
  })  : _primaryPositionAnimation = CurvedAnimation(
          parent: primaryRouteAnimation,
          curve: Curves.fastEaseInToSlowEaseOut,
          reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
        ).drive(_kBottomUpTween),
        _secondaryPositionAnimation = CurvedAnimation(
          parent: secondaryRouteAnimation,
          curve: Curves.linearToEaseOut,
          reverseCurve: Curves.easeInToLinear,
        ).drive(_kMidUpTween),
        _primaryPositionAnimationMBS = CurvedAnimation(
          parent: primaryRouteAnimation,
          curve: Curves.linearToEaseOut,
          reverseCurve: Curves.easeInToLinear,
        ).drive(_kFullBottomUpTween);

  // When this page is coming in to cover another page.
  final Animation<Offset> _primaryPositionAnimation;

  // When this page is coming in to cover another MBS. Because it's nested within
  // a MBS, a 0 y offset is not the top of the physical screen, but the top of
  // the previous MBS.
  final Animation<Offset> _primaryPositionAnimationMBS;

  // When this page is being covered by another MBS. It slides up slightly to
  // look like it's joining the stack of previous routes.
  final Animation<Offset> _secondaryPositionAnimation;

  /// Animation
  final Animation<double> secondaryRouteAnimation;

  /// The widget below this widget in the tree.
  final Widget child;

  /// The primary delegated transition. Will slide a non MBS page down.
  static Widget delegateTransition(BuildContext context, Widget? child,
      Animation<double> secondaryAnimation, Color color) {
    const Offset begin = Offset.zero;
    const Offset end = Offset(0.0, 0.05);
    const Curve curve = Curves.ease;

    final Animatable<Offset> tween =
        Tween<Offset>(begin: begin, end: end).chain(CurveTween(curve: curve));

    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, child) {
        return ColoredBox(
          color: color.withOpacity(secondaryAnimation.value),
          child: child,
        );
      },
      child: SlideTransition(
        position: secondaryAnimation.drive(tween),
        child: child,
      ),
    );
  }

  /// The secondary delegated transition. Will slide a MBS page up.
  static Widget secondaryDelegateTransition(BuildContext context, Widget? child,
      Animation<double> secondaryAnimation) {
    const Offset begin = Offset.zero;
    const Offset end = Offset(0.0, -0.05);
    const Curve curve = Curves.ease;

    final Animatable<Offset> tween =
        Tween<Offset>(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: secondaryAnimation.drive(tween),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    final bool topLevelMBS = Navigator.of(context).widget is! MBSNavigator;
    return DelegatedTransition(
      context: context,
      animation: secondaryRouteAnimation,
      builder: (BuildContext context, Widget? child) {
        return SlideTransition(
          position: _secondaryPositionAnimation,
          textDirection: textDirection,
          transformHitTests: false,
          child: child,
        );
      },
      child: SlideTransition(
          position: topLevelMBS
              ? _primaryPositionAnimation
              : _primaryPositionAnimationMBS,
          textDirection: textDirection,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: child,
          )),
    );
  }
}

class MBSPageRoute<T> extends PageRoute<T>
    with MBSRouteTransitionMixin<T>, FlexibleTransitionRouteMixin<T> {
  /// Creates a page route for use in an iOS designed app.
  final Color color;
  MBSPageRoute({
    required this.pageBuilder,
    required this.color,
  }) : _delegatedTransition = ((BuildContext context, Widget? child,
            Animation<double> animation) {
          return MBSTransition.delegateTransition(
              context, child, animation, color);
        });

  final WidgetBuilder pageBuilder;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegatedTransition;

  final DelegatedTransitionBuilder _delegatedTransition;

  @override
  Widget buildContent(BuildContext context) => pageBuilder(context);

  @override
  Color? get barrierColor => const Color(0x20000000);

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => 'Stacked card appearance for modal bottom sheet';

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;
}

mixin MBSRouteTransitionMixin<T> on PageRoute<T> {
  /// Builds the primary contents of the route.
  @protected
  Widget buildContent(BuildContext context);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return buildContent(context);
  }

  static Widget buildPageTransitions<T>(
    ModalRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return MBSTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      child: child,
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return nextRoute is MBSRouteTransitionMixin;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return buildPageTransitions<T>(
        this, context, animation, secondaryAnimation, child);
  }
}

class MBSNavigator extends Navigator {
  const MBSNavigator({
    super.key,
    super.pages,
    super.onPopPage,
    super.initialRoute,
    super.onGenerateInitialRoutes,
    super.onGenerateRoute,
    super.onUnknownRoute,
    super.transitionDelegate,
    super.reportsRouteUpdateToEngine,
    super.clipBehavior,
    super.observers,
    super.requestFocus,
    super.restorationScopeId,
    super.routeTraversalEdgeBehavior,
    required this.parentNavigatorContext,
  });

  final BuildContext parentNavigatorContext;

  void popMBS() {
    Navigator.of(parentNavigatorContext).pop();
  }

  static NavigatorState? of(
    BuildContext context, {
    bool rootNavigator = false,
  }) {
    // Handles the case where the input context is a navigator element.
    NavigatorState? navigator;
    if (context is StatefulElement && context.state is NavigatorState) {
      navigator = context.state as NavigatorState;
    }
    if (rootNavigator) {
      navigator =
          context.findRootAncestorStateOfType<NavigatorState>() ?? navigator;
    } else {
      navigator =
          navigator ?? context.findAncestorStateOfType<NavigatorState>();
    }
    if (navigator?.widget is! MBSNavigator) {
      return null;
    }

    return navigator;
  }
}
