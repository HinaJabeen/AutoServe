import 'package:customer/core/router/app_router.dart';
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
      expect(find.text('Emerald Motors').hitTestable(), findsOneWidget);
      expect(find.text('Send Inquiry'), findsOneWidget);
      expect(find.text('Book Test Drive'), findsOneWidget);
      // The bar should hug its buttons, not stretch over the screen.
      final bar = tester.getRect(find.byType(OutlinedButton));
      expect(bar.top, greaterThan(600));
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
