# Writing user-flow tests

A **flow** is an ordered list of `TestStep`s that run against the *same live app*,
so state and navigation carry from one step to the next. This is a cookbook of
patterns for the flows a QA tester typically covers. Copy a recipe, swap in your
`Key`s / texts, register it.

> Prerequisite: the app is already integrated (see [INTEGRATION.md](INTEGRATION.md)) —
> wrapped in `AutomationInspectorWrapper`, tests registered in `if (kDebugMode)`,
> and target widgets carry stable `Key`s. For the API reference, see the
> [README](../README.md).

---

## Anatomy of a flow

```dart
AutomationRegistry.instance.registerTest(
  name: 'Login → Dashboard → Profile',
  tags: {'smoke', 'flow'},
  steps: [
    TestStep(description: 'Do something', action: () => /* engine call */),
    TestStep(description: 'Assert the result', action: () => /* Expect.* */),
  ],
);
```

Each step is either an **action** (`AutomationEngine.instance.*`) or an
**assertion** (`Expect.*`). Put an assertion after every transition — it both
waits for the new state and verifies it.

### Golden rules for flows
1. **State persists across steps** — after a tap navigates, the next step is on
   the new screen.
2. **Assert between transitions** — `Expect.visible(...)` on the destination is
   how you check "it moved to X". It auto-waits, so route animations are fine.
3. **Never add `Future.delayed`** — assertions/actions auto-retry.
4. **Reset between flows** — use `beforeEach` so each flow starts from a known
   state; otherwise flows are order-coupled.
5. **Key everything you touch** — keys are your test contract.

```dart
final registry = AutomationRegistry.instance;

// Start every flow logged-out at the root.
registry.beforeEach(() async {
  // e.g. await appResetToLogin();
});
```

---

## Reusable sub-flows (compose, don't repeat)

Extract common sequences into functions that return `List<TestStep>` and spread
them:

```dart
List<TestStep> login({String user = 'tester', String pass = 'secret'}) => [
  TestStep(
    description: 'Enter username',
    action: () => AutomationEngine.instance.enterText(const Key('username_field'), user),
  ),
  TestStep(
    description: 'Enter password',
    action: () => AutomationEngine.instance.enterText(const Key('password_field'), pass),
  ),
  TestStep(
    description: 'Tap Login',
    action: () => AutomationEngine.instance.tap(const Key('login_button')),
  ),
  TestStep(
    description: 'Dashboard is shown',
    action: () => Expect.visible(find.byText('Dashboard')),
  ),
];

registry.registerTest(name: 'View profile', steps: [
  ...login(),
  TestStep(description: 'Open Profile', action: () => AutomationEngine.instance.tap(const Key('nav_profile'))),
  TestStep(description: 'Profile is shown', action: () => Expect.visible(find.byText('My Profile'))),
]);
```

For a login that should happen **once for the whole run**, use
`registry.beforeAll(...)` instead of a sub-flow.

---

## Flow catalog

### A. Authentication

**Login (happy path)** — the canonical flow:
```dart
registry.registerTest(name: 'Login succeeds', tags: {'auth', 'smoke'}, steps: [
  ...login(),
]);
```

**Login with invalid credentials → error is shown** (the error is expected UI,
not a thrown exception):
```dart
registry.registerTest(name: 'Login rejects bad password', tags: {'auth'}, steps: [
  ...login(pass: 'wrong'),                                   // reuse, override
  TestStep(description: 'Error message appears',
      action: () => Expect.visible(find.byText('Invalid username or password'))),
  TestStep(description: 'Still on login screen',
      action: () => Expect.visible(find.byKey(const Key('login_button')))),
]);
```
> Note: `...login()` ends by asserting the dashboard, which won't appear here.
> For negative cases, inline the steps (enter + tap) instead of the full helper,
> then assert the error.

**Logout → back to login:**
```dart
registry.registerTest(name: 'Logout', tags: {'auth'}, steps: [
  ...login(),
  TestStep(description: 'Open menu', action: () => AutomationEngine.instance.tap(const Key('nav_settings'))),
  TestStep(description: 'Tap Logout', action: () => AutomationEngine.instance.tap(find.byText('Log out'))),
  TestStep(description: 'Login screen returns', action: () => Expect.visible(find.byKey(const Key('login_button')))),
]);
```

