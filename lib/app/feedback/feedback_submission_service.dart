import 'package:one_remote/app/feedback/feedback_payload.dart';
import 'package:one_remote/app/feedback/feedback_submission_result.dart';

/// Submits in-app user feedback to a configured backend endpoint.
abstract class FeedbackSubmissionService {
  Future<FeedbackSubmissionResult> submit(FeedbackPayload payload);
}
