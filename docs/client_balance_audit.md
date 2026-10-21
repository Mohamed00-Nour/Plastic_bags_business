# Client credit and historical overpayments

Client balances are signed: positive means the client owes the store; negative
means the store holds credit for the client. New and edited sales invoices post
`totalAmount - paidAmount`, including negative values. Deletion reverses the
recorded posting. An older invoice with a clamped `remainingAmount` is corrected
when saved again; saving it repeatedly does not credit the same excess twice.

The read-only audit identifies historical invoices where the recorded posting
differs from the full payment. It never writes to Firestore. With the project's
existing service account, run from the repository root:

```powershell
dart run tool/audit_client_overpayments.dart --credentials assets/plastic-service-account.json --output build/client_overpayment_audit.json
```

Alternatively use `--input snapshot.json`, containing `sales_invoices` and
`clients` arrays of plain document maps with an `id` field, for an offline audit.
Keep exports and reports outside Git; `build/` is already ignored.

Review each candidate against the original balance history, later payments,
invoice transfers, and manual corrections. Missing recorded amounts require
manual investigation. The report's potential uncredited amounts are not approved
adjustments. It intentionally supplies no automatic database repair command.
