import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synq/core/domain/models/image_source.dart';
import 'package:synq/core/widgets/image_viewer.dart';

void main() {
  group('ImageViewer Logic Tests', () {
    test('getCanDismiss returns true for identity matrix', () {
      final controller = TransformationController();
      expect(getCanDismiss(controller), isTrue);
    });

    test('getCanDismiss returns true for slight zoom within 0.01 threshold', () {
      final controller = TransformationController();
      // Scale 1.005 which is within the 0.01 threshold of 1.0
      controller.value = Matrix4.identity()..scaleByDouble(1.005, 1.005, 1.0, 1.0);
      expect(getCanDismiss(controller), isTrue);
    });

    test('getCanDismiss returns false for significant zoom (2.0)', () {
      final controller = TransformationController();
      controller.value = Matrix4.identity()..scaleByDouble(2.0, 2.0, 1.0, 1.0);
      expect(getCanDismiss(controller), isFalse);
    });

    test('imageHeroTag is stable for same source and index', () {
      const source1 = NetworkImageSource('https://example.com/img.png');
      const source2 = NetworkImageSource('https://example.com/img.png');
      
      final tag1 = imageHeroTag(source1, 10);
      final tag2 = imageHeroTag(source2, 10);
      
      expect(tag1, equals(tag2));
    });

    test('imageHeroTag differs for different indices', () {
      const source = NetworkImageSource('https://example.com/img.png');
      
      final tag1 = imageHeroTag(source, 10);
      final tag2 = imageHeroTag(source, 11);
      
      expect(tag1, isNot(equals(tag2)));
    });

    test('imageHeroTag differs for different sources', () {
      const source1 = NetworkImageSource('https://example.com/img1.png');
      const source2 = NetworkImageSource('https://example.com/img2.png');
      
      final tag1 = imageHeroTag(source1, 10);
      final tag2 = imageHeroTag(source2, 10);
      
      expect(tag1, isNot(equals(tag2)));
    });
  });
}