**Signup (multi-field form):**
```dart
registry.registerTest(name: 'Sign up', tags: {'auth'}, steps: [
  TestStep(description: 'Go to sign up', action: () => AutomationEngine.instance.tap(find.byText('Create account'))),
  TestStep(description: 'Fill form', action: () async {
    final e = AutomationEngine.instance;
    await e.enterText(const Key('name_field'), 'Alex');
    await e.enterText(const Key('email_field'), 'alex@example.com');
    await e.enterText(const Key('password_field'), 'hunter2', submit: true);
  }),
  TestStep(description: 'Submit', action: () => AutomationEngine.instance.tap(const Key('signup_button'))),
  TestStep(description: 'Welcome screen', action: () => Expect.visible(find.byText('Welcome, Alex'))),
]);
```

### B. Navigation

**Bottom-nav / tab switching:**
```dart
registry.registerTest(name: 'Tab switching', tags: {'nav'}, steps: [
  ...login(),
  TestStep(description: 'Go to Search tab', action: () => AutomationEngine.instance.tap(const Key('tab_search'))),
  TestStep(description: 'Search screen', action: () => Expect.visible(find.byText('Search'))),
  TestStep(description: 'Go to Profile tab', action: () => AutomationEngine.instance.tap(const Key('tab_profile'))),
  TestStep(description: 'Profile screen', action: () => Expect.visible(find.byText('My Profile'))),
]);
```

**Drawer navigation:**
```dart
TestStep(description: 'Open drawer', action: () => AutomationEngine.instance.tap(find.byIcon(Icons.menu))),
TestStep(description: 'Tap Orders', action: () => AutomationEngine.instance.tap(find.byText('Orders'))),
TestStep(description: 'Orders screen', action: () => Expect.visible(find.byText('Your Orders'))),
```

**Push a detail, then go back:**
```dart
TestStep(description: 'Open item', action: () => AutomationEngine.instance.tap(const Key('item_1_tile'))),
TestStep(description: 'Detail screen', action: () => Expect.visible(find.byText('Item 1 details'))),
TestStep(description: 'Go back', action: () => AutomationEngine.instance.tap(find.byIcon(Icons.arrow_back))),
TestStep(description: 'Back on list', action: () => Expect.visible(find.byText('Inventory'))),
```

### C. Forms

**Submit + success:**
```dart
TestStep(description: 'Fill and submit', action: () async {
  final e = AutomationEngine.instance;
  await e.enterText(const Key('title_field'), 'My note');
  await e.enterText(const Key('body_field'), 'Body text');
  await e.tap(const Key('save_button'));
}),
TestStep(description: 'Saved toast', action: () => Expect.textContaining(find.byType(SnackBar), 'Saved')),
```

**Validation (required field empty):**
```dart
TestStep(description: 'Submit empty form', action: () => AutomationEngine.instance.tap(const Key('save_button'))),
TestStep(description: 'Validation error shown', action: () => Expect.visible(find.byText('Title is required'))),
```

**Submit stays disabled until valid** — assert enabled/disabled state:
```dart
TestStep(description: 'Save is disabled initially', action: () => Expect.disabled(const Key('save_button'))),
TestStep(description: 'Fill required field', action: () => AutomationEngine.instance.enterText(const Key('title_field'), 'x')),
TestStep(description: 'Save becomes enabled', action: () => Expect.enabled(const Key('save_button'))),
```

**Input formatting (digits only, etc.)** — the real IME pipeline runs formatters:
```dart
TestStep(description: 'Type into a digits-only field', action: () => AutomationEngine.instance.enterText(const Key('phone_field'), 'a1b2c3')),
TestStep(description: 'Only digits kept', action: () => Expect.text(const Key('phone_field'), '123')),
```

