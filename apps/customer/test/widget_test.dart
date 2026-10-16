import 'package:customer/core/router/app_router.dart';
import 'package:customer/core/cnic.dart';
import 'package:customer/core/widgets/inspection_badge.dart';
import 'package:customer/features/compare/presentation/compare_screen.dart';
import 'package:customer/features/compare/providers/compare_providers.dart';
import 'package:customer/features/dealer_application/models/dealer_application.dart';
import 'package:customer/features/dealer_application/presentation/dealer_status_card.dart';
import 'package:customer/features/dealer_application/providers/dealer_application_providers.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/core/validators.dart';
import 'package:customer/features/auth/models/customer_profile.dart';
import 'package:customer/features/auth/presentation/login_screen.dart';
import 'package:customer/features/auth/providers/auth_providers.dart';
import 'package:customer/features/auth/services/auth_service.dart';
import 'package:customer/features/details/presentation/vehicle_detail_screen.dart';
import 'package:customer/features/details/providers/vehicle_detail_providers.dart';
import 'package:customer/features/details/services/vehicle_detail_service.dart';
import 'package:customer/features/discovery/services/local_swipe_store.dart';
import 'package:customer/features/filters/models/vehicle_filters.dart';
import 'package:customer/features/filters/providers/filter_providers.dart';
import 'package:customer/features/leads/services/lead_service.dart';
import 'package:customer/features/search/providers/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

CarModel _car({
  String id = 'c1',
  String dealerId = 'd1',
  String make = 'Toyota',
  String model = 'Corolla',
}) {
  final now = DateTime(2026, 1, 1);
  return CarModel(
    id: id,
    dealerId: dealerId,
    make: make,
    model: model,
    year: 2022,
    price: 4500000,
    status: 'available',
    createdAt: now,
    updatedAt: now,
  );
}

/// AuthService whose sign-in/sign-up always throw [error].
class _FailingAuthService implements AuthService {
  _FailingAuthService(this.error);
  final Object error;

  @override
  Future<bool> isSelfRegisteredDealer(String userId) async => false;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<User?> signIn({required String email, required String password}) =>
      Future.error(error);

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) =>
      Future.error(error);

  @override
  Future<void> signOut() async {}

  @override
  Future<CustomerProfile?> fetchProfile(User user) async => null;
}

