import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rhttp/rhttp.dart';

Future<MockDatabase> mockDatabase() async {
  final db = MockDatabase();
  register<Database>(db);
  return db;
}

class MockDatabase extends Mock implements Database {}

Future<MockNetworkService> mockNetworkService() async {
  final networkService = MockNetworkService();
  register<NetworkService>(networkService);
  return networkService;
}

class MockNetworkService extends NetworkService {
  MockNetworkService() : super(MockRhttpClient());
}

class MockRhttpClient extends Mock implements RhttpClient {}

Future<MockDownloadService> mockDownloadService() async {
  final downloadService = MockDownloadService();
  register<DownloadService>(downloadService);
  return downloadService;
}

class MockDownloadService extends Mock implements DownloadService {}

Future<MockSourceExtension> mockSourceExtension() async {
  final sourceExtension = MockSourceExtension();
  register<SourceExtension>(sourceExtension);
  return sourceExtension;
}

class MockSourceExtension extends Mock implements SourceExtension {}

Future<MockPreferenceService> mockPreferenceService() async {
  final preferenceService = MockPreferenceService();
  register<PreferenceService>(preferenceService);
  return preferenceService;
}

class MockPreferenceService extends Mock implements PreferenceService {}
