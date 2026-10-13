---
name: magento-integration-tests
description: Write, run and debug Magento 2 / Adobe Commerce INTEGRATION tests the modern way — PHP Attributes (#[DataFixture], #[DbIsolation], #[AppArea], #[Config], #[Cache]) plus parameterized data fixtures implementing DataFixtureInterface / RevertibleDataFixtureInterface. Use whenever the task involves an integration test: "write integration test", "cover by integration tests", "test this plugin/observer/repository end to end", "magentoDataFixture", "data fixture", "fixture storage", "DbIsolation", "test sandbox", "dev/tests/integration", "phpunit integration". ALSO use when reading or refactoring an EXISTING integration test that still uses legacy @magentoDataFixture / @magentoDbIsolation docblocks, or when an integration test leaks data between tests. Not for unit tests, not for MFTF/functional.
---

# Magento 2 integration tests — attributes + parameterized fixtures

Caveman register. Facts below verified against framework source in
`dev/tests/integration/framework/Magento/TestFramework/`, not just docs. Where docs and
source disagree, source wins — noted inline.

## CORE RULE

New integration test → **PHP Attributes + parameterized fixtures**. Never legacy.

- Legacy `_files/*.php` scripts + `@magentoDataFixture Magento/Catalog/_files/x.php` = deprecated.
  Adobe: "New legacy fixtures **cannot be created**."
- Parameterized fixtures **cannot** be driven by docblocks. Attributes only.
- Never hand-roll entity creation in `setUp()`/private helpers when a `Test/Fixture` class exists.
  Hand-rolling is the legacy smell, not the fixture.

## ATTRIBUTE TABLE — real signatures from source

All `Magento\TestFramework\Fixture\`. "rep" = `IS_REPEATABLE`.

| Attribute | Constructor | Targets |
|---|---|---|
| `DataFixture` | `(string $type, array $data = [], ?string $as = null, ?string $scope = null, int $count = 1)` | method+class, rep |
| `DataFixtureBeforeTransaction` | extends `DataFixture` — same signature | method+class, rep |
| `DbIsolation` | `(bool $state = true)` | method+class |
| `AppIsolation` | `(bool $state = true)` | method+class |
| `AppArea` | `(string $area)` | method+class |
| `Cache` | `(string $type, bool $status)` | method+class, rep |
| `Config` | `(string $path, mixed $value, string $scopeType = 'default', ?string $scopeValue = null)` | method+class, rep |
| `ComponentsDir` | `(string $path)` | method+class, rep |
| `IndexerDimensionMode` | `(string $indexer, string $dimension)` | method+class |

`$type` in `DataFixture` = FQCN of a fixture class, NOT an entity name.

Docs claim `Config` is method-level only. Source says `TARGET_CLASS` too — trust source.

Application order (framework-enforced):
AppIsolation → DbIsolation → DataFixtureBeforeTransaction → DataFixture →
IndexerDimensionMode → ComponentsDir → AppArea → Cache → Config.

`AppArea` values: `Area::AREA_GLOBAL|AREA_ADMINHTML|AREA_FRONTEND|AREA_WEBAPI_REST|AREA_WEBAPI_SOAP|AREA_CRONTAB|AREA_GRAPHQL`. Default `global`.

## MERGE SEMANTICS — bites people

**Method-level REPLACES class-level. Never merges.** Holds for `Cache`, `DbIsolation`,
`AppArea`, `AppIsolation`, fixtures.

So a class-level `#[Cache('all', true)]` is fully wiped by one method-level
`#[Cache('config', false)]` — that method runs with all other caches disabled.

Class-level `DataFixture` applies to every test in the class; any method-level `DataFixture`
overrides the whole class-level set, not just one entry.

## ISOLATION — how it really works

`AppIsolation(bool $state = true)` — reinitializes the app so state does not carry over.
Defaults:

| Test ancestor | class level | method level |
|---|---|---|
| `PHPUnit\Framework\TestCase` | enabled | disabled |
| `Magento\TestFramework\TestCase\AbstractController` | enabled | enabled |

Class-level app isolation **cannot** be disabled. Enable at method level when the test
intentionally mutated shared application objects. Costs a reinit — do not sprinkle.

`DbIsolation(bool $state = true)` — begins a transparent transaction, suppresses commit,
rolls back after.

**DbIsolation is coupled to DataFixture.** Traced in `Annotation/DataFixture.php:29-40`:

- test has fixtures AND isolation not explicitly `disabled` → the *fixture* handler calls
  `requestTransactionStart()`. Rollback undoes everything.
- isolation explicitly disabled → fixtures applied outside any transaction, then torn down by
  each fixture's `revert()`. Requires `RevertibleDataFixtureInterface`, else data leaks.

That is what "DbIsolation is disabled by default unless DataFixture is used" actually means.
No fixtures + no `DbIsolation` → **no transaction at all**, writes persist.

`DataFixtureBeforeTransaction` — applies before the transaction opens, reverts after it closes.
Use for state that must survive the transaction boundary: indexer modes, global switches,
config other fixtures depend on.

## ALIASES + CROSS-FIXTURE REFERENCES

- `as: 'x'` names the return value.
- Retrieve: `DataFixtureStorageManager::getStorage()->get('x')` → `?DataObject`.
  Cache it in `setUp()`: `$this->fixtures = DataFixtureStorageManager::getStorage();`
- Reference in a later fixture's `$data`: `'$x$'` (whole object) or `'$x.snake_case_prop$'`.
- `count: 3` + `as: 'product'` → auto aliases `product1`, `product2`, `product3`.

Canonical core example — `Catalog/Model/ResourceModel/Product/CollectionTest.php:158`:

```php
#[
    AppIsolation(true),
    DbIsolation(false),
    DataFixture(CategoryFixture::class, as: 'c1'),
    DataFixture(CategoryFixture::class, ['parent_id' => '$c1.id$', 'is_anchor' => 0], 'c11'),
    DataFixture(CategoryFixture::class, ['parent_id' => '$c11.id$'], 'c111'),
    DataFixture(ProductFixture::class, ['category_ids' => ['$c1.id$']], 'p1'),
]
public function testSetCategoryFilter()
{
    $categoryId = $this->fixtures->get('c1')->getId();
```

Minimal shape — `Catalog/Model/CategoryTest.php:531`:

```php
#[
    DataFixture(CategoryFixture::class, as: 'category'),
]
public function testGetUrlAfterUpdate()
{
    $category = $this->dataFixtureStorage->get('category');
```

## WRITING A CUSTOM FIXTURE

Interfaces, exact from source:

```php
interface DataFixtureInterface {
    public function apply(array $data = []): ?DataObject;
}
interface RevertibleDataFixtureInterface extends DataFixtureInterface {
    public function revert(DataObject $data): void;   // takes DataObject, NOT a fixture
}
```

Docs prose says `revert(DataFixtureInterface $dataFixture)`. Wrong. It is `DataObject`.

Pick the interface:
- entity needing explicit teardown (product, category, customer, CMS page) → `RevertibleDataFixtureInterface`
- data that dies with its parent (e.g. child rows cascaded away) → plain `DataFixtureInterface`

House pattern, copy `Magento\Catalog\Test\Fixture\Category`:

- `private const DEFAULT_DATA = [...]` with `%uniqid%` in unique fields
- inject `ServiceFactory`, `ProcessorInterface` (data processor), `DataMerger`
- `apply()`: `$this->serviceFactory->create(XRepositoryInterface::class, 'save')->execute([...])`
- `revert()`: same factory, `'deleteByIdentifier'` / `'deleteById'`
- `prepareData()`: `$this->dataMerger->merge(self::DEFAULT_DATA, $data)` then `$this->dataProcessor->process($this, $data)`

Location convention: `<Module>/Test/Fixture/<Entity>.php`.

Three collaborators, what they do:

- `ServiceFactory` — thin `ObjectManager->create(Service::class, [className, methodName])`.
  **Fixtures persist through service contracts.** So plugins on the repository AND on the
  resource model DO fire during fixtures. Good for coverage — also means a broken plugin makes
  fixtures themselves explode, not just assertions.
- `UniqueIdProcessor` — swaps `%uniqid%` for a per-fixture-class `uniqid()` + increment.
  Do not override auto-generated unique fields (sku, name) unless the test demands the value.
- `DataMerger` — merges caller data over defaults. **Trap:** any key absent from
  `DEFAULT_DATA` is auto-routed into `custom_attributes` (or `extension_attributes` when the
  key exists there). Passing a custom EAV/static column to a stock fixture lands it in
  `custom_attributes`, not as plain model data. Verify it reaches the entity, or write a
  project-local fixture.

## RETRIEVING FIXTURE DATA

Always via `DataFixtureStorageManager::getStorage()`. Never rely on implicit side effects
(reloading by hardcoded sku/name/id). Storage API is three methods: `get(string)`,
`persist(string, ?DataObject)`, `flush()`.

## EXISTING FIXTURE CATALOG — look before writing

Search `*/Test/Fixture/*.php` in vendor before authoring anything. `Magento_Catalog` alone ships:
`Category`, `CategoryAttribute`, `Product`, `Virtual`, `Attribute`, `AttributeSet`,
`SelectAttribute`, `MultiselectAttribute`, `ProductStock`, `AssignProducts`, `AssignCategories`.

## MIXING WITH LEGACY

Attributes and docblocks are both parsed, via `Annotation\Parser\Composite` combining
`Annotation\Parser\X` + `Fixture\Parser\X`. Core test classes mix both styles in one file.
So legacy tests keep working — but only one isolation declaration per scope is allowed, else
`LocalizedException: Only one "@magentoDbIsolation" annotation is allowed per test`.

Do not convert legacy tests wholesale unless asked. New methods → attributes.

## RUNNING

Project-specific first: check `AGENTS.md` / `CLAUDE.md` for a custom phpunit config path —
many projects keep it outside Magento defaults (e.g. `.cicd/tests/integration/phpunit.xml`).
Otherwise default is `dev/tests/integration/phpunit.xml`, run from `dev/tests/integration`.

- whole suite: `vendor/bin/phpunit -c <config>`
- one class/method: `--filter 'TestClassName|testMethodName'`
- readable output: `--testdox`
- Dockerized (Warden etc.): run inside the PHP container, not on host PHP. Host PHP version
  often differs from project target and tooling will complain.

First run of a brand-new suite dir usually needs the sandbox built. Sandbox lives in
`dev/tests/integration/tmp/sandbox-*/` and carries **its own `generated/code`** — a plugin
added to `di.xml` will not exist in an old sandbox's interceptors.

Reinit when tests behave impossibly:
`git clean -dfx dev/tests/integration/var dev/tests/integration/tmp "app/code/Magento/Test*"`,
restart the test DB service, wait a few seconds, rerun.

`TESTS_CLEANUP` in phpunit.xml controls DB reinstall per run. Disabled = fast but requires
manual cache clearing; enabled = slow and safe.

## DEBUG CHECKLIST

Test fails in a way the code says is impossible — walk this in order:

1. Stale sandbox interceptors → sandbox holds its own `generated/code`. Wipe sandbox.
2. Data leaked from an earlier test → no transaction opened. Confirm the test has fixtures OR
   an explicit `#[DbIsolation]`. Neither → writes are permanent.
3. `DbIsolation(false)` used with a non-revertible fixture → nothing cleans up.
4. Method-level attribute silently wiped a class-level one (see MERGE SEMANTICS).
5. Custom key vanished → `DataMerger` routed it into `custom_attributes`.
6. Wrong area → add `#[AppArea('adminhtml')]`; admin-only code silently misbehaves in `global`.
7. Config not taking → `#[Config]` reverts after each test; also check `scopeType`/`scopeValue`.

## CHECKLIST BEFORE HANDING OVER A NEW TEST

- reused an existing `Test/Fixture` class where one exists
- attributes, not docblocks
- every created entity has a teardown path (transaction rollback or `revert()`)
- fixture data read via `DataFixtureStorageManager`
- `#[AppArea]` set when the code under test is area-sensitive
- enumerated every branch/case first and covered each, not happy path only
- cases differing only in input/expected → one method + data provider; separate methods only when fixtures, setup or assertions differ
- ran the suite and pasted real output; no "should pass"
