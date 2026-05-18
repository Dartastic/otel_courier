// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_courier_suppression.dart';

const _tracerName = 'dartastic_otel_libs_courier';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class CourierResult {
  const CourierResult({
    this.requestId,
    this.messageId,
    this.template,
    this.brand,
    this.channelsTried,
    this.providersTried,
    this.routingStrategy,
    this.deliveryStatus,
    this.timedOut,
    this.statusCode,
  });

  /// Courier `requestId` (the Send request id).
  final String? requestId;

  /// `messageId` for individual message tracking.
  final String? messageId;

  /// Template id used (`template` field in send).
  final String? template;

  /// `brand` id when sent through a specific brand.
  final String? brand;

  /// Channels Courier attempted (csv).
  final String? channelsTried;

  /// Providers Courier attempted (csv).
  final String? providersTried;

  /// `all` / `single` / `optimized` — routing strategy chosen.
  final String? routingStrategy;

  /// `delivered` / `simulated` / `bounced` / `failed` / `undeliverable`
  /// / `enqueued` / `digested` — final state when known.
  final String? deliveryStatus;

  /// Whether Courier hit the per-recipient throttle and timed out
  /// (a unique Courier signal for delayed sends).
  final bool? timedOut;

  final int? statusCode;
}

class CourierCallResult<T> {
  const CourierCallResult({required this.value, this.result});
  final T value;
  final CourierResult? result;
}

/// Wraps a Courier API call in a CLIENT span. [operation] is one of
/// `send`, `messages.list`, `messages.get`, `messages.history`,
/// `templates.list`, `templates.get`, `users.preferences.list`,
/// `users.preferences.update`, `users.tokens.put`, `lists.list`,
/// `lists.send`, `brands.list`, `inbox.list`, `inbox.unread`,
/// `audiences.list`, `automations.invoke`, `bulk.create`,
/// `bulk.users.add`.
Future<T> tracedCourier<T>({
  required String operation,
  required Future<CourierCallResult<T>> Function() invoke,
}) async {
  if (courierInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'courier',
    'rpc.method': operation,
    'courier.operation': operation,
  };

  final span = _tracer().startSpan(
    'courier $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'courier.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.messageId != null) {
        extras.add(OTel.attributeString(
          'courier.message.id',
          r.result!.messageId!,
        ));
      }
      if (r.result!.template != null) {
        extras.add(OTel.attributeString(
          'courier.template',
          r.result!.template!,
        ));
      }
      if (r.result!.brand != null) {
        extras.add(OTel.attributeString(
          'courier.brand',
          r.result!.brand!,
        ));
      }
      if (r.result!.channelsTried != null) {
        extras.add(OTel.attributeString(
          'courier.channels',
          r.result!.channelsTried!,
        ));
      }
      if (r.result!.providersTried != null) {
        extras.add(OTel.attributeString(
          'courier.providers',
          r.result!.providersTried!,
        ));
      }
      if (r.result!.routingStrategy != null) {
        extras.add(OTel.attributeString(
          'courier.routing.strategy',
          r.result!.routingStrategy!,
        ));
      }
      if (r.result!.deliveryStatus != null) {
        extras.add(OTel.attributeString(
          'courier.delivery.status',
          r.result!.deliveryStatus!,
        ));
        if (r.result!.deliveryStatus == 'failed' ||
            r.result!.deliveryStatus == 'undeliverable' ||
            r.result!.deliveryStatus == 'bounced') {
          span.setStatus(
            SpanStatusCode.Error,
            'Courier delivery ${r.result!.deliveryStatus}',
          );
        }
      }
      if (r.result!.timedOut != null) {
        extras.add(OTel.attributeBool(
          'courier.timed_out',
          r.result!.timedOut!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Courier HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
