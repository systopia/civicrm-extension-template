<div style="text-align: center;">

<img src="/docs/images/logo-systopia.webp"/>

![Generic badge](https://img.shields.io/badge/Maintained-Actively-green.svg)
[![Generic badge](https://img.shields.io/badge/Maintainer-SYSTOPIA-blue.svg)](https://github.com/systopia)
[![Generic badge](https://img.shields.io/badge/License-AGPL%203.0-yellow.svg)](https://opensource.org/licenses/AGPL-3.0)
[![Generic badge](https://img.shields.io/badge/PRs-Welcome-green.svg)](/issues)

<span style="display:inline-block; position:relative; top:-9px; padding-right:4px">Built for</span> <img src="/docs/images/logo-civicrm.webp" height="30"/>

</div>



# [TODO: EXTENSION.NAME] (e.g. Assumed Payments)

[TODO: ONE SENTENCE]

e.g.:

CiviCRM extension to automatically create **assumed payments** for recurring contributions where payments are missing or
still considered "open" within a defined date range.

---

## Description

[TODO: SHORT DESCRIPTION]

e.g.:

Assumed Payments identifies recurring contributions with missing or still open payments within a defined date range and creates corresponding assumed payment transactions.

It solves the problem of incomplete recurring contribution accounting where payments are delayed, missing, or intentionally assumed.

Designed for organizations running CiviCRM with recurring contributions that require structured financial reconciliation.

## Features

[TODO: FEATURE BULLETS] (max 6)

e.g.:

- Identifies relevant `ContributionRecur` records within a configured date window
- Creates queue items for each eligible recur
- Ensures a **Pending** contribution instance exists
- Creates a **Payment** for the contribution amount
- Marks the resulting financial transaction as *assumed*
- Marks the contribution as **Completed**

## Quickstart

[TODO: QUICKSTART GUIDE]

e.g.:

Install and enable the extension in CiviCRM.

or

Install by using `composer require systopia/civicrm-test-fixtures`

## Documentation

For further information please consult the extensive [documentation](/docs/index.md).

## Status

[TODO: KEEP ONLY ONE]

[![Generic badge](https://img.shields.io/badge/Status-Actively%20Maintained-green.svg)](https://shields.io/)
[![Generic badge](https://img.shields.io/badge/Status-Not%20Actively%20Maintained-red.svg)](https://shields.io/)

Production-ready and suitable for use in live environments.

## Support / Issues / Contributions

### We need your Support
This CiviCRM extension is Free and Open Source Software and we are glad if you find it useful.

However, a significant part of its development and ongoing maintenance happens outside funded projects. If this extension creates value for your work, consider supporting its continued development.

If you’d like to contribute financially, feel free to reach out via info@systopia.de to arrange a simple and suitable way.

Your support helps keep this extension maintained, improved, and available to everyone. 

### Issues / Security

Please report issues and security concerns [here](/issues).

### Contributions

Contributions are welcome. Learn how to contribute [here](docs/contributions.md).
