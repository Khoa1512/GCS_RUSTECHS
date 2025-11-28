import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:path_provider/path_provider.dart';

class MapCacheService {
  static final MapCacheService instance = MapCacheService._internal();

  CacheStore? _cacheStore;

  MapCacheService._internal();

  Future<CacheStore> getCacheStore() async {
    if (_cacheStore != null) return _cacheStore!;

    final dir = await getApplicationDocumentsDirectory();
    final cachePath = '${dir.path}/map_tiles_cache_v2';
    _cacheStore = FileCacheStore(cachePath);

    return _cacheStore!;
  }
}