**Toggles (Switch/Checkbox)** — use `SwitchListTile` / `CheckboxListTile`
(their row is tappable) or a keyed `InkWell`:
```dart
TestStep(description: 'Enable notifications', action: () => AutomationEngine.instance.tap(const Key('notifications_tile'))),
TestStep(description: 'Setting reflects on', action: () => Expect.visible(find.byText('Notifications: On'))),
```
> Caveat: a bare `Switch`/`Checkbox`/`Slider` may report `NotActionable` — the
> tap resolver targets buttons, `InkWell`/`InkResponse`, `GestureDetector`, and
> `ListTile`. Wrap custom controls in a keyed `InkWell`/`GestureDetector`, or use
> the `*ListTile` variants.

### D. Lists

**Scroll to an item, then tap it:**
```dart
TestStep(description: 'Scroll to Item 42', action: () => AutomationEngine.instance.scrollUntilVisible(find.byText('Item 42'))),
TestStep(description: 'Open Item 42', action: () => AutomationEngine.instance.tap(find.byText('Item 42'))),
TestStep(description: 'Item 42 details', action: () => Expect.visible(find.byText('Item 42 details'))),
```

**Search / filter a list:**
```dart
TestStep(description: 'Type a query', action: () => AutomationEngine.instance.enterText(const Key('search_field'), 'banana')),
TestStep(description: 'Results filter down', action: () async {
  await Expect.visible(find.byText('Banana bread'));
  await Expect.absent(find.byText('Apple pie'));
}),
```

**Horizontal list** — pass the axis:
```dart
TestStep(description: 'Scroll carousel to a card', action: () =>
    AutomationEngine.instance.scrollUntilVisible(const Key('card_8'), axis: Axis.horizontal)),
```

**Empty state:**
```dart
TestStep(description: 'Empty message shown', action: () => Expect.visible(find.byText('Nothing here yet'))),
```

> Caveat: **pull-to-refresh** and other drags aren't supported yet (only tap /
> text / scroll). Trigger a refresh via a button, or wait for the Tier-1 gesture
> work.

### E. CRUD

**Create → appears in list:**
```dart
TestStep(description: 'New item', action: () => AutomationEngine.instance.tap(const Key('add_button'))),
TestStep(description: 'Fill + save', action: () async {
  await AutomationEngine.instance.enterText(const Key('name_field'), 'Widget X');
  await AutomationEngine.instance.tap(const Key('save_button'));
}),
TestStep(description: 'Shows in the list', action: () => Expect.visible(find.byText('Widget X'))),
```

**Delete → removed:**
```dart
TestStep(description: 'Delete Widget X', action: () => AutomationEngine.instance.tap(const Key('delete_widget_x'))),
TestStep(description: 'Confirm', action: () => AutomationEngine.instance.tap(find.byText('Delete'))),
TestStep(description: 'Gone from the list', action: () => Expect.absent(find.byText('Widget X'))),
```

**Count changes:**
```dart
TestStep(description: 'Cart badge shows 3', action: () => Expect.text(const Key('cart_badge'), '3')),
```

### F. Async & conditional UI

**Loading → loaded:**
```dart
TestStep(description: 'Trigger load', action: () => AutomationEngine.instance.tap(const Key('load_button'))),
TestStep(description: 'Content arrives', action: () => Expect.visible(find.byText('Loaded data'), timeout: const Duration(seconds: 15))),
```

**Error → retry:**
```dart
TestStep(description: 'Error banner shown', action: () => Expect.visible(find.byText('Something went wrong'))),
TestStep(description: 'Tap Retry', action: () => AutomationEngine.instance.tap(find.byText('Retry'))),
TestStep(description: 'Recovers', action: () => Expect.visible(find.byText('Loaded data'))),
```

**Show/hide toggle:**
```dart
TestStep(description: 'Expand', action: () => AutomationEngine.instance.tap(const Key('expand'))),
TestStep(description: 'Details visible', action: () => Expect.visible(find.byText('More details'))),
TestStep(description: 'Collapse', action: () => AutomationEngine.instance.tap(const Key('expand'))),
TestStep(description: 'Details hidden', action: () => Expect.hidden(find.byText('More details'))),
```

### G. Dialogs, sheets, snackbars

