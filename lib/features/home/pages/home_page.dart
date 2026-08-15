import 'package:features_tour/features_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../auth/presentation/cubit/auth_state.dart';
import '../../bus_search/domain/repositories/trip_repository.dart';
import '../../bus_search/models/bus_search_params.dart';
import '../../bus_search/models/popular_route_model.dart';
import '../../bus_search/models/special_offer_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _tourController = FeaturesTourController('ClientHome');

  DateTime _departureDate = DateTime.now();
  String _fromCity = 'From';
  String _toCity = 'To';

  List<PopularRouteModel> _popularRoutes = [];
  List<SpecialOfferModel> _specialOffers = [];
  bool _tripsLoading = true;
  bool _offersLoading = true;
  bool _isRefreshing = false;

  static const List<String> _cities = [
    'Accra',
    'Kumasi',
    'Tamale',
    'Sekondi-Takoradi',
    'Cape Coast',
    'Koforidua',
    'Sunyani',
    'Bolgatanga',
    'Wa',
    'Ho',
    'Techiman',
    'Goaso',
    'Nalerigu',
    'Dambai',
    'Damongo',
    'Sefwi Wiawso',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPopularRoutes();
      _loadSpecialOffers();
    });
    _tourController.start(context);
  }

  Widget _tourTip(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
    );
  }

  Future<void> _loadSpecialOffers() async {
    try {
      final repo = RepositoryProvider.of<TripRepository>(context);
      final offers = await repo.getSpecialOffers();
      if (mounted) setState(() { _specialOffers = offers; _offersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _offersLoading = false);
    }
  }

  Future<void> _loadPopularRoutes() async {
    try {
      final repo = RepositoryProvider.of<TripRepository>(context);
      final routes = await repo.getPopularRoutes();
      if (mounted) {
        setState(() {
          _popularRoutes = routes;
          _tripsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tripsLoading = false);
    }
  }

  Future<void> _refreshHome() async {
    setState(() => _isRefreshing = true);
    await Future.wait([_loadPopularRoutes(), _loadSpecialOffers()]);
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _departureDate = picked);
  }

  Future<void> _pickCity({required bool isFrom}) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(
        title: isFrom ? 'Select Departure City' : 'Select Destination City',
        cities: _cities,
      ),
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromCity = selected;
        } else {
          _toCity = selected;
        }
      });
    }
  }

  void _swapCities() {
    setState(() {
      final temp = _fromCity;
      _fromCity = _toCity;
      _toCity = temp;
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, isDark, tt, cs),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshHome,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: FeaturesTour(
                        controller: _tourController,
                        index: 0,
                        introduce: _tourTip(
                          'Search buses by picking your travel dates and cities, right from here.',
                        ),
                        child: _buildSearchCard(context, isDark, tt, cs),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FeaturesTour(
                      controller: _tourController,
                      index: 1,
                      introduce: _tourTip(
                        'See the most booked routes at a glance.',
                      ),
                      child: _buildSectionHeader(
                        context, tt, 'Popular Routes', 'View All',
                        onActionTap: () => context.push(AppRoutes.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPopularRoutes(context, isDark, tt, cs),
                    const SizedBox(height: 24),
                    FeaturesTour(
                      controller: _tourController,
                      index: 2,
                      introduce: _tourTip(
                        "Don't miss out on limited-time discounts.",
                      ),
                      child: _buildSectionHeader(
                        context,
                        tt,
                        'Special Offers',
                        'Limited Time',
                        accentLabel: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSpecialOffers(context, tt),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkSurface, AppColors.darkBackground]
              : [const Color(0xFFE0EAFF), AppColors.lightBackground],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        20,
      ),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final user =
              authState is AuthAuthenticated ? authState.user : null;
          final firstName = user != null && user.fullName.isNotEmpty
              ? user.fullName.trim().split(RegExp(r'\s+')).first
              : null;

          return Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName != null
                          ? 'Good to see you, $firstName!'
                          : 'Welcome Back!',
                      style:
                          tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ready for your next adventure?',
                      style: tt.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isRefreshing ? null : _refreshHome,
                icon: _isRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.lightOnSurface,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.lightOnSurface,
                      ),
                tooltip: 'Refresh',
              ),
              FeaturesTour(
                controller: _tourController,
                index: 3,
                introduce: _tourTip(
                  'Switch between light and dark mode anytime.',
                ),
                child: IconButton(
                  onPressed: () {
                    context.read<ThemeBloc>().add(const ThemeToggled());
                  },
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                  tooltip: 'Toggle Theme',
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.notifications_outlined,
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Search Card ─────────────────────────────────────────────────────────────

  Widget _buildSearchCard(
    BuildContext context,
    bool isDark,
    TextTheme tt,
    ColorScheme cs,
  ) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor =
        isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final variantColor = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final subtextColor = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Search Buses',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Departure date
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: variantColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Departure',
                        style: tt.bodySmall?.copyWith(
                          color: subtextColor,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _formatDate(_departureDate),
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // From / Swap / To
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickCity(isFrom: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: variantColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_checked,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _fromCity,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: _fromCity == 'From'
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: _fromCity == 'From' ? subtextColor : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _swapCities,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.swap_horiz_rounded,
                      color: cs.primary, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickCity(isFrom: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: variantColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _toCity,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: _toCity == 'To'
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: _toCity == 'To' ? subtextColor : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_fromCity == 'From' || _toCity == 'To') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please select departure and destination cities'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                context.push(
                  AppRoutes.busResults,
                  extra: BusSearchParams(
                    from: _fromCity,
                    to: _toCity,
                    date: _departureDate,
                  ),
                );
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search Buses'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    BuildContext context,
    TextTheme tt,
    String title,
    String action, {
    bool accentLabel = false,
    VoidCallback? onActionTap,
  }) {
    final isRoutes = title == 'Popular Routes';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isRoutes
                    ? Icons.trending_up_rounded
                    : Icons.local_offer_rounded,
                size: 18,
                color: isRoutes ? AppColors.primary : AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          GestureDetector(
            onTap: onActionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: accentLabel
                  ? BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Text(
                action,
                style: tt.bodySmall?.copyWith(
                  color: accentLabel ? AppColors.secondary : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Popular Routes ──────────────────────────────────────────────────────────

  Widget _buildPopularRoutes(
    BuildContext context,
    bool isDark,
    TextTheme tt,
    ColorScheme cs,
  ) {
    if (_tripsLoading) {
      return SizedBox(
        height: 130,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => _SkeletonRouteCard(isDark: isDark),
        ),
      );
    }

    if (_popularRoutes.isEmpty) {
      return SizedBox(
        height: 130,
        child: Center(
          child: Text(
            'No routes available right now.',
            style: tt.bodySmall?.copyWith(color: AppColors.grey400),
          ),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _popularRoutes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final route = _popularRoutes[i];
          return GestureDetector(
            onTap: () => context.push(
              AppRoutes.busResults,
              extra: BusSearchParams(
                from: route.origin,
                to: route.destination,
                date: _departureDate,
              ),
            ),
            child: _PopularRouteCard(
              route: route,
              isDark: isDark,
              tt: tt,
              cs: cs,
            ),
          );
        },
      ),
    );
  }

  // ── Special Offers ──────────────────────────────────────────────────────────

  Widget _buildSpecialOffers(BuildContext context, TextTheme tt) {
    if (_offersLoading) {
      return SizedBox(
        height: 148,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => _SkeletonOfferCard(),
        ),
      );
    }

    if (_specialOffers.isEmpty) {
      return SizedBox(
        height: 148,
        child: Center(
          child: Text(
            'No special offers right now',
            style: tt.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 148,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _specialOffers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final offer = _specialOffers[i];
          // Offers with no linked route/trip apply to all trips — navigate
          // with empty from/to so the results page lists every upcoming trip.
          final origin = offer.routeOrigin ?? '';
          final destination = offer.routeDestination ?? '';
          // For trip-specific offers use the trip's departure date so the search
          // lands on the right day; fall back to today for route-wide offers.
          final searchDate = offer.tripDepartureTime != null
              ? DateUtils.dateOnly(offer.tripDepartureTime!)
              : DateTime.now();
          return _OfferCard(
            offer: offer,
            tt: tt,
            onTap: () => context.push(
              AppRoutes.busResults,
              extra: BusSearchParams(
                from: origin,
                to: destination,
                date: searchDate,
                offerId: offer.id,
                offerDiscountPercent: offer.discountPercent,
                offerTitle: offer.title,
                tripId: offer.tripId,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Skeleton card (loading placeholder) ──────────────────────────────────────

class _SkeletonRouteCard extends StatelessWidget {
  final bool isDark;

  const _SkeletonRouteCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final borderColor =
        isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              height: 14, width: 80, color: shimmerColor,
              margin: const EdgeInsets.only(bottom: 10)),
          Container(
              height: 14, width: 120, color: shimmerColor,
              margin: const EdgeInsets.only(bottom: 8)),
          Container(height: 20, width: 60, color: shimmerColor),
          const Spacer(),
          Container(height: 12, width: 70, color: shimmerColor),
        ],
      ),
    );
  }
}

// ── Popular route card (from Route table) ────────────────────────────────────

class _PopularRouteCard extends StatelessWidget {
  final PopularRouteModel route;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;

  const _PopularRouteCard({
    required this.route,
    required this.isDark,
    required this.tt,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.directions_bus_rounded, size: 18, color: cs.primary),
              if (route.bookingCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 10, color: Colors.orange),
                      const SizedBox(width: 2),
                      Text(
                        '${route.bookingCount}',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            route.origin,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.grey500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            route.destination,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GH₵ ${route.baseFare.toStringAsFixed(0)}',
                style: tt.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (route.distanceKm != null)
                Text(
                  '${route.distanceKm!.toStringAsFixed(0)} km',
                  style: tt.bodySmall
                      ?.copyWith(color: AppColors.grey400, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Offer Card ───────────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  final value = int.tryParse(clean, radix: 16) ?? 0xFF6366F1;
  return Color(value | 0xFF000000);
}

IconData _iconNameToData(String name) {
  switch (name) {
    case 'explore': return Icons.explore_rounded;
    case 'school': return Icons.school_rounded;
    case 'weekend': return Icons.weekend_rounded;
    case 'directions_bus': return Icons.directions_bus_rounded;
    case 'flight': return Icons.flight_rounded;
    case 'star': return Icons.star_rounded;
    case 'percent': return Icons.percent_rounded;
    case 'bolt': return Icons.bolt_rounded;
    case 'card_giftcard': return Icons.card_giftcard_rounded;
    case 'discount': return Icons.discount_rounded;
    default: return Icons.local_offer_rounded;
  }
}

class _OfferCard extends StatelessWidget {
  final SpecialOfferModel offer;
  final TextTheme tt;
  final VoidCallback? onTap;

  const _OfferCard({required this.offer, required this.tt, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorStart = _hexToColor(offer.colorHexStart);
    final colorEnd = _hexToColor(offer.colorHexEnd);
    final icon = _iconNameToData(offer.iconName);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorStart, colorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    offer.badgeText,
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
              ],
            ),
            const Spacer(),
            Text(
              offer.title,
              style: tt.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              offer.description,
              style: tt.bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${offer.discountPercent.toInt()}% OFF',
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onTap != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonOfferCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shimmer,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── City Picker Bottom Sheet ──────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final String title;
  final List<String> cities;

  const _CityPickerSheet({required this.title, required this.cities});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.white;

    final trimmed = _query.trim();
    final filtered = widget.cities
        .where((c) => c.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();

    // Show "Use '[input]'" option when the typed text isn't already an exact
    // match in the list (so users can pick cities not in the predefined set).
    final showCustom = trimmed.isNotEmpty &&
        !widget.cities
            .any((c) => c.toLowerCase() == trimmed.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkOutline : AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.radio_button_checked,
                      color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            // Search / type field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search or type a city name…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: trimmed.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // "Use '[custom input]'" row — shown when typing a city
                  // not already in the predefined list
                  if (showCustom)
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add_location_alt_rounded,
                            color: cs.primary, size: 18),
                      ),
                      title: Text(
                        'Use "$trimmed"',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      subtitle: Text(
                        'Not in the predefined list',
                        style: tt.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.lightOnSurfaceVariant),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: cs.primary),
                      onTap: () => Navigator.pop(context, trimmed),
                    ),
                  if (showCustom && filtered.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Text(
                        'Suggestions',
                        style: tt.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.lightOnSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // Predefined list (filtered by query)
                  ...filtered.map(
                    (city) => ListTile(
                      leading: Icon(Icons.location_city_rounded,
                          color: cs.primary, size: 20),
                      title: Text(city),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, city),
                    ),
                  ),
                  // Empty state when nothing matches and no custom input
                  if (filtered.isEmpty && !showCustom)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No cities found.\nType any city name above.',
                          textAlign: TextAlign.center,
                          style: tt.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.grey400),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
