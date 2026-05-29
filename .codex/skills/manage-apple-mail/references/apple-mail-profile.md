# Apple Mail Profile

## Accounts

Pro:

- `Babacoiffure` -> `admin@babacoiffure.com`
- `kylian pro` -> `mayangakylian@gmail.com`
- `renayam pro` -> `renayam.pro@gmail.com`
- `babacoiffure google 27` -> `babacoiffure27@gmail.com`

Personal:

- `kylian perso` -> `kylianmayanga@gmail.com`
- `sunshinedeep` -> `sunshinedeep81@gmail.com`
- `kylian us` -> `kylianmayangaus@gmail.com`
- `junk mail` -> `azertabj2008@gmail.com`

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

## Smart Mailboxes

Working dashboards:

- `DASHBOARD_PRO`: smart mailbox for pro recipient addresses.
- `DASHBOARD_PERSO`: smart mailbox for personal recipient addresses. If incomplete, repair through the Mail UI rather than direct plist edits.

Direct edits to `~/Library/Mail/V10/MailData/SyncedSmartMailboxes.plist` can be overwritten by Mail cache after restart. Prefer UI automation for Smart Mailboxes.
