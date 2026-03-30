import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Central singleton for image caching in Synq.
/// Configuration ensures that the cache doesn't grow unbounded, 
/// with a 7-day stale period and a maximum of 200 objects.
final synqCacheManager = CacheManager(Config(
  'synq_image_cache',
  stalePeriod: const Duration(days: 7),
  maxNrOfCacheObjects: 200,
  repo: JsonCacheInfoRepository(databaseName: 'synq_image_cache'),
  fileService: HttpFileService(),
));
