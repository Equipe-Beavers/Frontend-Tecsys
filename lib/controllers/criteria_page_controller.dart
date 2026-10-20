import 'package:flutter/foundation.dart';

import '../models/install_criterion.dart';
import '../services/install_criterion_service.dart';
import '../utils/name_filter.dart';

/// Keeps one page unless searching and ignores superseded responses.
class CriteriaPageController extends ChangeNotifier {
  CriteriaPageController({required this.service, required this.userId});
  final InstallCriterionService service;
  final int userId;
  List<InstallCriterion> items = const [];
  int page = 1;
  bool hasNext = false;
  bool loading = false;
  String? error;
  int _request = 0;
  int _retryPage = 1;
  String _query = '';
  bool _disposed = false;

  Future<void> search(String query) => load(targetPage: 1, query: query);

  Future<void> load({int? targetPage, String? query}) async {
    if (_disposed) return;
    if (query != null) _query = query.trim();
    final searchQuery = _query;
    final requestedPage = targetPage ?? page;
    _retryPage = requestedPage;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (searchQuery.isNotEmpty) {
        final matches = <InstallCriterion>[];
        var searchPage = 1;
        while (true) {
          final result = await service.list(userId: userId, page: searchPage);
          if (_disposed || request != _request) return;
          matches.addAll(
            result.items.where((item) => matchesName(item.name, searchQuery)),
          );
          if (!result.hasNext) break;
          searchPage++;
        }
        items = List.unmodifiable(matches);
        page = 1;
        hasNext = false;
        return;
      }
      final result = await service.list(userId: userId, page: requestedPage);
      if (_disposed || request != _request) return;
      if (result.items.isEmpty && requestedPage > 1) {
        if (requestedPage > page && items.isNotEmpty) {
          hasNext = false;
        } else {
          await load(targetPage: requestedPage - 1);
          return;
        }
      } else {
        items = result.items;
        page = result.page;
        hasNext = result.hasNext;
      }
    } catch (_) {
      if (!_disposed && request == _request) {
        error = 'Não foi possível carregar os critérios. Verifique a conexão e tente novamente.';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => load(targetPage: _retryPage);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
