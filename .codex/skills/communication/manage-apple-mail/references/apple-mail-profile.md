# Apple Mail Profile

## Accounts

Pro:

- `Babacoiffure` -> `admin@babacoiffure.com`
- `kylian pro` -> `mayanga.kylian@gmail.com`

Personal:

- `kylian perso` -> `kylianmayanga@gmail.com`

Other configured Mail accounts are not part of the normal pro/perso workflow
unless the user explicitly reclassifies them.

## Folder Conventions

Pro folders:

- `00_PRO_A_TRAITER`
- `01_PRO_ADMIN_COMPTES`
- `02_PRO_FACTURES`
- `03_PRO_CLIENTS_BUSINESS`
- `04_PRO_NEWSLETTERS`

Personal folders:

- `00_PERSO_A_TRAITER`
- `01_PERSO_ADMIN_COMPTES`
- `02_PERSO_FACTURES`
- `03_PERSO_VOYAGE`
- `04_PERSO_NEWSLETTERS`

## Learned Patterns

`bounce-undelivered`:

- Scope: pro
- Subject contains: `Undelivered Mail Returned to Sender`
- Destination: `00_PRO_A_TRAITER`
- Extra action: flag orange

`stripe-invoice-exact`:

- Scope: pro
- Sender contains: `invoice+statements+acct_1CTbIsBmBV2o9vP5@stripe.com`
- Destination: `02_PRO_FACTURES`

`qonto-transfers`:

- Scope: pro
- Sender contains: `support@qonto.com`
- Subject contains any:
  - `You received a transfer`
  - `Your transfer has been executed successfully`
- Destination: `02_PRO_FACTURES`
- Retroactive apply should skip trash/junk/spam.

`tldv-failed-payment`:

- Scope: `Babacoiffure` / `admin@babacoiffure.com`
- Sender contains: `failed-payments+acct_1GsT2DAmFsu7xy0b@stripe.com`
- Destination: `00_PRO_A_TRAITER`
- Extra action: flag orange

`babacoiffure-recurring-newsletters`:

- Scope: `Babacoiffure` / `admin@babacoiffure.com`
- `learn@send.zapier.com` and senders containing `mobbin.com`
- Destination: `04_PRO_NEWSLETTERS`

`disposable-marketing-extra-accounts`:

- `value@acquisition.com` and `no-reply@marketing.base44.com` sent to
  `azertabj2008@gmail.com` go to Trash.
- `noreply@x.ai` sent to `renayam.pro@gmail.com` goes to Trash.
- These rules are recipient-scoped and do not permanently delete or empty Trash.

## Smart Mailboxes

`DASHBOARD_PRO` and `DASHBOARD_PERSO` were removed on 2026-06-20 through the
Mail UI. Current smart mailboxes use explicit account and category names:

- `COMPTE - PRO Babacoiffure`
- `COMPTE - PRO Kylian`
- `COMPTE - PERSO Kylian`
- `CATEGORIE - factures et paiements`
- `CATEGORIE - a traiter`
- `CATEGORIE - admin comptes`
- `CATEGORIE - dev et produit`
- `CATEGORIE - newsletters`
- `CATEGORIE - voyage`
- `CATEGORIE - marketing unsubscribe`

These are views only; they do not move or delete messages. `CATEGORIE -
marketing unsubscribe` matches all non-trash/non-junk/non-sent mail where the
message body contains `unsubscribe`. Account smart boxes
are strict account views. Category smart boxes are keyword views and intentionally
do not claim to be pro/perso scoped, because Mail's UI cannot reliably express
`(account A or account B) and (keyword A or keyword B)` in a single smart box.
They were created through the Mail UI because direct plist edits are overwritten
by Mail sync.