**Confirm dialog:**
```dart
TestStep(description: 'Open confirm', action: () => AutomationEngine.instance.tap(const Key('checkout_button'))),
TestStep(description: 'Dialog appears', action: () => Expect.visible(find.byText('Confirm purchase?'))),
TestStep(description: 'Confirm', action: () => AutomationEngine.instance.tap(find.byText('Yes'))),
TestStep(description: 'Dialog closes', action: () => Expect.absent(find.byText('Confirm purchase?'))),
```

**Cancel dialog:**
```dart
TestStep(description: 'Cancel', action: () => AutomationEngine.instance.tap(find.byText('Cancel'))),
TestStep(description: 'Dialog gone, still on page', action: () => Expect.absent(find.byText('Confirm purchase?'))),
```

**Snackbar text** (they auto-dismiss — assert promptly):
```dart
TestStep(description: 'Snackbar shows', action: () => Expect.textContaining(find.byType(SnackBar), 'Added to cart')),
```

### H. Cross-screen data

Enter data on one screen, verify it on another:
```dart
TestStep(description: 'Edit display name', action: () async {
  await AutomationEngine.instance.tap(const Key('edit_name'));
  await AutomationEngine.instance.enterText(const Key('name_field'), 'Alex R.');
  await AutomationEngine.instance.tap(const Key('save_button'));
}),
TestStep(description: 'Name updated on profile', action: () => Expect.text(const Key('profile_name'), 'Alex R.')),
```

### I. Composite end-to-end (e-commerce)

```dart
registry.registerTest(name: 'Browse → cart → checkout', tags: {'e2e'}, timeout: const Duration(minutes: 1), steps: [
  ...login(),
  TestStep(description: 'Open catalog', action: () => AutomationEngine.instance.tap(const Key('tab_shop'))),
  TestStep(description: 'Find product', action: () => AutomationEngine.instance.scrollUntilVisible(find.byText('Blue Mug'))),
  TestStep(description: 'Open product', action: () => AutomationEngine.instance.tap(find.byText('Blue Mug'))),
  TestStep(description: 'Add to cart', action: () => AutomationEngine.instance.tap(const Key('add_to_cart'))),
  TestStep(description: 'Cart badge = 1', action: () => Expect.text(const Key('cart_badge'), '1')),
  TestStep(description: 'Open cart', action: () => AutomationEngine.instance.tap(const Key('open_cart'))),
  TestStep(description: 'Checkout', action: () => AutomationEngine.instance.tap(const Key('checkout_button'))),
  TestStep(description: 'Confirmation', action: () => Expect.visible(find.byText('Order confirmed'))),
]);
```

---

## Data-driven flows

Register many variants of a flow in a loop:
```dart
for (final item in const ['Item 1', 'Item 8', 'Item 42']) {
  registry.registerTest(name: 'Open $item', tags: {'items'}, steps: [
    TestStep(description: 'Scroll to $item', action: () => AutomationEngine.instance.scrollUntilVisible(item)),
    TestStep(description: 'Open $item', action: () => AutomationEngine.instance.tap(item)),
    TestStep(description: 'Detail for $item', action: () => Expect.visible(find.textContaining(item))),
  ]);
}
```

---

## Running a subset

Filter by tag or name at run time:
```dart
await AutomationController.instance.runAllTests(includeTags: {'smoke'});
await AutomationController.instance.runAllTests(grep: 'checkout');
await AutomationController.instance.runAllTests(excludeTags: {'e2e'});
```

---

## What cannot be a flow (needs a human)

The engine only sees the **Flutter widget tree**, so a step cannot drive:
- Native OS dialogs (permissions, share sheet, file/photo picker), the Android
  system back button, notifications, biometrics.
- Content inside a `WebView`, native platform views, maps, video.
- Flows that leave the app (OAuth redirect to a browser, external payment SDKs).
- Gestures beyond tap / text / scroll (drag, swipe, long-press, pinch, hover).
- Pure visual judgement (layout/color correctness) — screenshots are captured,
  but there's no pixel-diff assertion yet.

For these, keep a short manual checklist alongside the automated flows.
