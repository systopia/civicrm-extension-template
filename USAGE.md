# CiviCRM extension template

This directory contains some files that can be used for new CiviCRM extensions.

It provides configurations for
[PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer),
[PHPStan](https://phpstan.org/), 
and [PHPUnit](https://phpunit.de/) (via 
[Symfony PHPUnit Bridge](https://symfony.com/doc/current/components/phpunit_bridge.html)).
Additionally there are workflows to run this tools in GitHub actions. The
worklows are configured to run on git push (might be changed).

(Note: The tools are installed in individual directories to avoid potential
conflicting requirements.)

## Installation

Copy all files (including .gitignore, exluding this file) to the extension
directory. (Use [`civix`](https://docs.civicrm.org/dev/en/latest/extensions/civix/)
to create a new one.)

* Rename `composer.json.template` to `composer.json`.
  * Replace the placeholder `{EXTENSION}`.
* Rename `tests/docker-compose.yml.template` to `tests/docker-compose.yml`.
  * Replace the placeholder `{EXTENSION}`.
* Rename `.github/workflows/phpunit.yml.template` to `.github/workflows/phpunit.yml`.
  * Replace the placeholder `{EXTENSION}`.
  * Adapt `civicrm-image-tags` to your needs. (At least the minimum and maximum supported versions should be used.) See https://hub.docker.com/r/michaelmcandrew/civicrm/tags for available tags (only drupal).
* Adapt `php-versions` in `.github/workflows/phpstan.yml`
  * Recommendation: Earliest and latest supported minor version of each supported major version.
* Rename `phpstan.neon.dist.template` to `* Rename `phpstan.neon.dist`.
  * Replace the placeholder `{EXTENSION}`. (Use `_` instead of `-`.)
* Copy (not rename) `phpstan.neon.template` to `phpstan.neon` (only used locally).
  * Replace the placeholder `{VENDOR_DIR}` to the path of the `vendor` directory of your CiviCRM installation.
  * The template is kept for others to create their own `phpstan.neon`.
* Set the minimum supported CiviCRM version in `ci/composer.json`.
  * Add `civicrm/civicrm-packages` as requirement if required for phpstan in your extension. (`scanFiles` or `scanDirectories` in the phpstan configuration need to be adapted then.)
* If the extension has no APIv3 actions, drop `api` from the scanned directories in `phpstan.neon.dist` and `phpcs.xml.dist` (and remove the directory if existent).

Now install the required dependencies (might be run later for updates as well):

```shell
composer update
composer composer-tools update
```

Note: If no requirement was added to `composer.json` at least the file
`vendor/autoload.php` will be created which is referenced in the phpstan
configuration. Alternatively the configuration can be adjusted to make the
call of `composer update` obsolete. (The `vendor` directory is ignored via
`.gitignore`.)

## Run tools

Run the tests with `composer test` or each tool on its own:

```shell
composer phpcs
composer phpstan
composer phpunit
```

To fix code style issues with phpcbf run `composer phpcbf`.

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
action cannot be run via `act`. You might use `docker-composer` to do this
yourself.

## Usage in PhpStorm

PhpStorm allows only one phpcs and phpstan configuration per project. If you
have a project with multiple CiviCRM extensions you might use the scripts in
https://gitea.systopia.de/SYSTOPIA/SystopiaScripts/src/branch/master/phpstorm

## Dependending on other CiviCRM extensions

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
git clone --depth=1 https://github.com/{ORGANIZATION}/{OTHER}.git &&
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

* Add `{EXT_DIR}/{OTHER}/` to `scanDirectories` in `phpstan.neon.template` with `{OTHER}` replaced.
* Add the above line also to `phpstan.neon` with `{EXT_DIR}` replaced, too.
* Add `{OTHER}/` to `scanDirectories` in `phpstan.ci.neon`.

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
