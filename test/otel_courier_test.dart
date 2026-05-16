// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_courier/otel_courier.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_courier-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('send records template + channels + providers + routing', () async {
    await tracedCourier<String>(
      operation: 'send',
      invoke: () async => const CourierCallResult(
        value: 'ok',
        result: CourierResult(
          requestId: 'req-1',
          template: 'order-shipped',
          brand: 'main',
          channelsTried: 'email,push,sms',
          providersTried: 'sendgrid,firebase,twilio',
          routingStrategy: 'optimized',
          deliveryStatus: 'delivered',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('courier send')!);
    expect(a['courier.template'], 'order-shipped');
    expect(a['courier.channels'], 'email,push,sms');
    expect(a['courier.providers'], 'sendgrid,firebase,twilio');
    expect(a['courier.routing.strategy'], 'optimized');
    expect(a['courier.delivery.status'], 'delivered');
  });

  test('bounced delivery sets span error', () async {
    await tracedCourier<String>(
      operation: 'messages.get',
      invoke: () async => const CourierCallResult(
        value: 'ok',
        result: CourierResult(deliveryStatus: 'bounced'),
      ),
    );
    expect(
      spans.findSpanByName('courier messages.get')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutCourierInstrumentationAsync(() async {
      await tracedCourier<String>(
        operation: 'messages.list',
        invoke: () async => const CourierCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('courier '), isEmpty);
  });
}
