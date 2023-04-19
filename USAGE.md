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
directory.

* Rename `tests/docker-compose.yml.template` to `tests/docker-compose.yml`.
  * Replace the placeholder `{EXTENSION}`.
* Rename `.github/workflows/phpunit.yml.template` to `.github/workflows/phpunit.yml`.
  * Replace the placeholder `{EXTENSION}`.
  * Adapt `civicrm-image-tags` to your needs. (At least the minimum and maximum supported versions should be used.) See https://hub.docker.com/r/michaelmcandrew/civicrm/tags for available tags (only drupal).
* Adapt `php-versions` in `.github/workflows/phpstan.yml`
  * Recommendation: Earliest and latest supported minor version of each supported major version.
* Rename `phpstan.neon.dist.template` to `* Rename `phpstan.neon.dist`.
  * Replace the placeholder `{EXTENSION}`.
* Copy (not rename) `phpstan.neon.template` to `phpstan.neon` (only used locally).
  * Replace the placeholder `{VENDOR_DIR}` to the path of the `vendor` directory of your CiviCRM installation.
  * The template is kept for others to create their own `phpstan.neon`.
* Set the minimum supported CiviCRM version in `ci/composer.json`.
  * Add `civicrm/civicrm-packages` as requirement if required for phpstan in your extension. (`scanFiles` or `scanDirectories` in the phpstan configuration need to be adapted then.)
  
Now nstall the required dependencies (might be run later for updates as well):

```shell
composer update
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
action cannot be run via `act`. You might use `docker-composer` to do this
yourself.

