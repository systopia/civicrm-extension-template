# CiviCRM Extension Template

This directory contains some files that can be used for CiviCRM extensions.

It provides configurations for
[PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer),
[PHPStan](https://phpstan.org/),
and [PHPUnit](https://phpunit.de/) (via
[Symfony PHPUnit Bridge](https://symfony.com/doc/current/components/phpunit_bridge.html)).
Additionally there are workflows to run this tools in GitHub actions. The
workflows are configured to run on `git push` (might be changed).

(Note: The tools are installed in individual directories to avoid potential
conflicting requirements.)

Apart from that it contains the basic files to start a [documentation with MkDocs](#documentation-with-mkdocs).

In addition there are the following helper scripts:

* [`tools/create-release.sh`](`tools/create-release.sh`) Helps to create a new release of the extension.
* [`tools/update-pot.sh`](`tools/update-pot.sh`) Extracts translatable strings and updates the `.pot` file.

See the help of the scripts for more details.

This template allows to add `civicrm/civicrm-core` as requirement to the
`composer.json` to specify the minimum required CiviCRM version as well as other
CiviCRM extensions that are available as composer package. This makes it
possible to install a CiviCRM extension via `composer` with all its
dependencies. When running `composer update` in the extension directory itself,
the installation of `civicrm/civicrm-core` and CiviCRM extensions is
[prevented](ComposerHelper.php.template).

## Installation template

### Install from scratch/update

To install/update the files from this template into an existing or newly
created CiviCRM extension first make sure that the `info.xml` is up to date.
Then run:

```shell
./install.sh <extension directory> [<file or directory in extension template> ...]
```

This will copy all non template files (excluding this file and `install.sh`
itself) to the extension directory. In files with the extension `.template`
the placeholders will be replaced appropriately and the extension will be
dropped. If files are specified only those will be installed.

Only the file `phpstan.neon.template` won't be renamed, but just copied.

If a file already exists you'll be asked how to proceed. So it is safe to run
this script in any case. You might also want to run this script after a file of
this template has been updated.

(Hint: You might want to use the option `--update`. See script usage for
details via `install.sh --help`.)

The script automatically executes
[`tools/git/init-hooks.sh`](`tools/git/init-hooks.sh`) to initialize the git
hooks.

After running `install.sh`:

* Change the vendor name *systopia* in `composer.json` if necessary.
* Copy `phpstan.neon.template` to `phpstan.neon` and replace the placeholder
  `{VENDOR_DIR}` with the vendor-path of the root composer project. If you 
  installed CiviCRM Standalone, make sure to use the alternative parameters 
  section.
* Adapt `php-versions` in `.github/workflows/phpstan.yml`
  * Recommendation: Earliest and latest supported minor version of each
    supported major version.
* If elements from `civicrm/civicrm-packages` are used in your extension,
  `scanFiles` or `scanDirectories` in the phpstan configuration might need to be
  adapted.
* Adjust the directories to analyze in `phpstan.neon.dist` and `phpcs.xml.dist`.
  * Remove directories if not existent, e.g. `api`.
  * Add directories like `ang` if used. (Note: The directory `managed` usually
    should be added only to `phpstan.neon.dist` because the code exported by
    CiviCRM doesn't match all rules in `phpcs.xml.dist`.)
* If you have (or plan to have) dependencies in the extension's `composer.json`
  add the following code to `{EXT_SHORT_NAME}.php`:

  ```php
  function _{EXT_SHORT_NAME}_composer_autoload(): void {
    if (file_exists(__DIR__ . '/vendor/autoload.php')) {
      require_once __DIR__ . '/vendor/autoload.php';
    }
  }
  ```

  Call this function at the beginning of `{EXT_SHORT_NAME}_civicrm_config()` and
  `{EXT_SHORT_NAME}_civicrm_container()` (if used).

Additionally, in some cases it makes sense to replace `README.md` with a symlink
to `docs/index.md`. (Usually if both files would contain basically the same
information.)

### Installation tools

Now install the different tools (might be run later for updates of the tools as
well):

```shell
composer composer-tools update
```

## Alternative: (Re)Activate after cloning repo

If this template already exists in a freshly cloned repository, you need to
initialize the git hooks and install the various tools.

To initialize the git hooks execute
```shell
./tools/git/init-hooks.sh
```

The following steps are necessary in order to get the `composer-tools` running
again:

* Copy `phpstan.neon.template` to `phpstan.neon` and replace the placeholder
  `{VENDOR_DIR}` with the vendor-path of the root composer project.

Install all project dependencies, that are listed in the repos `composer.json`
file (if there are any) either in the extension directory or in the root
`composer.json`. They are necessary for `phpstan` to resolve symbols of external
library code:

```shell
composer update # or add requirements to root composer.json
```

Install `composer-tools` in order to locally run `phpcs`, `phpcbf`, `phpstan`
and `phpunit`.

```shell
composer composer-tools update
```

Make sure that in your local CiviCRM instance, all those extensions have been
installed, that the current project is depending on (if there are any).
Otherwise, `phpstan` may complain about missing symbols.

## Run tools

Run the tests with `composer test` or each tool on its own:

```shell
composer phpcs
composer phpstan
composer phpunit
```

To fix code style issues with `phpcbf` run `composer phpcbf`.

## Recommendations for existing extensions

If you add this template to an existing extension it might lead to many
errors and  warnings that you cannot handle immediately. Here you can find
some recommendations for that case. Make sure the tests run successfully before
enabling them in the CI system (GitHub Actions).

### Initial handling of code style violations

Recommended approach:

1. Fix style violations automatically with `composer phpcbf`.
1. Run `composer phpcs` and fix the remaining issues by hand.
1. If there are still too many issues to handle immediately:
   * [Ignore parts of
    files](https://github.com/PHPCSStandards/PHP_CodeSniffer/wiki/Advanced-Usage#ignoring-parts-of-a-file)
    (be specific about ignored sniffs, if possible).
    * Exclude files or directories from validation in `phpcs.xml.dist`.

In general it should be shortly mentioned when validation is disabled for that
reason.

### Initial handling of phpstan errors

Recommended approach:

1. Run phpstan with the lowest level (`composer run -- phpstan --level=0`) and
  fix the reported errors.
1. Gradually increase the level and fix the reported errors until the
  important issues are fixed or the number of messages is overwhelming.
1. Create a [baseline](https://phpstan.org/user-guide/baseline) for the
   remaining errors:
   * Run `composer run -- phpstan --generate-baseline`.
   * Include `phpstan-baseline.neon` in `phpstan.neon.dist`:
   ```
   includes:
  	- phpstan-baseline.neon
   ```

Consider opening an issue saying that errors in the baseline should be checked.

## Dealing with errors

If any tool reports an error or warning it has to be resolved!

In case it's a false positive or there exists no practicable way to resolve it,
errors can be ignored.

### Dealing with code style errors

Errors reported by phpcs can be ignored with `// phpcs:ignore <sniffs>` above
the problematic line. See [the
manual](https://github.com/PHPCSStandards/PHP_CodeSniffer/wiki/Advanced-Usage#ignoring-parts-of-a-file)
for more details. If you make use of `// phpcs:disable <sniffs>` always enable
the sniffs again with `// phpcs:enable`. (Always state the ignored sniffs.)

### Dealing with phpstan errors

Errors reported by phpstan can be ignored with `// @phpstan-ignore <error
identifiers>` above the problematic line. See [the
manual](https://phpstan.org/user-guide/ignoring-errors) for more details.
(Always state the ignored error identifiers and don't use
`// @phpstan-ignore-next-line`.)

Add an explanation if it's not obvious why an error is ignored.

In some cases it might make sense to ignore errors in the `phpstan.neon.dist`
[configuration
file](https://phpstan.org/user-guide/ignoring-errors#ignoring-in-configuration-file).
Though the ignored errors should always be as specific as possible, i.e. actual
issues must never be covered that way.

## Testing GitHub actions locally

It is possible to test GitHub actions for phpcs and phpstan locally using
[`nektos/act`](https://github.com/nektos/act) and
[`shivammathur/node`](https://github.com/shivammathur/node-docker) docker
images:

```shell
act -P ubuntu-latest=shivammathur/node:latest -j phpcs
act -P ubuntu-latest=shivammathur/node:latest -j phpstan
# Network "bridge" is necessary to start MySQL service in the container.
# (act uses host network by default.)
act -P ubuntu-latest=shivammathur/node:latest -j phpunit --network bridge
```
It is possible to limit the matrix like this:

```shell
act workflow_dispatch -P ubuntu-latest=shivammathur/node:latest -j phpstan --matrix php-versions:8.4 --matrix prefer:prefer-stable
```

The phpunit workflow allows to specify a composer version constraint for CiviCRM
in the `workflow_dispatch` trigger:

```shell
act workflow_dispatch -P ubuntu-latest=shivammathur/node:latest -j phpunit --network bridge --input civicrm-version="6.7.8"
```

`act` might be installed via [Homebrew](https://brew.sh/).

## Usage in PhpStorm

PhpStorm allows only one phpcs and phpstan configuration per project. If you
have a project with multiple CiviCRM extensions you might use the scripts in
https://github.com/systopia/phpstorm-scripts

## GitHub Actions: Depending on other CiviCRM extensions

If the CiviCRM extension depends on other extensions they have to be installed
when running phpunit and also phpstan, if it directly uses code from another
extension. The following describes how to handle that case. The placeholder
`{OTHER}` represents the name of the other extension.

### phpstan

When running as GitHub action the code of the other extension has to be
available. In the best case they can be installed via composer. Otherwise, the
`run` part of the *Install dependencies* step in `.github/workflows/phpstan.yml`
has to be modified accordingly. To use the base branch of an extension developed
on GitHub the additional line would look like this:
```shell
git clone --depth=1 https://github.com/{ORGANIZATION}/{OTHER}.git ../{OTHER}
```

To test with different versions when a dependent extension cannot be installed
via composer `${{ matrix.prefer }}` could be checked:
```shell
if [ "${{ matrix.prefer }}" = "prefer-lowest" ]; then
  git clone ...
else
  git clone ...
fi
```

* Add `../{OTHER}` to `scanDirectories` in `phpstan.neon.dist`.

Note: Depending on which code is used it might be enough to only scan a
subfolder of the other extension e.g. `Civi`.

### phpunit

It has to be ensured that dependent extensions are available in the `ext` folder
when running phpunit. In the best case extensions can be installed via
composer. Otherwise, the `run` part of the *Set up CiviCRM* step in
`.github/workflows/phpunit.yml` has to be modified accordingly. For example
an extension can be fetched with `cv ext:download`:
```shell
cv ext:download "{OTHER}@https://github.com/{ORGANIZATION}/{OTHER}/releases/download/${OTHER}_VERSION/{OTHER}-${OTHER}_VERSION.zip"
```

In this example the version is defined in the environment variable
`{OTHER}_VERSION`.

To test with different versions when a dependent extension cannot be installed
via composer `${{ matrix.prefer }}` could be checked:
```shell
if [ "${{ matrix.prefer }}" = "prefer-lowest" ]; then
  {OTHER}_VERSION=1.0.0
else
  {OTHER}_VERSION=1.2.3
fi
```

## Documentation with MkDocs

Basic files for a documentation with [MkDocs](https://www.mkdocs.org/) are
installed by this template.

When editing the documentation you can use `mkdocs` to verify the changes.
Ensure you have `mkdocs` installed (`apt install mkdocs`). Then you can run
`mkdocs serve` in the extension directory and open the URL printed on the
console. Changes will be applied immediately to the served website.

How to get the documentation up on [docs.civicrm.org](https://docs.civicrm.org/)
is explained in the [developer
guide](https://docs.civicrm.org/dev/en/latest/extensions/documentation/#submit).

## Files to adapt if minimal PHP or CiviCRM version changes

### Change of minimal PHP version

The following files have to be adapted accordingly if the minimal PHP version
changes:

* `info.xml`:
  [`<php_compatibility>`](https://docs.civicrm.org/dev/en/latest/extensions/info-xml/#php_compatibility)
  (if used)
* `composer.json`: `composer require --no-update php:^{VERSION}`
* `.github/workflows/phpstan.yml`
* `.github/workflows/phpunit.yml`

### Change of minimal CiviCRM version

The following files have to be adapted accordingly if the minimal CiviCRM
version changes:

* `info.xml`: [`<compatiblity>`](https://docs.civicrm.org/dev/en/latest/extensions/info-xml/#compatibility)
* `composer.json`:
  `composer require --no-update civicrm/civicrm-core:>={VERSION} civicrm/civicrm-packages:>={VERSION}`

## Files to adapt if a new version of PHP is released

To test with the latest version of PHP the following files have to be adapted
accordingly, if a new version of PHP (minor or major) is released:

* `.github/workflows/phpstan.yml`
* `.github/workflows/phpunit.yml`
