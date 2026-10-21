import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

/// Finds historical postings to review. This report never changes balances and
/// cannot infer whether a later manual adjustment already restored the credit.
Map<String, dynamic> buildOverpaymentAudit(Map<String, dynamic> snapshot) {
  final invoices = (snapshot['sales_invoices'] as List).cast<Map>();
  final clients = {
    for (final client in (snapshot['clients'] as List? ?? []).cast<Map>())
      client['id'].toString(): client,
  };
  final candidates = <Map<String, dynamic>>[];
  final issues = <Map<String, dynamic>>[];
  final potentialCreditByClient = <String, double>{};

  for (final invoice in invoices) {
    final total = _number(invoice['totalAmount']);
    final paid = _number(invoice['paidAmount']);
    if (total == null || paid == null || total < 0 || paid < 0) {
      issues.add({
        'invoiceId': invoice['id'],
        'reason': 'Invalid total or payment',
      });
      continue;
    }
    if (invoice['isReturn'] == true || paid <= total) continue;
    final posted = _number(invoice['remainingAmount']);
    final expected = total - paid;
    if (posted != null && (posted - expected).abs() < 0.005) continue;

    final clientId = invoice['clientId']?.toString() ?? '';
    final uncredited = posted == null ? null : posted - expected;
    candidates.add({
      'invoiceId': invoice['id'],
      'invoiceNumber': invoice['invoiceNumber'],
      'clientId': clientId,
      'clientName': clients[clientId]?['name'] ?? invoice['clientName'],
      'totalAmount': total,
      'paidAmount': paid,
      'recordedBalanceChange': posted,
      'expectedBalanceChange': expected,
      'potentialUncreditedAmount': uncredited,
      'reviewRequired': true,
      'reason':
          posted == null
              ? 'Missing recorded amount; inspect original history before correcting'
              : 'Recorded posting differs from invoice total minus payment',
    });
    if (uncredited != null && uncredited > 0 && clientId.isNotEmpty) {
      potentialCreditByClient.update(
        clientId,
        (sum) => sum + uncredited,
        ifAbsent: () => uncredited,
      );
    }
  }

  return {
    'readOnly': true,
    'reviewNote':
        'Review original history, invoice transfers and later manual '
        'corrections before applying any adjustment. Amounts are candidates, '
        'not approved corrections. Re-running this audit changes no data.',
    'invoicesScanned': invoices.length,
    'candidates': candidates,
    'dataIssues': issues,
    'clientsToReview': [
      for (final entry in potentialCreditByClient.entries)
        {
          'clientId': entry.key,
          'clientName': clients[entry.key]?['name'],
          'currentBalance': _number(clients[entry.key]?['balance']),
          'potentialUncreditedAmount': entry.value,
        },
    ],
  };
}

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!{'--input', '--credentials', '--output'}.contains(args[i]) ||
        i + 1 >= args.length) {
      stderr.writeln(
        'Usage: dart run tool/audit_client_overpayments.dart '
        '(--input snapshot.json | --credentials service-account.json) '
        '[--output report.json]',
      );
      exitCode = 64;
      return;
    }
    options[args[i]] = args[i + 1];
  }
  if (options.containsKey('--input') == options.containsKey('--credentials')) {
    stderr.writeln('Specify exactly one of --input or --credentials.');
    exitCode = 64;
    return;
  }

  try {
    final Map<String, dynamic> snapshot;
    if (options.containsKey('--input')) {
      snapshot =
          jsonDecode(await File(options['--input']!).readAsString())
              as Map<String, dynamic>;
    } else {
      final credentialsJson =
          jsonDecode(await File(options['--credentials']!).readAsString())
              as Map<String, dynamic>;
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      final client = await clientViaServiceAccount(credentials, [
        'https://www.googleapis.com/auth/datastore',
      ]);
      try {
        final project = credentialsJson['project_id'] as String;
        snapshot = {
          'sales_invoices': await _readCollection(
            client,
            project,
            'sales_invoices',
          ),
          'clients': await _readCollection(client, project, 'clients'),
        };
      } finally {
        client.close();
      }
    }
    final report = const JsonEncoder.withIndent(
      '  ',
    ).convert(buildOverpaymentAudit(snapshot));
    if (options.containsKey('--output')) {
      final output = File(options['--output']!);
      await output.parent.create(recursive: true);
      await output.writeAsString('$report\n');
    } else {
      stdout.writeln(report);
    }
  } on ServerRequestFailedException catch (error) {
    final response = error.responseContent;
    final code = response is Map ? response['error'] : null;
    stderr.writeln(
      'Audit authentication failed (HTTP ${error.statusCode ?? 'unknown'}'
      '${code is String ? '; $code' : ''}). No database data was changed.',
    );
    exitCode = 1;
  } catch (error) {
    stderr.writeln(
      'Read-only audit failed (${error.runtimeType}). No database data was changed.',
    );
    exitCode = 1;
  }
}

Future<List<Map<String, dynamic>>> _readCollection(
  AutoRefreshingAuthClient client,
  String project,
  String collection,
) async {
  final documents = <Map<String, dynamic>>[];
  String? pageToken;
  do {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$project/databases/(default)/documents/$collection',
      {'pageSize': '300', if (pageToken != null) 'pageToken': pageToken},
    );
    // GET is deliberately the only Firestore operation in this utility.
    final response = await client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Firestore read returned ${response.statusCode}');
    }
    final page = jsonDecode(response.body) as Map<String, dynamic>;
    for (final document in page['documents'] as List? ?? []) {
      documents.add({
        'id': (document['name'] as String).split('/').last,
        ...((document['fields'] as Map?) ?? {}).map(
          (key, value) => MapEntry(key.toString(), _decodeField(value as Map)),
        ),
      });
    }
    pageToken = page['nextPageToken'] as String?;
  } while (pageToken != null && pageToken.isNotEmpty);
  return documents;
}

dynamic _decodeField(Map value) {
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('integerValue')) {
    return num.parse(value['integerValue'].toString());
  }
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('timestampValue')) return value['timestampValue'];
  return null;
}

double? _number(dynamic value) {
  final number =
      value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
  return number != null && number.isFinite ? number : null;
}
