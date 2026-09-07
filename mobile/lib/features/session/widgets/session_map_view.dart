import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/session_timeline.dart';
import '../../../services/session_gps_service.dart';

class SessionMapView extends StatefulWidget {
  const SessionMapView({
    super.key,
    required this.route,
    this.current,
    this.height = 200,
    this.interactive = false,
    this.showGpsBadge = false,
    this.distanceMeters,
  });

  final List<RoutePoint> route;
  final Position? current;
  final double height;
  final bool interactive;
  final bool showGpsBadge;
  final double? distanceMeters;

  @override
  State<SessionMapView> createState() => _SessionMapViewState();
}

class _SessionMapViewState extends State<SessionMapView> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitRoute(List<LatLng> points) {
    if (points.length < 2 || widget.showGpsBadge) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(44),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.route.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = _center(points, widget.current);
    final showEnd = !widget.showGpsBadge && points.length >= 2;
    final endPoint = showEnd ? points.last : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                onMapReady: () => _fitRoute(points),
                interactionOptions: InteractionOptions(
                  flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mobile',
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: AppColors.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (points.isNotEmpty)
                      _marker(
                        point: points.first,
                        color: const Color(0xFF81C784),
                        label: 'A',
                        size: 32,
                      ),
                    if (endPoint != null)
                      _marker(
                        point: endPoint,
                        color: AppColors.primary,
                        label: 'B',
                        size: 32,
                      ),
                    if (widget.showGpsBadge && widget.current != null)
                      Marker(
                        point: LatLng(widget.current!.latitude, widget.current!.longitude),
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (widget.showGpsBadge)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF81C784),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'GPS aktif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.distanceMeters != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatDistance(widget.distanceMeters!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (points.length >= 2 && !widget.showGpsBadge)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapLegendDot(color: Color(0xFF81C784), text: 'Awal'),
                      SizedBox(width: 10),
                      _MapLegendDot(color: AppColors.primary, text: 'Akhir'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _marker({
    required LatLng point,
    required Color color,
    required String label,
    required double size,
  }) {
    return Marker(
      point: point,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  LatLng _center(List<LatLng> points, Position? pos) {
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    if (points.length >= 2) {
      return LatLng(
        (points.first.latitude + points.last.latitude) / 2,
        (points.first.longitude + points.last.longitude) / 2,
      );
    }
    if (points.isNotEmpty) return points.last;
    return const LatLng(-6.2, 106.8);
  }
}

class _MapLegendDot extends StatelessWidget {
  const _MapLegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