ProviderContainer _containerFailingWith(Object error) {
  final container = ProviderContainer(overrides: [
    authServiceProvider.overrideWithValue(_FailingAuthService(error)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AuthNotifier failures', () {
    const emailLimit = AuthException('email rate limit exceeded',
        statusCode: '429', code: 'over_email_send_rate_limit');
    const requestLimit = AuthException('Request rate limit reached',
        statusCode: '429', code: 'over_request_rate_limit');

    test('sign-in rate limit → SnackBar message, loading reset', () async {
      final container = _containerFailingWith(requestLimit);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a@b.co', password: 'emerald2026');

      final state = container.read(authProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.snackMessage, rateLimitMessage);
      expect(state.snackMessage, startsWith('Rate limit reached.'));
      expect(state.errorMessage, isNull);
    });

    test('sign-up rate limit → SnackBar message, loading reset', () async {
      final container = _containerFailingWith(emailLimit);
      final result = await container.read(authProvider.notifier).signUp(
            fullName: 'Sara Khan',
            phone: '+92 300 1234567',
            email: 'a@b.co',
            password: 'emerald2026',
          );

      final state = container.read(authProvider);
      expect(result, SignUpResult.failed);
      expect(state.isSubmitting, isFalse);
      expect(state.snackMessage, rateLimitMessage);
      expect(state.errorMessage, isNull);
    });

    test('other auth errors keep their own message in the banner', () async {
      final container = _containerFailingWith(const AuthException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials'));
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a@b.co', password: 'wrong');

      final state = container.read(authProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, 'Incorrect email or password.');
      expect(state.snackMessage, isNull);
    });

    test('a non-auth error still resets the loading state', () async {
      final container = _containerFailingWith(StateError('boom'));
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a@b.co', password: 'emerald2026');

      final state = container.read(authProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test('rate limits are recognised with or without an error code', () {
      expect(isRateLimitError(emailLimit), isTrue);
      expect(isRateLimitError(const AuthException('Too many requests')), isTrue);
      expect(
        isRateLimitError(const AuthException(
            'For security purposes, you can only request this after 42 seconds.')),
        isTrue,
      );
      expect(
        isRateLimitError(const AuthException('Invalid login credentials',
            code: 'invalid_credentials')),
        isFalse,
      );
    });
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets(
        'login: rate limit shows the SnackBar and the button stops loading '
        '(${theme.brightness.name})', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_FailingAuthService(
              const AuthException('Request rate limit reached',
                  statusCode: '429', code: 'over_request_rate_limit'))),
        ],
        child: MaterialApp(theme: theme, home: const LoginScreen()),
      ));

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(1), 'emerald2026');
      await tester.tap(find.text('Sign in'));
      await tester.pump(); // request fails
      await tester.pump(const Duration(milliseconds: 800)); // SnackBar slides in

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(rateLimitMessage), findsOneWidget);
      // Back to an idle, usable form: label visible again, no spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('Validators', () {
    test('email', () {
      expect(Validators.email('sara@example.com'), isNull);
      expect(Validators.email('  sara@example.com '), isNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('sara@example'), isNotNull);
      expect(Validators.email('sara example.com'), isNotNull);
    });

    test('phone', () {
      expect(Validators.phone('+92 300 1234567'), isNull);
      expect(Validators.phone('(021) 555-1234'), isNull);
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('call me maybe'), isNotNull);
    });

    test('newPassword', () {
      expect(Validators.newPassword('emerald2026'), isNull);
      expect(Validators.newPassword('short1'), isNotNull);
      expect(Validators.newPassword('lettersonly'), isNotNull);
      expect(Validators.newPassword('1234567890'), isNotNull);
    });
  });

  group('CustomerProfile', () {
    CustomerProfile parse(Object? role) => CustomerProfile.fromJson(
          {'id': 'u1', 'full_name': 'Sara Khan', 'phone': null, 'role': role},
          email: 'sara@example.com',
        );

    test('only an explicit customer role is let in', () {
      expect(parse('customer').isCustomer, isTrue);
      expect(parse('dealer').isCustomer, isFalse);
      expect(parse('admin').isCustomer, isFalse);
      // Unknown / missing roles fail closed.
      expect(parse('something_new').isCustomer, isFalse);
      expect(parse(null).isCustomer, isFalse);
    });

    test('initials', () {
      expect(parse('customer').initials, 'SK');
      expect(
        const CustomerProfile(
          id: 'u2',
          email: 'zed@example.com',
          fullName: '',
          role: ProfileRole.customer,
        ).initials,
        'Z',
      );
    });
  });

  group('friendlyAuthError', () {
    test('maps the sign-up edge cases', () {
      expect(
        friendlyAuthError(const AuthException('User already registered',
            statusCode: '422', code: 'user_already_exists')),
        emailAlreadyRegisteredMessage,
      );
      expect(
        friendlyAuthError(AuthWeakPasswordException(
            message: 'weak', statusCode: '422', reasons: const ['length'])),
        contains('too weak'),
      );
      expect(
        friendlyAuthError(const AuthException('Invalid login credentials',
            statusCode: '400', code: 'invalid_credentials')),
        'Incorrect email or password.',
      );
      // No error code — falls back to matching on the message.
      expect(
        friendlyAuthError(const AuthException('User already registered')),
        emailAlreadyRegisteredMessage,
      );
    });
  });

  group('VehicleFilters dealer filter', () {
    test('matches only the targeted dealer, and counts as active', () {
      const filters = VehicleFilters(dealerId: 'd1', dealerName: 'Al-Noor Motors');
      expect(filters.isActive, isTrue);
      expect(filters.matches(_car(dealerId: 'd1')), isTrue);
      expect(filters.matches(_car(dealerId: 'd2')), isFalse);
    });

    test('clearing drops the dealer filter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(vehicleFiltersProvider.notifier);

      notifier.filterByDealer('d1', 'Al-Noor Motors');
      expect(container.read(vehicleFiltersProvider).dealerId, 'd1');
      notifier.clear();
      expect(container.read(vehicleFiltersProvider).isActive, isFalse);
    });
  });

  group('DebouncedSearchQueryNotifier', () {
    test('clearing the field drops the query immediately, no wait', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(debouncedSearchQueryProvider.notifier);

      notifier.onQueryChanged('toyota');
      notifier.onQueryChanged(''); // user deleted everything before the timer fired
      expect(container.read(debouncedSearchQueryProvider), '');
    });

    test('only the trimmed query is published, after the debounce window', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // autoDispose providers tear themselves down (cancelling the pending
      // Timer) as soon as nothing is listening — keep this one alive for
      // the length of the test, same as a watching widget would.
      container.listen(debouncedSearchQueryProvider, (_, _) {});
      final notifier = container.read(debouncedSearchQueryProvider.notifier);

      notifier.onQueryChanged('  corolla  ');
      expect(container.read(debouncedSearchQueryProvider), isEmpty,
          reason: 'not yet debounced');
      await Future.delayed(const Duration(milliseconds: 500));
      expect(container.read(debouncedSearchQueryProvider), 'corolla');
    });

    test('a short query never reaches the search service', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(debouncedSearchQueryProvider.notifier).onQueryChanged('a');
      await Future.delayed(const Duration(milliseconds: 500));

      final results = await container.read(searchResultsProvider.future);
      expect(results.isEmpty, isTrue);
    });
  });

  group('AppRoutes.withFrom', () {
    test('keeps in-app destinations', () {
      expect(AppRoutes.withFrom(AppRoutes.login, '/vehicle/abc'),
          '/login?from=%2Fvehicle%2Fabc');
    });

    test('drops anything that is not a plain in-app path', () {
      expect(AppRoutes.withFrom(AppRoutes.login, null), '/login');
      expect(AppRoutes.withFrom(AppRoutes.login, '/'), '/login');
      expect(AppRoutes.withFrom(AppRoutes.login, '/login'), '/login');
      expect(AppRoutes.withFrom(AppRoutes.login, 'https://evil.example'),
          '/login');
      expect(AppRoutes.withFrom(AppRoutes.login, '//evil.example'), '/login');
    });
  });

  group('Dealer application', () {
    test('CNIC is auto-masked and validated', () {
      expect(CnicInputFormatter.format('3520212345671'), '35202-1234567-1');
      expect(CnicInputFormatter.format('35202 1234'), '35202-1234');
      expect(CnicInputFormatter.format('35202123456719999'), '35202-1234567-1');
      expect(validateCnic('35202-1234567-1'), isNull);
      expect(validateCnic('35202-123456-1'), isNotNull);
      expect(validateCnic(''), isNotNull);
    });

    test('a pending application with its private verification row parses', () {
      final app = DealerApplication.fromRow({
        'id': 'd1', 'name': 'Capital Motors', 'city': 'Islamabad', 'status': 'rejected',
        'contact_phone': '+923001234567', 'rejection_reason': 'Unclear facade photo',
        'submitted_at': '2026-10-15T09:00:00Z',
        'dealer_verifications': {
          'owner_full_name': 'Hina Jabeen', 'owner_cnic': '35202-1234567-1',
          'cnic_front_url': 'u1/cnic_front_1.jpg',
          'initial_inventory_info': {'expected_stock_size': '10-30', 'primary_makes': ['Toyota']},
        },
      });
      expect(app.status, ApplicationStatus.rejected);
      expect(app.rejectionReason, 'Unclear facade photo');
      expect(app.ownerCnic, '35202-1234567-1');
      expect(app.cnicFrontPath, 'u1/cnic_front_1.jpg');
      expect(app.inventoryInfo['primary_makes'], ['Toyota']);
    });

    test('submit params match the RPC and omit an empty sample vehicle', () {
      const draft = DealerApplicationDraft(
        ownerFullName: 'Hina Jabeen', ownerCnic: '35202-1234567-1', ownerPhone: '+923001234567',
        showroomName: 'Capital Motors', city: 'Islamabad', address: 'Plot 4, Blue Area',
        whatsapp: '+923001234567', businessHours: 'Mon-Sat 10-8', ntnNumber: '',
        showroomPhotoPath: 'u/showroom.jpg', cnicFrontPath: 'u/f.jpg', cnicBackPath: 'u/b.jpg',
        businessDocPath: 'u/doc.jpg', expectedStock: '10-30', primaryMakes: ['Toyota', 'Honda'],
      );
      final params = draft.toRpcParams();
      expect(params.keys, containsAll(['p_showroom_name', 'p_owner_cnic', 'p_inventory_info']));
      final inv = params['p_inventory_info']! as Map;
      expect(inv['primary_makes'], ['Toyota', 'Honda']);
      expect(inv.containsKey('sample_vehicle'), isFalse);
    });

    Future<void> pumpCard(WidgetTester tester, DealerApplication? app) async {
      await tester.pumpWidget(ProviderScope(
        // Fresh scope per state — a reused scope keeps its first override.
        key: UniqueKey(),
        overrides: [myDealerApplicationProvider.overrideWith((ref) async => app)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: DealerStatusCard())),
        ),
      ));
      await tester.pumpAndSettle();
    }

    DealerApplication app(String status) => DealerApplication.fromRow({
          'id': 'd1', 'name': 'Capital Motors', 'city': 'Islamabad', 'status': status,
          'rejection_reason': 'Invalid CNIC',
        });

    testWidgets('profile card covers all four application states', (tester) async {
      await pumpCard(tester, null);
      expect(find.text('Register Dealership'), findsOneWidget);

      await pumpCard(tester, app('pending'));
      expect(find.text('Application Under Review'), findsOneWidget);

      await pumpCard(tester, app('rejected'));
      expect(find.text('Application Rejected'), findsOneWidget);
      expect(find.text('Invalid CNIC'), findsOneWidget);
      expect(find.text('Update & Resubmit'), findsOneWidget);

      await pumpCard(tester, app('approved'));
      expect(find.text('Verified Dealer'), findsOneWidget);
      expect(find.text('Open Dealer Portal'), findsOneWidget);
    });

    test('portal URL falls back to the local dashboard when .env has none', () {
      expect(dealerPortalUrl(), 'http://localhost:5000');
    });
  });

  group('Comparison & inspection', () {
    CarModel inspected(String id, {double? score, double price = 4500000}) => CarModel(
          id: id, dealerId: 'd1', make: 'Toyota', model: 'Corolla $id', year: 2022,
          price: price, status: 'available', createdAt: DateTime(2026), updatedAt: DateTime(2026),
          inspectionScore: score,
          inspectionDetails: score == null
              ? const {}
              : const {'engine': 9.0, 'suspension': 8.5, 'body': 'Non-Accidental'},
        );

    test('/compare is registered on the app router', () {
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(_FailingAuthService(Exception('unused'))),
      ]);
      addTearDown(container.dispose);
      final router = container.read(goRouterProvider);

      List<String> paths(List<RouteBase> routes) => [
            for (final r in routes) ...[
              if (r is GoRoute) r.path,
              ...paths(r.routes),
            ],
          ];
      expect(paths(router.configuration.routes), contains(AppRoutes.compare));
    });

    testWidgets('compare screen opened directly still has a back button', (tester) async {
      final container = ProviderContainer(overrides: [
        compareDealersProvider.overrideWith((ref) async => const <String, DealershipModel>{}),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: const CompareScreen()),
      ));
      expect(find.byType(BackButton), findsOneWidget);
    });

    test('the compare tray holds at most 3 cars and toggles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tray = container.read(compareProvider.notifier);
      expect(tray.toggle(inspected('a')), CompareToggleResult.added);
      expect(tray.toggle(inspected('b')), CompareToggleResult.added);
      expect(tray.toggle(inspected('c')), CompareToggleResult.added);
      expect(tray.toggle(inspected('d')), CompareToggleResult.full);
      expect(tray.toggle(inspected('b')), CompareToggleResult.removed);
      expect(container.read(compareProvider).map((c) => c.id), ['a', 'c']);
    });

    testWidgets('badge and inspection report only for inspected cars', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(children: [
            InspectionBadge(car: inspected('x', score: 9.2)),
            InspectionReport(car: inspected('x', score: 9.2)),
            InspectionBadge(car: inspected('y')),
          ]),
        ),
      ));
      expect(find.text('AutoServe Inspected • 9.2/10'), findsOneWidget);
      expect(find.text('Inspection Report'), findsOneWidget);

      await tester.tap(find.text('Inspection Report'));
      await tester.pumpAndSettle();
      expect(find.text('Engine'), findsOneWidget);
      expect(find.text('Suspension'), findsOneWidget);
      expect(find.text('Non-Accidental'), findsOneWidget);
    });

    testWidgets('compare screen lays cars side by side and marks the cheapest', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(overrides: [
        compareDealersProvider.overrideWith((ref) async => const <String, DealershipModel>{}),
      ]);
      addTearDown(container.dispose);
      container.read(compareProvider.notifier)
        ..toggle(inspected('a', score: 9.2, price: 5000000))
        ..toggle(inspected('b', price: 4200000));

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: const CompareScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Compare (2/3)'), findsOneWidget);
      expect(find.text('Toyota'), findsNWidgets(2));
      expect(find.text('9.2 / 10'), findsOneWidget);
      expect(find.text('Not inspected'), findsOneWidget);
      // Best-value star on the cheaper car's price only.
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('WhatsApp'), findsNWidgets(2));
    });
  });

  group('VehicleFilters.copyWith', () {
    test('can clear a field, and keeps the dealer filter', () {
      const base = VehicleFilters(
          make: 'Toyota', model: 'Corolla', fuelType: 'petrol',
          dealerId: 'd1', dealerName: 'Emerald Motors');
      final cleared = base.copyWith(fuelType: () => null);
      expect(cleared.fuelType, isNull);
      expect(cleared.make, 'Toyota');
      expect(cleared.dealerId, 'd1');
      expect(cleared.dealerName, 'Emerald Motors');

      final newMake = base.copyWith(make: () => 'Honda', model: () => null);
      expect(newMake.make, 'Honda');
      expect(newMake.model, isNull);
    });
  });

  group('VehicleDetailScreen', () {
    final dealer = DealershipModel(
      id: 'd1', name: 'Emerald Motors', ownerName: 'Owner', email: 'e@x.co',
      phone: '0300', city: 'Lahore', status: 'approved', createdAt: DateTime(2026),
    );

    Future<void> pumpDetail(WidgetTester tester, Future<VehicleDetail> Function() load) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [vehicleDetailProvider('c1').overrideWith((ref) => load())],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const VehicleDetailScreen(carId: 'c1'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('content is visible above the action bar, not covered by it', (tester) async {
      await pumpDetail(tester, () async => VehicleDetail(car: _car(), dealer: dealer));

      expect(find.text('2022 Toyota Corolla').hitTestable(), findsOneWidget);
      // A car with no spec data still gets the four headline spec tiles
      // (showing "—"), not a gap.
      expect(find.text('Mileage'), findsOneWidget);
      expect(find.text('Gearbox'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));
      await tester.ensureVisible(find.text('Emerald Motors'));
      await tester.pumpAndSettle();
      expect(find.text('Emerald Motors').hitTestable(), findsOneWidget);
      expect(find.text('Send Inquiry'), findsOneWidget);
      expect(find.text('Book Test Drive'), findsOneWidget);
      // The bar should hug its buttons, not stretch over the screen.
      final bar = tester.getRect(find.byType(OutlinedButton));
      expect(bar.top, greaterThan(600));
    });

    testWidgets('dealer card shows hours and a pre-filled WhatsApp button', (tester) async {
      final open = DealershipModel(
        id: 'd1', name: 'Emerald Motors', ownerName: 'Owner', email: 'e@x.co',
        phone: '0300 1234567', city: 'Lahore', status: 'approved',
        createdAt: DateTime(2026), businessHours: 'Mon–Sat 10am–8pm',
      );
      await pumpDetail(tester, () async => VehicleDetail(car: _car(), dealer: open));

      expect(find.text('Mon–Sat 10am–8pm'), findsOneWidget);
      // In the floating action bar; the short label fits phone width and the
      // full wording is the tooltip / accessibility label.
      expect(find.byTooltip('Contact Dealer via WhatsApp'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      // With WhatsApp in the bar, the inquiry form moves to the dealer card.
      expect(find.text('Send an inquiry instead'), findsOneWidget);
      expect(find.text('Send Inquiry'), findsNothing);
    });

    testWidgets('no WhatsApp button when the dealer phone is unusable', (tester) async {
      await pumpDetail(tester, () async => VehicleDetail(car: _car(), dealer: dealer));
      expect(find.byTooltip('Contact Dealer via WhatsApp'), findsNothing);
      // No usable number → the bar offers the inquiry form instead.
      expect(find.text('Send Inquiry'), findsOneWidget);
    });

    testWidgets('a failed fetch shows the error and a retry', (tester) async {
      await pumpDetail(
          tester, () => Future.error(VehicleDetailException('This listing is no longer available.')));

      expect(find.text('This listing is no longer available.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('LocalSwipeStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('one user never sees another user\'s swipes', () async {
      await LocalSwipeStore('user-a').markInterested('c1');
      await LocalSwipeStore('user-a').markPassed('c2');

      expect(await LocalSwipeStore('user-b').loadDecidedIds(), isEmpty);
      expect(await LocalSwipeStore('user-a').loadDecidedIds(), {'c1', 'c2'});
    });

    test('saving again moves a car to newest; unsaving removes it', () async {
      final store = LocalSwipeStore('u');
      await store.markInterested('c1');
      await store.markInterested('c2');
      await store.markInterested('c1');
      expect(await store.loadInterestedIds(), ['c2', 'c1']);

      await store.unmarkInterested('c2');
      expect(await store.loadInterestedIds(), ['c1']);
    });
  });

  group('LeadService', () {
    test('source values stay inside the leads_source_check allow-list', () {
      expect(LeadType.testDrive.source, 'test_drive_request');
      expect(LeadType.inquiry.source, 'inquiry');
    });

    test('notes carry the date, message, and contact email', () {
      final notes = LeadService.buildNotes(
        type: LeadType.testDrive,
        email: 'a@b.co',
        message: '  Mornings please ',
        preferredDate: DateTime(2026, 3, 7),
      );
      expect(notes,
          'Test drive requested for 2026-03-07.\nMessage: Mornings please\nContact email: a@b.co');
    });

    test('a blank message is left out of an inquiry', () {
      final notes = LeadService.buildNotes(
          type: LeadType.inquiry, email: 'a@b.co', message: '   ');
      expect(notes, 'Vehicle inquiry.\nContact email: a@b.co');
    });
  });
}
