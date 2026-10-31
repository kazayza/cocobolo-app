import 'package:flutter/material.dart';

/// Global navigator key shared by MaterialApp + notification deep links.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Shared route observer — lets long-lived screens (e.g. Home) react when
/// a route pushed on top of them is popped (RouteAware.didPopNext).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
