<?php

declare(strict_types = 1);

use PhpCsFixer\Config;
use PhpCsFixer\Finder;

$finder = Finder::create()
  ->in([
    __DIR__ . '/CRM',
    __DIR__ . '/Civi',
    __DIR__ . '/api',
    __DIR__ . '/tests',
  ])
  ->exclude(['vendor', 'node_modules']);

return (new Config())
  ->setRiskyAllowed(TRUE)
  ->setRules([
    'declare_strict_types' => TRUE,
  ])
  ->setFinder($finder);
