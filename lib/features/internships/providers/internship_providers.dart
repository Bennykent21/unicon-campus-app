import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/internship_repository.dart';
import '../models/internship.dart';
import '../utils/field_matcher.dart';

final internshipRepositoryProvider =
    Provider<InternshipRepository>((ref) => InternshipRepository());

// ── Filters ───────────────────────────────────────────────────────────────────

class InternshipFilter {
  /// Only listings that fit the student's department and level.
  final bool matchesOnly;
  final Set<InternshipKind> kinds;
  final bool paidOnly;
  final bool remoteOnly;
  final bool edoOnly;
  final bool openNowOnly;
  final String query;

  const InternshipFilter({
    this.matchesOnly = true,
    this.kinds = const {},
    this.paidOnly = false,
    this.remoteOnly = false,
    this.edoOnly = false,
    this.openNowOnly = false,
    this.query = '',
  });

  bool get hasExtraFilters =>
      kinds.isNotEmpty ||
      paidOnly ||
      remoteOnly ||
      edoOnly ||
      openNowOnly ||
      query.isNotEmpty;

  InternshipFilter copyWith({
    bool? matchesOnly,
    Set<InternshipKind>? kinds,
    bool? paidOnly,
    bool? remoteOnly,
    bool? edoOnly,
    bool? openNowOnly,
    String? query,
  }) =>
      InternshipFilter(
        matchesOnly: matchesOnly ?? this.matchesOnly,
        kinds: kinds ?? this.kinds,
        paidOnly: paidOnly ?? this.paidOnly,
        remoteOnly: remoteOnly ?? this.remoteOnly,
        edoOnly: edoOnly ?? this.edoOnly,
        openNowOnly: openNowOnly ?? this.openNowOnly,
        query: query ?? this.query,
      );

  InternshipFilter cleared() => InternshipFilter(matchesOnly: matchesOnly);
}

final internshipFilterProvider =
    StateProvider<InternshipFilter>((ref) => const InternshipFilter());

const _edoPlaces = ['benin', 'edo', 'okomu', 'ihovbor', 'ekpoma', 'auchi'];

