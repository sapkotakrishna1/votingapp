// Stub for mobile/desktop (does nothing)
class PlatformViewRegistry {
  void registerViewFactory(String viewType, dynamic viewFactory) {}
}

PlatformViewRegistry get platformViewRegistry => PlatformViewRegistry();
