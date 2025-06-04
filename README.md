# CiviCRM Extension Template

This directory contains some files that can be used for CiviCRM extensions.

It provides configurations for
[PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer),
[PHPStan](https://phpstan.org/),
and [PHPUnit](https://phpunit.de/) (via
[Symfony PHPUnit Bridge](https://symfony.com/doc/current/components/phpunit_bridge.html)).
Additionally there are workflows to run this tools in GitHub actions. The
worklows are configured to run on git push (might be changed).

(Note: The tools are installed in individual directories to avoid potential
conflicting requirements.)

Apart from that it contains the basic files to start a [documentation with MkDocs](#documentation-with-mkdocs).

## Installation template

### Install from scratch/update

To install/update the files from this template into an existing or newly
created CiviCRM extension first make sure that the `info.xml` is up to date.
Then run:

```sh
./install.sh <extension directory>
```

This will copy all non template files (excluding this file and `install.sh`
itself) to the extension directory. In files with the extension `.template`
the placeholders will be replaced appropriately and the extension will be
dropped.

Only the file `phpstan.neon.template` won't be renamed but just copied:

- copy `phpstan.neon.template` to `phpstan.neon`
- in `phpstan.neon` replace the placeholder `{VENDOR_DIR}` with the Drupal vendor-path of a local civicrm-instance
- add `phpstan.neon.template` to the repository
- `phpstan.neon` depends on local setups and must not be commited to the repo.

If a file already exists you'll be asked how to proceed. So it is safe to run
this script in any case. You might also want to run this script after a file of
this template has been updated.

(Hint: You might want to use the option `--update`. See script usage for
details via `install.sh --help`.)

After running `install.sh`:

* Check `.github/workflows/phpunit.yml`.
  * Adapt `civicrm-image-tags` to your needs. (At least the minimum and maximum supported versions should be used.) See https://hub.docker.com/r/michaelmcandrew/civicrm/tags for available tags (only drupal).
  * The CiviCRM version used comes from the extension's `info.xml`. Ensure that the Docker image tag exists. (For more recent versions there's no php7.4 tag.)
* Adapt `php-versions` in `.github/workflows/phpstan.yml`
  * Recommendation: Earliest and latest supported minor version of each supported major version.
* Add `civicrm/civicrm-packages` as requirement in `ci/composer.json` if required for phpstan in your extension. (`scanFiles` or `scanDirectories` in the phpstan configuration need to be adapted then.)
* If the extension has no APIv3 actions, drop `api` from the scanned directories in `phpstan.neon.dist` and `phpcs.xml.dist` (and remove the directory if existent).
* Add optional directories like `managed` to `phpstan.neon.dist` and `phpcs.xml.dist` if used.
* Set version constraint for PHP in `composer.json` (`composer require 'php:<constraint>'`).
* If you have (or plan to have) dependencies in the extension's `composer.json` add the following code to `{EXT_SHORT_NAME}.php`:

  ```php
  function _{EXT_SHORT_NAME}_composer_autoload(): void {
    if (file_exists(__DIR__ . '/vendor/autoload.php')) {
        require_once __DIR__ . '/vendor/autoload.php';
    }
  }
  ```

  Call this function at the beginning of `{EXT_SHORT_NAME}_civicrm_config()` and `{EXT_SHORT_NAME}_civicrm_container()` (if used).

Additionally in some cases it makes sense to replace `README.md` with a symlink
to `docs/index.md`. (Usually if both files would contain basically the same information.)

### Installation tools

Now install the different tools (might be run later for updates of the tools as well):

```shell
composer composer-tools update
```

## Alternative: (Re)Activate after cloning repo

If this template already exists in a freshly cloned repository, then the following steps are necessary in order to get the `composer-tools` running again:

- copy `phpstan.neon.template` to `phpstan.neon`
- in `phpstan.neon` replace the placeholder `{VENDOR_DIR}` with the Drupal
  vendor-path of a local CiviCRM instance.

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
Otherwise, `phpstan` will complain about missing symbols.

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
```

Because its not possible to use docker containers with `act` the phpunit
action cannot be run via `act`. You might use `docker compose` to do this
yourself.

`act` might be installed via [Homebrew](https://brew.sh/).

## Usage in PhpStorm

PhpStorm allows only one phpcs and phpstan configuration per project. If you
have a project with multiple CiviCRM extensions you might use the scripts in
https://gitea.systopia.de/SYSTOPIA/SystopiaScripts/src/branch/master/phpstorm

## Depending on other CiviCRM extensions

If the CiviCRM extension depends on other extensions they have to be installed
when running phpunit and also phpstan, if it directly uses code from another
extension. The following describes how to handle that case. The placeholder
`{OTHER}` represents the name of the other extension.

### phpstan

When running as GitHub action the code of the other extension has to be
available. This can be achieved by modifying the `run` part of the
*Install dependencies* step in `.github/workflows/phpstan.yml`. To use the base
branch of an extension developed on GitHub the additional line would look like
this:
```
git clone --depth=1 https://github.com/{ORGANIZATION}/{OTHER}.git ../{OTHER} &&
```

To test with different versions of the extension `${{ matrix.prefer }}` could
be checked:
```
if [ "${{ matrix.prefer }}" = "prefer-lowest" ]; then
  git clone ...
else
  git clone ...
fi &&
```

* Add `../{OTHER}` to `scanDirectories` in `phpstan.neon.dist`.

Note: Depending on which code is used it might be enough to only scan a
subfolder of the other extension e.g. `Civi`.

### phpunit

Use `cv ext:download` to install depending extensions in
`tests/docker-prepare.sh`. Add the required lines before the line containing
`cv ext:enable`. Example:
```
cv ext:download "{OTHER}@https://github.com/{ORGANIZATION}/{OTHER}/releases/download/${OTHER}_VERSION/{OTHER}-${OTHER}_VERSION.zip"
```

In this example the version is defined in the shell variable `{OTHER}_VERSION`
which can be set at the beginning of the script.

You might consider using the `matrix` and an environment variable in the GitHub
workflow to run phpunit with different extension versions.

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

* `composer.json`
* `.github/workflows/phpstan.yml`
* `.github/workflows/phpunit.yml`

### Change of minimal CiviCRM version

The following files have to be adapted accordingly if the minimal CiviCRM
version changes:

* `ci/composer.json`
* `.github/workflows/phpunit.yml`