/// Pure filter + sort, kept separate from providers so it can be unit tested.
List<Internship> applyInternshipFilter(
  List<Internship> all,
  InternshipFilter f, {
  String? department,
  String? level,
  required DateTime today,
}) {
  final q = f.query.trim().toLowerCase();
  final result = all.where((i) {
    if (f.matchesOnly &&
        !(FieldMatcher.matchesDepartment(i.fields, department) &&
            FieldMatcher.matchesLevel(i.levels, level))) {
      return false;
    }
    if (f.kinds.isNotEmpty && !f.kinds.contains(i.kind)) return false;
    if (f.paidOnly && i.isPaid != true) return false;
    if (f.remoteOnly && i.workMode != 'remote') return false;
    if (f.edoOnly) {
      final where =
          '${i.location ?? ''} ${i.companyCity ?? ''} ${i.companyAddress ?? ''}'
              .toLowerCase();
      if (!_edoPlaces.any(where.contains)) return false;
    }
    if (f.openNowOnly && !i.isActionableOn(today)) return false;
    if (q.isNotEmpty) {
      final hay =
          '${i.title} ${i.companyName} ${i.location ?? ''} ${i.companyCity ?? ''} ${i.companyIndustry ?? ''}'
              .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }).toList();

  result.sort((a, b) {
    final r = a.sortRank(today).compareTo(b.sortRank(today));
    if (r != 0) return r;
    final ad = a.deadline, bd = b.deadline;
    if (ad != null && bd != null) return ad.compareTo(bd);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return a.companyName.compareTo(b.companyName);
  });
  return result;
}

// ── Data ──────────────────────────────────────────────────────────────────────

final internshipsProvider =
    FutureProvider.autoDispose<List<Internship>>((ref) async {
  return ref.read(internshipRepositoryProvider).fetchAll();
});

final internshipByIdProvider =
    FutureProvider.autoDispose.family<Internship?, String>((ref, id) async {
  return ref.read(internshipRepositoryProvider).fetchOne(id);
});

final myApplicationsProvider =
    FutureProvider.autoDispose<List<TrackedApplication>>((ref) async {
  return ref.read(internshipRepositoryProvider).fetchMyApplications();
});

final companyAlumniProvider = FutureProvider.autoDispose
    .family<List<CompanyAlumnus>, String>((ref, companyId) async {
  return ref.read(internshipRepositoryProvider).fetchAlumni(companyId);
});

/// The signed-in student's department and level, for matching.
final studentMatchInfoProvider =
    Provider.autoDispose<({String? department, String? level})>((ref) {
  final p = ref.watch(myProfileProvider).valueOrNull;
  return (department: p?.department, level: p?.level);
});

final filteredInternshipsProvider =
    Provider.autoDispose<AsyncValue<List<Internship>>>((ref) {
  final all = ref.watch(internshipsProvider);
  final filter = ref.watch(internshipFilterProvider);
  final me = ref.watch(studentMatchInfoProvider);
  final overlay = ref.watch(stageOverlayProvider);
  return all.whenData((list) => applyInternshipFilter(
        [
          for (final i in list)
            overlay.containsKey(i.id)
                ? i.copyWith(
                    myStage: overlay[i.id], clearStage: overlay[i.id] == null)
                : i,
        ],
        filter,
        department: me.department,
        level: me.level,
        today: DateTime.now(),
      ));
});

// ── Tracking (optimistic) ─────────────────────────────────────────────────────

/// Stage changes made this session, applied on top of fetched data so the
/// UI updates instantly. A null value means "untracked".
final stageOverlayProvider =
    StateProvider<Map<String, ApplicationStage?>>((ref) => {});

final internshipActionsProvider =
    Provider<InternshipActions>((ref) => InternshipActions(ref));

class InternshipActions {
  InternshipActions(this._ref);
  final Ref _ref;

  InternshipRepository get _repo => _ref.read(internshipRepositoryProvider);

  ApplicationStage? stageOf(Internship i) {
    final overlay = _ref.read(stageOverlayProvider);
    return overlay.containsKey(i.id) ? overlay[i.id] : i.myStage;
  }

  /// Sets [stage] (or clears tracking when null). Rolls back and rethrows on
  /// failure so the caller can show an error.
  Future<void> setStage(Internship i, ApplicationStage? stage,
      {DateTime? interviewAt}) async {
    final previous = stageOf(i);
    _setOverlay(i.id, stage);
    try {
      if (stage == null) {
        await _repo.removeTracking(i.id);
      } else {
        await _repo.setStage(i.id, stage, interviewAt: interviewAt);
      }
      _ref.invalidate(myApplicationsProvider);
    } catch (e, st) {
      AppLogger.error('setStage failed', error: e, stackTrace: st);
      _setOverlay(i.id, previous);
      rethrow;
    }
  }

  Future<void> toggleSaved(Internship i) {
    final current = stageOf(i);
    return setStage(i, current == null ? ApplicationStage.saved : null);
  }

  Future<void> snoozeFollowUp(Internship i) async {
    await _repo.snoozeFollowUp(i.id);
    _ref.invalidate(myApplicationsProvider);
  }

  Future<void> setTrainedHere(Internship i, bool trained) async {
    await _repo.setTrainedHere(i.companyId, trained);
    _ref.invalidate(companyAlumniProvider(i.companyId));
    _ref.invalidate(internshipsProvider);
    _ref.invalidate(internshipByIdProvider(i.id));
  }

  void _setOverlay(String id, ApplicationStage? stage) {
    final next =
        Map<String, ApplicationStage?>.from(_ref.read(stageOverlayProvider));
    next[id] = stage;
    _ref.read(stageOverlayProvider.notifier).state = next;
  }
}
