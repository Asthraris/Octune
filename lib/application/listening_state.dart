import '../domain/analysis_snapshot.dart';
import '../domain/recent_notes.dart';

enum ListeningStatus {
  idle,
  requestingPermission,
  listening,
  interrupted,
  permissionDenied,
  permissionPermanentlyDenied,
  error,
}

/// Everything the main screen shows about listening. A new instance is
/// created for every update.
class ListeningState {
  const ListeningState({
    required this.status,
    required this.snapshot,
    required this.recent,
    this.errorMessage,
  });

  factory ListeningState.initial() => ListeningState(
        status: ListeningStatus.idle,
        snapshot: AnalysisSnapshot.empty(),
        recent: RecentNotes.empty(),
      );

  final ListeningStatus status;
  final AnalysisSnapshot snapshot;
  final RecentNotes recent;
  final String? errorMessage;

  bool get isActive =>
      status == ListeningStatus.listening || status == ListeningStatus.interrupted;

  ListeningState copyWith({
    ListeningStatus? status,
    AnalysisSnapshot? snapshot,
    RecentNotes? recent,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ListeningState(
        status: status ?? this.status,
        snapshot: snapshot ?? this.snapshot,
        recent: recent ?? this.recent,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}
