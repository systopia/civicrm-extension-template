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

## Installation

To install/update the files from this template into an existing CiviCRM
extension run:

```sh
./install.sh <extension directory>
```

This will copy all non template files (excluding this file and `install.sh`
itself). To the extension directory. In files with the extension `.template`
the placeholders will be replaced appropriately and the extension will be
dropped. The file `phpstan.neon.template` won't be renamed but just copied.
This file should be added to the repository instead of `phpstan.neon`. The
latter one should be identical to `phpstan.neon.template`, but with the
placeholder `{VENDOR_DIR}` replaced.

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
* If you have (or plan to have) dependencies in the extension's `composer.json` add the following code to `{EXT_SHORT_NAME}.php`:

  ```php
  function _{EXT_SHORT_NAME}_composer_autoload(): void {
    if (file_exists(__DIR__ . '/vendor/autoload.php')) {
        require_once __DIR__ . '/vendor/autoload.php';
    }
  }
  ```

  Call this function at the beginning of `{EXT_SHORT_NAME}_civicrm_config()` and `{EXT_SHORT_NAME}_civicrm_container()` (if used).

Now install the different tools (might be run later for updates of the tools as well):

```shell
composer composer-tools update
```

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
action cannot be run via `act`. You might use `docker compose` to do this
yourself.

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
