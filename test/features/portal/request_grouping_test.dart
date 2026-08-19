import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/utils/request_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

TransportationRequest _req(String id, RequestStatus status) {
  final now = DateTime(2026, 7, 14);
  return TransportationRequest(
    id: id,
    requestingCompanyId: 'c1',
    buyerCompanyId: 'c1',
    requestType: 'transportation',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('groupForStatus', () {
    test('maps each status to its bucket', () {
      expect(groupForStatus(RequestStatus.sentBack), RequestGroup.needsAction);
      expect(
          groupForStatus(RequestStatus.requested), RequestGroup.pendingReview);
      expect(groupForStatus(RequestStatus.resubmitted),
          RequestGroup.pendingReview);
      expect(groupForStatus(RequestStatus.approved), RequestGroup.active);
      expect(groupForStatus(RequestStatus.linked), RequestGroup.active);
      expect(groupForStatus(RequestStatus.declined), RequestGroup.closed);
    });
  });

  group('groupRequestsByStatus', () {
    test('returns sections in priority order, empty groups omitted', () {
      final sections = groupRequestsByStatus([
        _req('a', RequestStatus.linked), // active
        _req('b', RequestStatus.sentBack), // needsAction
        _req('c', RequestStatus.requested), // pendingReview
        _req('d', RequestStatus.resubmitted), // pendingReview
        // no declined -> closed group omitted
      ]);

      expect(sections.map((s) => s.group).toList(), [
        RequestGroup.needsAction,
        RequestGroup.pendingReview,
        RequestGroup.active,
      ]);
      expect(sections.first.requests.single.id, 'b');
      expect(sections[1].requests.map((r) => r.id).toList(), ['c', 'd']);
      expect(sections.last.requests.single.id, 'a');
    });

    test('preserves source order within a group', () {
      final sections = groupRequestsByStatus([
        _req('newest', RequestStatus.requested),
        _req('older', RequestStatus.resubmitted),
      ]);
      expect(sections.single.group, RequestGroup.pendingReview);
      expect(sections.single.requests.map((r) => r.id).toList(),
          ['newest', 'older']);
    });

    test('empty input yields no sections', () {
      expect(groupRequestsByStatus(const []), isEmpty);
    });

    test('every group can render when all statuses present', () {
      final sections = groupRequestsByStatus([
        _req('a', RequestStatus.requested),
        _req('b', RequestStatus.sentBack),
        _req('c', RequestStatus.approved),
        _req('d', RequestStatus.declined),
      ]);
      expect(sections.map((s) => s.group).toList(), [
        RequestGroup.needsAction,
        RequestGroup.pendingReview,
        RequestGroup.active,
        RequestGroup.closed,
      ]);
    });
  });
}
